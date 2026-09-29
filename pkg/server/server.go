package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/jasondavenport/agents-of-chat/pkg/agent"
	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

// Server provides HTTP API and WebSocket routing for Agents of Chat.
type Server struct {
	store       storage.MemoryStore
	orchestrator *agent.Orchestrator
	hub         *WSHub
	staticDir   string
}

// NewServer creates a new server instance.
func NewServer(store storage.MemoryStore, orch *agent.Orchestrator, hub *WSHub, staticDir string) *Server {
	return &Server{
		store:        store,
		orchestrator: orch,
		hub:          hub,
		staticDir:    staticDir,
	}
}

// Routes sets up the HTTP handler.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/api/healthz", s.handleHealthz)

	// API Endpoints
	mux.HandleFunc("/api/eras", s.handleEras)
	mux.HandleFunc("/api/presence", s.handlePresence)
	mux.HandleFunc("/api/scratchpads", s.handleScratchpads)
	mux.HandleFunc("/api/channels", s.handleChannels)
	mux.HandleFunc("/api/channels/", s.handleChannelSubroutes)
	mux.HandleFunc("/api/seed", s.handleSeed)
	mux.HandleFunc("/api/pacing", s.handlePacing)
	mux.HandleFunc("/api/spanner/ddl", s.handleSpannerDDL)
	mux.HandleFunc("/api/database", s.handleDatabase)

	// WebSocket endpoint
	mux.HandleFunc("/ws", s.handleWebSocket)

	// Static web assets or fallback
	mux.HandleFunc("/", s.handleStatic)

	return s.corsMiddleware(mux)
}

func (s *Server) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	dbInfo := s.store.GetStorageInfo(r.Context())
	resp := map[string]interface{}{
		"status":        "healthy",
		"service":       "agents-of-chat",
		"timestamp":     time.Now().UTC().Format(time.RFC3339),
		"models":        []string{"gemini-3.8-flash"},
		"project":       "davenport-boutique",
		"database":      "Google BigQuery",
		"dataset":       "adk_agent_telemetry",
		"vector_engine": "BigQuery Vector Search (ML.DISTANCE COSINE)",
		"storage_info":  dbInfo,
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) handleDatabase(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	info := s.store.GetStorageInfo(r.Context())
	writeJSON(w, http.StatusOK, info)
}

func (s *Server) handleChannels(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	channels, err := s.store.ListChannels(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, channels)
}

// handleChannelSubroutes routes /api/channels/{id}/messages, /summaries, /events
func (s *Server) handleChannelSubroutes(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/channels/")
	parts := strings.Split(path, "/")
	if len(parts) < 2 {
		http.NotFound(w, r)
		return
	}

	channelID := parts[0]
	action := parts[1]

	switch action {
	case "messages":
		if r.Method == http.MethodGet {
			threadID := r.URL.Query().Get("thread_id")
			limitStr := r.URL.Query().Get("limit")
			limit := 50
			if limitStr != "" {
				if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
					limit = l
				}
			}
			msgs, err := s.store.ListMessages(r.Context(), channelID, threadID, limit)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusOK, msgs)
			return
		}

		if r.Method == http.MethodPost {
			var req struct {
				Content    string `json:"content"`
				ThreadID   string `json:"thread_id"`
				SenderName string `json:"sender_name"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "invalid request body", http.StatusBadRequest)
				return
			}
			if req.SenderName == "" {
				req.SenderName = "Jason Davenport"
			}
			msg, err := s.orchestrator.HandleIncomingUserMessage(r.Context(), channelID, req.ThreadID, req.Content, req.SenderName)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusCreated, msg)
			return
		}

	case "events":
		if r.Method == http.MethodPost {
			var req struct {
				Title    string `json:"title"`
				Details  string `json:"details"`
				ThreadID string `json:"thread_id"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "invalid request body", http.StatusBadRequest)
				return
			}
			msg, err := s.orchestrator.InjectScenarioEvent(r.Context(), channelID, req.ThreadID, req.Title, req.Details)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusCreated, msg)
			return
		}

	case "summaries":
		if r.Method == http.MethodGet {
			summaries, err := s.store.ListSummaries(r.Context(), channelID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusOK, summaries)
			return
		}

	case "buffer":
		if r.Method == http.MethodGet {
			buf, err := s.store.GetMemoryBuffer(r.Context(), channelID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusOK, buf)
			return
		}

	case "consolidate":
		if r.Method == http.MethodPost {
			report, err := s.orchestrator.ConsolidateMemory(r.Context(), channelID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusCreated, report)
			return
		}

	case "reports":
		if r.Method == http.MethodGet {
			reports, err := s.store.ListConsolidationReports(r.Context(), channelID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, http.StatusOK, reports)
			return
		}
	}

	http.NotFound(w, r)
}

func (s *Server) handleEras(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	eras, err := s.store.ListEras(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, eras)
}

func (s *Server) handlePresence(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		presences, err := s.store.ListAgentPresences(r.Context())
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, presences)
		return
	}

	if r.Method == http.MethodPost {
		var req storage.AgentPresence
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if err := s.orchestrator.UpdateAgentPresence(r.Context(), req); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, req)
		return
	}

	http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
}

func (s *Server) handleScratchpads(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		agentID := r.URL.Query().Get("agent_id")
		channelID := r.URL.Query().Get("channel_id")
		if agentID == "" || channelID == "" {
			http.Error(w, "missing agent_id or channel_id query param", http.StatusBadRequest)
			return
		}

		pad, err := s.store.GetPrivateScratchpad(r.Context(), agentID, channelID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, pad)
		return
	}

	if r.Method == http.MethodPost {
		var req storage.PrivateScratchpad
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if err := s.orchestrator.UpdatePrivateScratchpad(r.Context(), req); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, req)
		return
	}

	http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
}

func (s *Server) handleSeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if err := s.store.ResetAndSeed(r.Context()); err != nil {
		http.Error(w, fmt.Sprintf("failed to re-seed: %v", err), http.StatusInternalServerError)
		return
	}

	// Notify all connected UI clients that data re-seeded
	s.hub.BroadcastEvent("seed_reset", map[string]string{
		"status": "reseeded",
	})

	writeJSON(w, http.StatusOK, map[string]string{
		"message": "Talk scenarios re-seeded successfully",
	})
}

func (s *Server) handlePacing(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		writeJSON(w, http.StatusOK, s.orchestrator.GetPacing())
		return
	}

	if r.Method == http.MethodPost {
		var req agent.PacingMode
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}
		s.orchestrator.SetPacing(req)
		writeJSON(w, http.StatusOK, s.orchestrator.GetPacing())
		return
	}

	http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
}

func (s *Server) handleSpannerDDL(w http.ResponseWriter, r *http.Request) {
	resp := map[string]string{
		"ddl": storage.SpannerDDL,
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	_, err := s.hub.Upgrade(w, r)
	if err != nil {
		http.Error(w, fmt.Sprintf("websocket upgrade error: %v", err), http.StatusBadRequest)
		return
	}
}

func (s *Server) handleStatic(w http.ResponseWriter, r *http.Request) {
	if s.staticDir != "" {
		filePath := filepath.Join(s.staticDir, filepath.Clean(r.URL.Path))
		if stat, err := os.Stat(filePath); err == nil && !stat.IsDir() {
			http.ServeFile(w, r, filePath)
			return
		}

		// Fallback to index.html for Single Page App client-side routing
		indexPath := filepath.Join(s.staticDir, "index.html")
		if _, err := os.Stat(indexPath); err == nil {
			http.ServeFile(w, r, indexPath)
			return
		}
	}

	// Academic sepia status landing page if static bundle not present
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Agents of Chat: Architecture API</title>
<style>
body { background: #fbf9f5; color: #2c2925; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 40px; line-height: 1.6; }
.card { background: #fff; border: 1px solid #e7e2d9; border-radius: 8px; padding: 24px; max-width: 760px; margin: 0 auto; box-shadow: 0 2px 4px rgba(0,0,0,0.04); }
h1 { font-family: Georgia, serif; font-size: 24px; margin-top: 0; color: #1f1d1a; }
.pill { display: inline-block; background: #f0ece1; color: #5a544c; padding: 4px 10px; border-radius: 12px; font-size: 13px; font-weight: 500; margin-right: 6px; }
a { color: #8a5824; text-decoration: none; font-weight: 600; }
a:hover { text-decoration: underline; }
pre { background: #f4efe4; padding: 12px; border-radius: 6px; font-size: 13px; overflow-x: auto; }
</style>
</head>
<body>
<div class="card">
<h1>Agents of Chat: Core Engine Active</h1>
<p>Google Cloud Run Service: <code>davenport-boutique</code> (us-central1)</p>
<p>
<span class="pill">Gemini 3.8 Flash</span>
<span class="pill">Cloud Spanner Vector Search</span>
<span class="pill">WebSockets RFC 6455</span>
<span class="pill">Strict Zero Mocks</span>
</p>
<h3>Live API Endpoints</h3>
<ul>
<li><a href="/healthz">/healthz</a> — Service Health & Telemetry</li>
<li><a href="/api/channels">/api/channels</a> — Channels List</li>
<li><a href="/api/channels/chan-incident-postmortem/messages">/api/channels/chan-incident-postmortem/messages</a> — Event History Stream</li>
<li><a href="/api/spanner/ddl">/api/spanner/ddl</a> — Spanner Vector Index Schema</li>
</ul>
</div>
</body>
</html>`)
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
