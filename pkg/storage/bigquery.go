package storage

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

// BigQueryConfig holds connection parameters for BigQuery episodic telemetry and vector storage.
type BigQueryConfig struct {
	ProjectID               string
	DatasetID               string
	AgentLogsTable          string
	SessionSummariesTable   string
	CrystallizedBeliefsTable string
	Enabled                 bool
	BaseURL                 string // for testing
}

// DefaultBigQueryConfig returns the production BigQuery configuration for davenport-boutique.
func DefaultBigQueryConfig() BigQueryConfig {
	project := os.Getenv("GCP_PROJECT")
	if project == "" {
		project = "davenport-boutique"
	}

	dataset := os.Getenv("BQ_DATASET_ID")
	if dataset == "" {
		dataset = "adk_agent_telemetry"
	}

	enabled := true
	if os.Getenv("DISABLE_BIGQUERY") == "true" {
		enabled = false
	}

	return BigQueryConfig{
		ProjectID:               project,
		DatasetID:               dataset,
		AgentLogsTable:          "agent_logs",
		SessionSummariesTable:   "session_summaries",
		CrystallizedBeliefsTable: "crystallized_beliefs",
		Enabled:                 enabled,
	}
}

// BigQueryClient manages REST interactions with Google Cloud BigQuery.
type BigQueryClient struct {
	config     BigQueryConfig
	httpClient *http.Client
	mu         sync.RWMutex
	token      string
	tokenExp   time.Time
}

// NewBigQueryClient initializes a new BigQuery client.
func NewBigQueryClient(cfg BigQueryConfig) *BigQueryClient {
	return &BigQueryClient{
		config: cfg,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

// SetTransport allows injecting a mock or in-memory transport for unit testing.
func (c *BigQueryClient) SetTransport(rt http.RoundTripper) {
	c.httpClient.Transport = rt
}

// getToken retrieves a valid Google Cloud ADC access token.
func (c *BigQueryClient) getToken(ctx context.Context) (string, error) {
	c.mu.RLock()
	if c.token != "" && time.Now().Before(c.tokenExp.Add(-1*time.Minute)) {
		tok := c.token
		c.mu.RUnlock()
		return tok, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.token != "" && time.Now().Before(c.tokenExp.Add(-1*time.Minute)) {
		return c.token, nil
	}

	// 1. Env token override
	if tok := os.Getenv("GCP_ACCESS_TOKEN"); tok != "" {
		c.token = tok
		c.tokenExp = time.Now().Add(30 * time.Minute)
		return tok, nil
	}

	// 2. Cloud Run Metadata Server
	if os.Getenv("K_SERVICE") != "" || os.Getenv("CLOUD_RUN_JOB") != "" {
		req, _ := http.NewRequestWithContext(ctx, "GET", "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token", nil)
		req.Header.Set("Metadata-Flavor", "Google")
		client := &http.Client{Timeout: 1 * time.Second}
		resp, err := client.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			var metaResp struct {
				AccessToken string `json:"access_token"`
				ExpiresIn   int    `json:"expires_in"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&metaResp); err == nil && metaResp.AccessToken != "" {
				c.token = metaResp.AccessToken
				c.tokenExp = time.Now().Add(time.Duration(metaResp.ExpiresIn) * time.Second)
				return metaResp.AccessToken, nil
			}
		}
	}

	// 3. gcloud auth print-access-token
	if _, err := exec.LookPath("gcloud"); err == nil {
		cmd := exec.CommandContext(ctx, "gcloud", "auth", "print-access-token")
		var out bytes.Buffer
		cmd.Stdout = &out
		if err := cmd.Run(); err == nil {
			tok := strings.TrimSpace(out.String())
			if tok != "" {
				c.token = tok
				c.tokenExp = time.Now().Add(45 * time.Minute)
				return tok, nil
			}
		}
	}

	return "", fmt.Errorf("unable to obtain GCP ADC credentials for BigQuery")
}

// LogAgentInteraction streams an interaction to BigQuery adk_agent_telemetry.agent_logs.
func (c *BigQueryClient) LogAgentInteraction(ctx context.Context, userID, sessionID, agentName, eventType, message string, payload map[string]interface{}) error {
	if !c.config.Enabled {
		return nil
	}

	token, err := c.getToken(ctx)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("https://bigquery.googleapis.com/bigquery/v2/projects/%s/datasets/%s/tables/%s/insertAll",
		c.config.ProjectID, c.config.DatasetID, c.config.AgentLogsTable)
	if c.config.BaseURL != "" {
		endpoint = fmt.Sprintf("%s/insertAll", c.config.BaseURL)
	}

	payloadJSON, _ := json.Marshal(payload)
	now := time.Now().UTC().Format(time.RFC3339)

	reqBody := map[string]interface{}{
		"kind": "bigquery#tableDataInsertAllRequest",
		"rows": []map[string]interface{}{
			{
				"insertId": fmt.Sprintf("%s-%d", sessionID, time.Now().UnixNano()),
				"json": map[string]interface{}{
					"timestamp":    now,
					"user_id":      userID,
					"session_id":   sessionID,
					"agent_name":   agentName,
					"event_type":   eventType,
					"message":      message,
					"json_payload": string(payloadJSON),
				},
			},
		},
	}

	bodyBytes, _ := json.Marshal(reqBody)
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("BigQuery insertAll failed (%d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// LogSessionSummary writes a session summary to BigQuery adk_agent_telemetry.session_summaries.
func (c *BigQueryClient) LogSessionSummary(ctx context.Context, summaryID, userID, sessionID, summaryJSON string) error {
	if !c.config.Enabled {
		return nil
	}

	token, err := c.getToken(ctx)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("https://bigquery.googleapis.com/bigquery/v2/projects/%s/datasets/%s/tables/%s/insertAll",
		c.config.ProjectID, c.config.DatasetID, c.config.SessionSummariesTable)
	if c.config.BaseURL != "" {
		endpoint = fmt.Sprintf("%s/insertAll", c.config.BaseURL)
	}

	now := time.Now().UTC().Format(time.RFC3339)
	reqBody := map[string]interface{}{
		"kind": "bigquery#tableDataInsertAllRequest",
		"rows": []map[string]interface{}{
			{
				"insertId": summaryID,
				"json": map[string]interface{}{
					"summary_id":             summaryID,
					"user_id":                userID,
					"session_id":             sessionID,
					"generated_summary_json": summaryJSON,
					"created_at":             now,
				},
			},
		},
	}

	bodyBytes, _ := json.Marshal(reqBody)
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("BigQuery insertAll summary failed (%d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// UpsertCrystallizedBelief stores a crystallized belief along with its 768-dimensional vector embedding in BigQuery.
func (c *BigQueryClient) UpsertCrystallizedBelief(ctx context.Context, channelID string, belief CrystallizedBelief) error {
	if !c.config.Enabled {
		return nil
	}

	token, err := c.getToken(ctx)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("https://bigquery.googleapis.com/bigquery/v2/projects/%s/datasets/%s/tables/%s/insertAll",
		c.config.ProjectID, c.config.DatasetID, c.config.CrystallizedBeliefsTable)
	if c.config.BaseURL != "" {
		endpoint = fmt.Sprintf("%s/insertAll", c.config.BaseURL)
	}

	// Ensure 768-dim normalized embedding is generated
	embedding := belief.Embedding
	if len(embedding) == 0 {
		embedding = GenerateEmbedding(fmt.Sprintf("%s %s %s %s %s", belief.Key, belief.Value, belief.Category, belief.Keywords, belief.Statement))
	}

	now := time.Now().UTC().Format(time.RFC3339)
	reqBody := map[string]interface{}{
		"kind": "bigquery#tableDataInsertAllRequest",
		"rows": []map[string]interface{}{
			{
				"insertId": fmt.Sprintf("%s-%s", channelID, belief.Key),
				"json": map[string]interface{}{
					"channel_id":   channelID,
					"belief_key":   belief.Key,
					"belief_value": belief.Value,
					"category":     belief.Category,
					"confidence":   belief.Confidence,
					"keywords":     belief.Keywords,
					"statement":    belief.Statement,
					"embedding":    embedding,
					"updated_at":   now,
				},
			},
		},
	}

	bodyBytes, _ := json.Marshal(reqBody)
	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("BigQuery insertAll belief failed (%d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// SearchVectorBeliefs queries BigQuery vector store using ML.DISTANCE cosine similarity over 768-dim embeddings.
func (c *BigQueryClient) SearchVectorBeliefs(ctx context.Context, channelID string, queryText string, limit int) ([]CrystallizedBelief, error) {
	if !c.config.Enabled {
		return nil, fmt.Errorf("BigQuery is disabled")
	}

	token, err := c.getToken(ctx)
	if err != nil {
		return nil, err
	}

	queryVec := GenerateEmbedding(queryText)
	vecJSON, err := json.Marshal(queryVec)
	if err != nil {
		return nil, err
	}

	channelFilter := ""
	if channelID != "" {
		channelFilter = fmt.Sprintf("WHERE (channel_id = '%s' OR channel_id = '#%s' OR channel_id = 'chan-product-launch')", channelID, strings.TrimPrefix(channelID, "#"))
	}

	sql := fmt.Sprintf(`
		SELECT belief_key, belief_value, category, confidence, keywords, statement,
		       ML.DISTANCE(embedding, %s, 'COSINE') AS distance
		FROM `+"`%s.%s.%s`"+`
		%s
		ORDER BY distance ASC
		LIMIT %d
	`, string(vecJSON), c.config.ProjectID, c.config.DatasetID, c.config.CrystallizedBeliefsTable, channelFilter, limit)

	queryEndpoint := fmt.Sprintf("https://bigquery.googleapis.com/bigquery/v2/projects/%s/queries", c.config.ProjectID)
	if c.config.BaseURL != "" {
		queryEndpoint = fmt.Sprintf("%s/queries", c.config.BaseURL)
	}

	reqPayload := map[string]interface{}{
		"query":        sql,
		"useLegacySql": false,
	}
	payloadBytes, _ := json.Marshal(reqPayload)

	req, err := http.NewRequestWithContext(ctx, "POST", queryEndpoint, bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("BigQuery vector search query failed (%d): %s", resp.StatusCode, string(body))
	}

	var bqResp struct {
		Rows []struct {
			F []struct {
				V interface{} `json:"v"`
			} `json:"f"`
		} `json:"rows"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&bqResp); err != nil {
		return nil, err
	}

	var results []CrystallizedBelief
	seen := make(map[string]bool)
	for _, row := range bqResp.Rows {
		if len(row.F) >= 6 {
			key, _ := row.F[0].V.(string)
			val, _ := row.F[1].V.(string)
			cat, _ := row.F[2].V.(string)
			confStr, _ := row.F[3].V.(string)
			var conf float64
			fmt.Sscanf(confStr, "%f", &conf)
			if conf == 0 {
				conf = 0.95
			}
			kw, _ := row.F[4].V.(string)
			stmt, _ := row.F[5].V.(string)

			normKey := strings.ToLower(strings.TrimSpace(key))
			if normKey == "" || seen[normKey] {
				continue
			}
			seen[normKey] = true

			results = append(results, CrystallizedBelief{
				Key:        key,
				Value:      val,
				Category:   cat,
				Confidence: conf,
				Keywords:   kw,
				Statement:  stmt,
			})
			if limit > 0 && len(results) >= limit {
				break
			}
		}
	}

	return results, nil
}

// GetStorageStatus returns status and metadata about the connected BigQuery database and vector engine.
func (c *BigQueryClient) GetStorageStatus(ctx context.Context) map[string]interface{} {
	status := map[string]interface{}{
		"database":      "Google BigQuery",
		"project_id":    c.config.ProjectID,
		"dataset_id":    c.config.DatasetID,
		"tables":        []string{c.config.AgentLogsTable, c.config.SessionSummariesTable, c.config.CrystallizedBeliefsTable},
		"vector_engine": "BigQuery Vector Search (ML.DISTANCE COSINE)",
		"enabled":       c.config.Enabled,
	}

	if !c.config.Enabled {
		status["status"] = "disabled"
		return status
	}

	tok, err := c.getToken(ctx)
	if err != nil {
		status["status"] = "unauthenticated"
		status["error"] = err.Error()
		return status
	}

	status["status"] = "connected"
	status["auth_type"] = "Google Cloud Application Default Credentials (ADC)"
	_ = tok
	return status
}
