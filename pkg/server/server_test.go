package server

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jasondavenport/agents-of-chat/pkg/agent"
	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

func setupTestServer() (*Server, storage.MemoryStore) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	_ = store.ResetAndSeed(ctx)

	geminiCfg := agent.DefaultGeminiConfig()
	geminiClient := agent.NewGeminiClient(geminiCfg)

	wsHub := NewWSHub()
	go wsHub.Run()

	orch := agent.NewOrchestrator(store, geminiClient, wsHub.BroadcastEvent)
	srv := NewServer(store, orch, wsHub, "")
	return srv, store
}

func TestHealthzEndpoint(t *testing.T) {
	srv, _ := setupTestServer()
	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()

	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp["status"] != "healthy" {
		t.Fatalf("expected healthy status, got %v", resp["status"])
	}
	if resp["project"] != "davenport-boutique" {
		t.Fatalf("expected project davenport-boutique, got %v", resp["project"])
	}
	models, ok := resp["models"].([]interface{})
	if !ok || len(models) != 1 || models[0] != "gemini-3.8-flash" {
		t.Fatalf("expected models [gemini-3.8-flash], got %v", resp["models"])
	}
}

func TestListChannelsEndpoint(t *testing.T) {
	srv, _ := setupTestServer()
	req := httptest.NewRequest("GET", "/api/channels", nil)
	w := httptest.NewRecorder()

	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var channels []storage.Channel
	if err := json.Unmarshal(w.Body.Bytes(), &channels); err != nil {
		t.Fatalf("failed to decode channels: %v", err)
	}

	if len(channels) != 10 {
		t.Fatalf("expected 10 channels across the 6 eras, got %d", len(channels))
	}
}

func TestListErasEndpoint(t *testing.T) {
	srv, _ := setupTestServer()
	req := httptest.NewRequest("GET", "/api/eras", nil)
	w := httptest.NewRecorder()

	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var eras []storage.Era
	if err := json.Unmarshal(w.Body.Bytes(), &eras); err != nil {
		t.Fatalf("failed to decode eras: %v", err)
	}

	if len(eras) != 6 {
		t.Fatalf("expected 6 historical eras, got %d", len(eras))
	}
	if eras[0].Year != 1988 || eras[5].Year != 2026 {
		t.Fatalf("unexpected era span: %d to %d", eras[0].Year, eras[5].Year)
	}
}

func TestPresenceEndpoints(t *testing.T) {
	srv, _ := setupTestServer()

	// GET /api/presence
	req := httptest.NewRequest("GET", "/api/presence", nil)
	w := httptest.NewRecorder()
	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var presences []storage.AgentPresence
	if err := json.Unmarshal(w.Body.Bytes(), &presences); err != nil {
		t.Fatalf("failed to decode presences: %v", err)
	}
	if len(presences) == 0 {
		t.Fatalf("expected seeded presences, got 0")
	}

	// POST /api/presence
	body := strings.NewReader(`{"agent_id":"lead-agent","agent_name":"Lead Coordinator","status":"away","status_message":"In RFC review"}`)
	reqPost := httptest.NewRequest("POST", "/api/presence", body)
	reqPost.Header.Set("Content-Type", "application/json")
	wPost := httptest.NewRecorder()
	srv.Routes().ServeHTTP(wPost, reqPost)

	if wPost.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", wPost.Code)
	}
}

func TestScratchpadEndpoints(t *testing.T) {
	srv, _ := setupTestServer()

	// GET /api/scratchpads?agent_id=lead-agent&channel_id=chan-product-launch
	req := httptest.NewRequest("GET", "/api/scratchpads?agent_id=lead-agent&channel_id=chan-product-launch", nil)
	w := httptest.NewRecorder()
	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var pad storage.PrivateScratchpad
	if err := json.Unmarshal(w.Body.Bytes(), &pad); err != nil {
		t.Fatalf("failed to decode scratchpad: %v", err)
	}
	if pad.AgentID != "lead-agent" {
		t.Fatalf("expected lead-agent scratchpad, got %s", pad.AgentID)
	}
}

func TestBufferEndpoint(t *testing.T) {
	srv, _ := setupTestServer()

	req := httptest.NewRequest("GET", "/api/channels/chan-1988-irc/buffer", nil)
	w := httptest.NewRecorder()
	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var buf storage.MemoryBuffer
	if err := json.Unmarshal(w.Body.Bytes(), &buf); err != nil {
		t.Fatalf("failed to decode buffer: %v", err)
	}
	if buf.MaxTurns != 5 {
		t.Fatalf("expected max 5 turns for 1988 IRC buffer, got %d", buf.MaxTurns)
	}
}

func TestGetMessagesEndpoint(t *testing.T) {
	srv, _ := setupTestServer()
	req := httptest.NewRequest("GET", "/api/channels/chan-incident-postmortem/messages", nil)
	w := httptest.NewRecorder()

	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var msgs []storage.Message
	if err := json.Unmarshal(w.Body.Bytes(), &msgs); err != nil {
		t.Fatalf("failed to decode messages: %v", err)
	}

	if len(msgs) == 0 {
		t.Fatalf("expected seeded incident messages, got 0")
	}
}

func TestInjectEventEndpoint(t *testing.T) {
	srv, _ := setupTestServer()
	body := strings.NewReader(`{"title":"Database Lock Warning","details":"Thread pool saturation at 85%"}`)
	req := httptest.NewRequest("POST", "/api/channels/chan-incident-postmortem/events", body)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d (body: %s)", w.Code, w.Body.String())
	}

	var msg storage.Message
	if err := json.Unmarshal(w.Body.Bytes(), &msg); err != nil {
		t.Fatalf("failed to decode created message: %v", err)
	}

	if !strings.Contains(msg.Content, "Database Lock Warning") {
		t.Fatalf("expected event content to contain title, got: %s", msg.Content)
	}
}

func TestReseedEndpoint(t *testing.T) {
	srv, _ := setupTestServer()
	req := httptest.NewRequest("POST", "/api/seed", nil)
	w := httptest.NewRecorder()

	srv.Routes().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}
}
