package storage

import (
	"context"
)

// MemoryStore defines the complete persistent storage and retrieval interface
// for the Agents of Chat multi-agent memory system.
type MemoryStore interface {
	// Channel Operations
	CreateChannel(ctx context.Context, ch Channel) error
	GetChannel(ctx context.Context, id string) (*Channel, error)
	ListChannels(ctx context.Context) ([]Channel, error)

	// Message Operations (Audit trail & Event history)
	SaveMessage(ctx context.Context, msg Message) error
	GetMessage(ctx context.Context, id string) (*Message, error)
	ListMessages(ctx context.Context, channelID string, threadID string, limit int) ([]Message, error)
	CountMessages(ctx context.Context, channelID string, threadID string) (int, error)

	// Long-Term Memory Vector Search (RAG)
	SearchVectors(ctx context.Context, channelID string, queryEmbedding []float32, topK int) ([]VectorSearchResult, error)

	// Summaries & State Compaction
	SaveSummary(ctx context.Context, sum Summary) error
	GetLatestSummary(ctx context.Context, channelID string, threadID string) (*Summary, error)
	ListSummaries(ctx context.Context, channelID string) ([]Summary, error)

	// Retention Policies & Context Pruning
	ApplyRetentionPolicy(ctx context.Context, channelID string, maxAgeHours int) (int, error)

	// Eras Operations
	ListEras(ctx context.Context) ([]Era, error)
	GetEra(ctx context.Context, id string) (*Era, error)

	// Short-Term Memory Buffer & Eviction
	GetMemoryBuffer(ctx context.Context, channelID string) (*MemoryBuffer, error)

	// Agent Presence & Attentional State
	SetAgentPresence(ctx context.Context, presence AgentPresence) error
	GetAgentPresence(ctx context.Context, agentID string) (*AgentPresence, error)
	ListAgentPresences(ctx context.Context) ([]AgentPresence, error)

	// Private Working Memory (Scratchpad / Inner Monologue)
	SavePrivateScratchpad(ctx context.Context, pad PrivateScratchpad) error
	GetPrivateScratchpad(ctx context.Context, agentID string, channelID string) (*PrivateScratchpad, error)

	// Dreaming & Memory Consolidation Reports
	SaveConsolidationReport(ctx context.Context, report ConsolidationReport) error
	ListConsolidationReports(ctx context.Context, channelID string) ([]ConsolidationReport, error)

	// Crystallized Beliefs (Long-Term Semantic Consolidation & Fast-Path Recall)
	SaveCrystallizedBeliefs(ctx context.Context, channelID string, beliefs []CrystallizedBelief) error
	SearchCrystallizedBeliefs(ctx context.Context, channelID string, query string) ([]CrystallizedBelief, error)

	// Seed & Reset Data
	ResetAndSeed(ctx context.Context) error

	// Storage & Vector Store Metadata
	GetStorageInfo(ctx context.Context) map[string]interface{}

	// Lifecycle
	Close() error
}
