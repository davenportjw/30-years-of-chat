package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jasondavenport/agents-of-chat/pkg/agent"
	"github.com/jasondavenport/agents-of-chat/pkg/server"
	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	staticDir := os.Getenv("STATIC_DIR")
	if staticDir == "" {
		staticDir = "frontend/build/web"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	// 1. Initialize Storage Layer (Embedded pure-Go memory store with exact vector math)
	store := storage.NewInMemStore()
	if err := store.ResetAndSeed(ctx); err != nil {
		log.Fatalf("failed to seed initial talk data: %v", err)
	}
	log.Printf("Storage initialized and talk scenarios seeded successfully")

	// 2. Initialize Gemini 3.8 Client
	geminiCfg := agent.DefaultGeminiConfig()
	geminiClient := agent.NewGeminiClient(geminiCfg)
	log.Printf("Gemini 3.8 client initialized for project %s (location: %s, model: %s)", geminiCfg.ProjectID, geminiCfg.Location, geminiCfg.Model)

	// 3. Initialize WebSocket Hub
	wsHub := server.NewWSHub()
	go wsHub.Run()
	log.Printf("WebSocket Hub event loop started")

	// 4. Initialize Multi-Agent Orchestrator
	orchestrator := agent.NewOrchestrator(store, geminiClient, wsHub.BroadcastEvent)
	log.Printf("Multi-Agent Orchestrator initialized (Lead, Scribe, Researcher)")

	// 5. Initialize Server & Routes
	srv := server.NewServer(store, orchestrator, wsHub, staticDir)
	httpHandler := srv.Routes()

	addr := fmt.Sprintf("0.0.0.0:%s", port)
	log.Printf("Agents of Chat server listening on %s", addr)
	if err := http.ListenAndServe(addr, httpHandler); err != nil {
		log.Fatalf("server terminated unexpectedly: %v", err)
	}
}
