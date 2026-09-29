package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

type mockBigQueryRoundTripper struct {
	lastURL     string
	lastBody    string
	lastHeaders http.Header
	response    string
	statusCode  int
}

func (m *mockBigQueryRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	m.lastURL = req.URL.String()
	m.lastHeaders = req.Header
	if req.Body != nil {
		b, _ := io.ReadAll(req.Body)
		m.lastBody = string(b)
	}

	status := m.statusCode
	if status == 0 {
		status = http.StatusOK
	}

	respBody := m.response
	if respBody == "" {
		respBody = `{"kind": "bigquery#tableDataInsertAllResponse"}`
	}

	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader(respBody)),
		Header:     make(http.Header),
	}, nil
}

func TestBigQueryClient_LogAgentInteraction(t *testing.T) {
	mockRT := &mockBigQueryRoundTripper{}
	cfg := BigQueryConfig{
		ProjectID:               "test-project",
		DatasetID:               "test_dataset",
		AgentLogsTable:          "agent_logs",
		SessionSummariesTable:   "session_summaries",
		CrystallizedBeliefsTable: "crystallized_beliefs",
		Enabled:                 true,
		BaseURL:                 "https://bigquery.mock/api",
	}

	client := NewBigQueryClient(cfg)
	client.SetTransport(mockRT)
	client.token = "test-token"
	client.tokenExp = time.Now().Add(1 * time.Hour)

	ctx := context.Background()
	err := client.LogAgentInteraction(ctx, "lead-agent", "chan-test", "Lead Coordinator", "AGENT_RESPONSE", "Test message", map[string]interface{}{
		"thread_id": "th-123",
	})
	if err != nil {
		t.Fatalf("expected no error, got: %v", err)
	}

	if !strings.Contains(mockRT.lastURL, "/insertAll") {
		t.Errorf("expected URL to contain /insertAll, got: %s", mockRT.lastURL)
	}
	if !strings.Contains(mockRT.lastBody, "lead-agent") {
		t.Errorf("expected payload to contain lead-agent, got: %s", mockRT.lastBody)
	}
	if !strings.Contains(mockRT.lastBody, "Test message") {
		t.Errorf("expected payload to contain Test message, got: %s", mockRT.lastBody)
	}
}

func TestBigQueryClient_SearchVectorBeliefs(t *testing.T) {
	mockQueryResp := `{
		"kind": "bigquery#queryResponse",
		"rows": [
			{
				"f": [
					{"v": "deployment_stack"},
					{"v": "Cloud Run with Vertex AI Gemini 3.8 Flash"},
					{"v": "Infrastructure"},
					{"v": "0.98"},
					{"v": "cloud run, vertex ai"},
					{"v": "Production services deploy on Cloud Run."}
				]
			}
		]
	}`

	mockRT := &mockBigQueryRoundTripper{
		response: mockQueryResp,
	}
	cfg := BigQueryConfig{
		ProjectID:               "test-project",
		DatasetID:               "test_dataset",
		AgentLogsTable:          "agent_logs",
		SessionSummariesTable:   "session_summaries",
		CrystallizedBeliefsTable: "crystallized_beliefs",
		Enabled:                 true,
		BaseURL:                 "https://bigquery.mock/api",
	}

	client := NewBigQueryClient(cfg)
	client.SetTransport(mockRT)
	client.token = "test-token"
	client.tokenExp = time.Now().Add(1 * time.Hour)

	ctx := context.Background()
	results, err := client.SearchVectorBeliefs(ctx, "chan-test", "What is our deployment stack?", 3)
	if err != nil {
		t.Fatalf("expected no error, got: %v", err)
	}

	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].Key != "deployment_stack" {
		t.Errorf("expected key deployment_stack, got: %s", results[0].Key)
	}
	if !strings.Contains(mockRT.lastBody, "ML.DISTANCE") {
		t.Errorf("expected BigQuery SQL query to use ML.DISTANCE, got: %s", mockRT.lastBody)
	}
}

func TestBigQueryClient_UpsertCrystallizedBelief_DeterministicInsertID(t *testing.T) {
	mockRT := &mockBigQueryRoundTripper{}
	cfg := BigQueryConfig{
		ProjectID:               "test-project",
		DatasetID:               "test_dataset",
		AgentLogsTable:          "agent_logs",
		SessionSummariesTable:   "session_summaries",
		CrystallizedBeliefsTable: "crystallized_beliefs",
		Enabled:                 true,
		BaseURL:                 "https://bigquery.mock/api",
	}

	client := NewBigQueryClient(cfg)
	client.SetTransport(mockRT)
	client.token = "test-token"
	client.tokenExp = time.Now().Add(1 * time.Hour)

	belief := CrystallizedBelief{
		Key:        "spanner_dual_layer",
		Value:      "Cloud Spanner dual-layer memory with exact cosine distance",
		Category:   "Database",
		Confidence: 0.99,
		Keywords:   "spanner, memory, vector",
		Statement:  "Spanner provides dual-layer persistent memory.",
	}

	ctx := context.Background()
	err := client.UpsertCrystallizedBelief(ctx, "chan-test", belief)
	if err != nil {
		t.Fatalf("expected no error, got: %v", err)
	}

	expectedInsertID := "chan-test-spanner_dual_layer"
	if !strings.Contains(mockRT.lastBody, fmt.Sprintf(`"insertId":"%s"`, expectedInsertID)) {
		t.Errorf("expected deterministic insertId %q in BigQuery payload, got: %s", expectedInsertID, mockRT.lastBody)
	}
}

func TestBigQueryClient_SearchVectorBeliefs_Deduplication(t *testing.T) {
	mockQueryResp := `{
		"kind": "bigquery#queryResponse",
		"rows": [
			{
				"f": [
					{"v": "deployment_stack"},
					{"v": "Cloud Run with Vertex AI Gemini 3.8 Flash"},
					{"v": "Infrastructure"},
					{"v": "0.98"},
					{"v": "cloud run, vertex ai"},
					{"v": "Production services deploy on Cloud Run."}
				]
			},
			{
				"f": [
					{"v": "DEPLOYMENT_STACK"},
					{"v": "Duplicated older entry in streaming buffer"},
					{"v": "Infrastructure"},
					{"v": "0.95"},
					{"v": "cloud run"},
					{"v": "Older duplicated row."}
				]
			},
			{
				"f": [
					{"v": "spanner_vector"},
					{"v": "Cloud Spanner vector search"},
					{"v": "Database"},
					{"v": "0.99"},
					{"v": "spanner, vector"},
					{"v": "Spanner supports cosine distance."}
				]
			}
		]
	}`

	mockRT := &mockBigQueryRoundTripper{
		response: mockQueryResp,
	}
	cfg := BigQueryConfig{
		ProjectID:               "test-project",
		DatasetID:               "test_dataset",
		AgentLogsTable:          "agent_logs",
		SessionSummariesTable:   "session_summaries",
		CrystallizedBeliefsTable: "crystallized_beliefs",
		Enabled:                 true,
		BaseURL:                 "https://bigquery.mock/api",
	}

	client := NewBigQueryClient(cfg)
	client.SetTransport(mockRT)
	client.token = "test-token"
	client.tokenExp = time.Now().Add(1 * time.Hour)

	ctx := context.Background()
	results, err := client.SearchVectorBeliefs(ctx, "chan-test", "deployment", 5)
	if err != nil {
		t.Fatalf("expected no error, got: %v", err)
	}

	if len(results) != 2 {
		t.Fatalf("expected 2 deduplicated results, got %d: %+v", len(results), results)
	}

	keysSeen := make(map[string]int)
	for _, r := range results {
		k := strings.ToLower(r.Key)
		keysSeen[k]++
	}
	if keysSeen["deployment_stack"] != 1 {
		t.Errorf("expected exactly 1 deployment_stack, got %d", keysSeen["deployment_stack"])
	}
	if keysSeen["spanner_vector"] != 1 {
		t.Errorf("expected exactly 1 spanner_vector, got %d", keysSeen["spanner_vector"])
	}
}

func TestBigQueryClient_GetStorageStatus(t *testing.T) {
	cfg := DefaultBigQueryConfig()
	client := NewBigQueryClient(cfg)
	client.token = "valid-token"
	client.tokenExp = time.Now().Add(1 * time.Hour)

	status := client.GetStorageStatus(context.Background())
	if status["database"] != "Google BigQuery" {
		t.Errorf("expected database to be Google BigQuery, got: %v", status["database"])
	}
	if status["dataset_id"] != "adk_agent_telemetry" {
		t.Errorf("expected dataset_id to be adk_agent_telemetry, got: %v", status["dataset_id"])
	}
	if status["status"] != "connected" {
		t.Errorf("expected status connected, got: %v", status["status"])
	}
}

func TestEmbedding_VectorConsistency(t *testing.T) {
	v1 := GenerateEmbedding("What is the production deployment stack for Cloud Run?")
	v2 := GenerateEmbedding("deployment stack cloud run vertex ai")
	v3 := GenerateEmbedding("medieval castle tapestry history")

	if len(v1) != 768 {
		t.Fatalf("expected 768-dim vector, got %d", len(v1))
	}

	dist12 := CosineDistance64(v1, v2)
	dist13 := CosineDistance64(v1, v3)

	if dist12 >= dist13 {
		t.Errorf("expected deployment queries to be semantically closer than unrelated medieval topic (dist12=%f, dist13=%f)", dist12, dist13)
	}
}

func TestStore_GetStorageInfo(t *testing.T) {
	store := NewInMemStore()
	info := store.GetStorageInfo(context.Background())
	if info == nil {
		t.Fatalf("expected non-nil storage info")
	}

	if info["database"] != "Google BigQuery" {
		t.Errorf("expected Google BigQuery, got: %v", info["database"])
	}

	b, _ := json.Marshal(info)
	if !strings.Contains(string(b), "adk_agent_telemetry") {
		t.Errorf("expected info to mention adk_agent_telemetry, got: %s", string(b))
	}
}
