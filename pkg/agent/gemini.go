package agent

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

// GeminiConfig holds configuration for calling Gemini 3.8 on Vertex AI.
type GeminiConfig struct {
	ProjectID string
	Location  string
	Model     string
	BaseURL   string
}

// DefaultGeminiConfig returns the default GCP configuration adhering to user rules.
func DefaultGeminiConfig() GeminiConfig {
	project := os.Getenv("GCP_PROJECT")
	if project == "" {
		project = os.Getenv("GOOGLE_CLOUD_PROJECT")
	}
	if project == "" {
		project = "davenport-boutique"
	}

	location := os.Getenv("GCP_LOCATION")
	if location == "" {
		location = "us-central1"
	}

	model := os.Getenv("GEMINI_MODEL")
	if model == "" {
		model = "gemini-3.8-flash"
	}

	return GeminiConfig{
		ProjectID: project,
		Location:  location,
		Model:     model,
		BaseURL:   os.Getenv("GEMINI_BASE_URL"),
	}
}

// TokenProvider manages obtaining and caching OAuth2 tokens via Application Default Credentials (ADC).
type TokenProvider struct {
	mu          sync.RWMutex
	cachedToken string
	expiry      time.Time
}

var defaultTokenProvider = &TokenProvider{}

// GetToken resolves a valid Bearer token for GCP API calls.
func (tp *TokenProvider) GetToken(ctx context.Context) (string, error) {
	tp.mu.RLock()
	if tp.cachedToken != "" && time.Now().Before(tp.expiry.Add(-1*time.Minute)) {
		token := tp.cachedToken
		tp.mu.RUnlock()
		return token, nil
	}
	tp.mu.RUnlock()

	tp.mu.Lock()
	defer tp.mu.Unlock()

	// Double check cache after acquiring write lock
	if tp.cachedToken != "" && time.Now().Before(tp.expiry.Add(-1*time.Minute)) {
		return tp.cachedToken, nil
	}

	// 1. Check environment variable token override
	if envTok := os.Getenv("GCP_ACCESS_TOKEN"); envTok != "" {
		tp.cachedToken = envTok
		tp.expiry = time.Now().Add(30 * time.Minute)
		return envTok, nil
	}

	// 2. Check Cloud Run metadata server only when running on GCP
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
				tp.cachedToken = metaResp.AccessToken
				tp.expiry = time.Now().Add(time.Duration(metaResp.ExpiresIn) * time.Second)
				return metaResp.AccessToken, nil
			}
		}
	}

	// 3. Fallback: gcloud CLI token
	if _, err := exec.LookPath("gcloud"); err == nil {
		cmd := exec.CommandContext(ctx, "gcloud", "auth", "print-access-token")
		var out bytes.Buffer
		cmd.Stdout = &out
		if err := cmd.Run(); err == nil {
			tok := strings.TrimSpace(out.String())
			if tok != "" {
				tp.cachedToken = tok
				tp.expiry = time.Now().Add(45 * time.Minute)
				return tok, nil
			}
		}
	}

	return "", fmt.Errorf("unable to acquire GCP ADC credentials for project 'davenport-boutique'. Ensure ADC is configured or GCP_ACCESS_TOKEN is set")
}

// GeminiClient interacts with Gemini 3.8 models via Vertex AI REST API.
type GeminiClient struct {
	config     GeminiConfig
	httpClient *http.Client
	tokenProv  *TokenProvider
}

// NewGeminiClient creates a new client.
func NewGeminiClient(cfg GeminiConfig) *GeminiClient {
	return &GeminiClient{
		config: cfg,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
		tokenProv: defaultTokenProvider,
	}
}

// SetTransport sets the http.RoundTripper transport for the HTTP client (useful for in-memory testing).
func (gc *GeminiClient) SetTransport(rt http.RoundTripper) {
	gc.httpClient.Transport = rt
}

// GenerateContentRequest represents the Vertex AI Gemini payload.
type GenerateContentRequest struct {
	Contents          []GeminiContent    `json:"contents"`
	SystemInstruction *GeminiContent     `json:"systemInstruction,omitempty"`
	GenerationConfig  *GenerationConfig  `json:"generationConfig,omitempty"`
}

type GeminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []GeminiPart `json:"parts"`
}

type GeminiPart struct {
	Text string `json:"text"`
}

type GenerationConfig struct {
	Temperature     float32 `json:"temperature"`
	MaxOutputTokens int     `json:"maxOutputTokens"`
}

type GenerateContentResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
		FinishReason string `json:"finishReason"`
	} `json:"candidates"`
	UsageMetadata struct {
		PromptTokenCount     int `json:"promptTokenCount"`
		CandidatesTokenCount int `json:"candidatesTokenCount"`
		TotalTokenCount      int `json:"totalTokenCount"`
	} `json:"usageMetadata"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error,omitempty"`
}

// AgentGenerateResult contains the LLM output and exact token telemetry.
type AgentGenerateResult struct {
	Text            string
	PromptTokens    int
	CandidateTokens int
	TotalTokens     int
	ModelUsed       string
}

// Generate sends a real prompt to Gemini 3.8 on Vertex AI.
// STRICT NEVER MOCK: Returns real errors if authentication or API call fails.
func (gc *GeminiClient) Generate(ctx context.Context, systemInstruction string, prompt string) (*AgentGenerateResult, error) {
	token, err := gc.tokenProv.GetToken(ctx)
	if err != nil {
		return nil, fmt.Errorf("gemini auth error: %w", err)
	}

	host := fmt.Sprintf("%s-aiplatform.googleapis.com", gc.config.Location)
	if gc.config.Location == "global" {
		host = "aiplatform.googleapis.com"
	}
	url := fmt.Sprintf(
		"https://%s/v1/projects/%s/locations/%s/publishers/google/models/%s:generateContent",
		host,
		gc.config.ProjectID,
		gc.config.Location,
		gc.config.Model,
	)
	if gc.config.BaseURL != "" {
		url = fmt.Sprintf(
			"%s/v1/projects/%s/locations/%s/publishers/google/models/%s:generateContent",
			gc.config.BaseURL,
			gc.config.ProjectID,
			gc.config.Location,
			gc.config.Model,
		)
	}

	reqPayload := GenerateContentRequest{
		Contents: []GeminiContent{
			{
				Role: "user",
				Parts: []GeminiPart{
					{Text: prompt},
				},
			},
		},
		GenerationConfig: &GenerationConfig{
			Temperature:     0.2,
			MaxOutputTokens: 2048,
		},
	}

	if systemInstruction != "" {
		reqPayload.SystemInstruction = &GeminiContent{
			Parts: []GeminiPart{
				{Text: systemInstruction},
			},
		}
	}

	jsonBytes, err := json.Marshal(reqPayload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal Gemini request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(jsonBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := gc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("gemini HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	var geminiResp GenerateContentResponse
	if err := json.Unmarshal(bodyBytes, &geminiResp); err != nil {
		return nil, fmt.Errorf("failed to decode Gemini response (HTTP %d): %s", resp.StatusCode, string(bodyBytes))
	}

	if geminiResp.Error != nil {
		return nil, fmt.Errorf("vertex AI error %d [%s]: %s", geminiResp.Error.Code, geminiResp.Error.Status, geminiResp.Error.Message)
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("empty response received from Gemini 3.8 (HTTP %d)", resp.StatusCode)
	}

	return &AgentGenerateResult{
		Text:            geminiResp.Candidates[0].Content.Parts[0].Text,
		PromptTokens:    geminiResp.UsageMetadata.PromptTokenCount,
		CandidateTokens: geminiResp.UsageMetadata.CandidatesTokenCount,
		TotalTokens:     geminiResp.UsageMetadata.TotalTokenCount,
		ModelUsed:       gc.config.Model,
	}, nil
}
