package storage

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// IntentTag represents an educational callout badge shown on a message in the UI.
type IntentTag struct {
	Label       string `json:"label"`       // e.g. "Working Context: 1.4k tokens"
	Type        string `json:"type"`        // "context", "compaction", "scoping", "vector_hit", "permission"
	Color       string `json:"color"`       // UI color key: "sepia", "amber", "blue", "green", "slate"
	Description string `json:"description"` // Architectural explanation for talk attendee
}

// Era represents an evolutionary milestone in 30 years of chat and agent memory.
type Era struct {
	ID             string   `json:"id"`              // e.g. "era-1988-irc"
	Year           int      `json:"year"`            // 1988, 1997, 2006, 2013, 2017, 2026
	Name           string   `json:"name"`            // e.g. "The Ephemeral Buffer"
	Platform       string   `json:"platform"`        // "IRC & Unix talk"
	ChatParadigm   string   `json:"chat_paradigm"`   // "Line-Buffered Daemon Streams"
	MemoryConcept  string   `json:"memory_concept"`  // "Short-Term Memory & FIFO Eviction"
	Description    string   `json:"description"`     // Architectural explanation
	ActiveFeatures []string `json:"active_features"` // UI/Backend feature gates
}

// MemoryBuffer tracks Short-Term Memory FIFO buffer usage and eviction telemetry.
type MemoryBuffer struct {
	ChannelID      string   `json:"channel_id"`
	MaxTurns       int      `json:"max_turns"`       // Max message capacity before eviction (e.g. 5)
	CurrentTurns   int      `json:"current_turns"`   // Messages currently in buffer
	EvictedCount   int      `json:"evicted_count"`   // Total messages dropped over time
	LastEvictedMsg *Message `json:"last_evicted_msg,omitempty"` // Message evicted in the most recent turn
}

// AgentPresence represents the active cognitive and attentional state of an agent.
type AgentPresence struct {
	AgentID       string    `json:"agent_id"`       // e.g. "lead-agent"
	AgentName     string    `json:"agent_name"`     // "Lead Coordinator"
	AvatarURL     string    `json:"avatar_url"`
	Status        string    `json:"status"`         // "available", "away", "dnd", "typing"
	StatusMessage string    `json:"status_message"` // Away message or active task
	CurrentTask   string    `json:"current_task,omitempty"`
	LastHeartbeat time.Time `json:"last_heartbeat"`
}

// PrivateScratchpad stores an agent's individual cognitive working memory (Inner Monologue).
type PrivateScratchpad struct {
	AgentID       string    `json:"agent_id"`
	ChannelID     string    `json:"channel_id"`
	InnerThoughts []string  `json:"inner_thoughts"` // Step-by-step reasoning hidden from peers
	DraftPlan     string    `json:"draft_plan"`     // Tentative hypothesis or plan
	ToolTraces    []string  `json:"tool_traces"`    // Low-level tool executions and raw queries
	UpdatedAt     time.Time `json:"updated_at"`
}

// CrystallizedBelief represents an immutable, high-confidence consolidated fact distilled during REM dreaming.
type CrystallizedBelief struct {
	Key        string    `json:"key"`
	Value      string    `json:"value"`
	Category   string    `json:"category"`
	Confidence float64   `json:"confidence"`
	Keywords   string    `json:"keywords"`
	Statement  string    `json:"statement"`
	Embedding  []float64 `json:"embedding,omitempty"`
}

// UnmarshalJSON supports unmarshaling keywords from either a JSON array or a comma-separated string.
func (b *CrystallizedBelief) UnmarshalJSON(data []byte) error {
	type Alias CrystallizedBelief
	aux := struct {
		RawKeywords interface{} `json:"keywords"`
		*Alias
	}{
		Alias: (*Alias)(b),
	}
	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}
	switch kw := aux.RawKeywords.(type) {
	case string:
		b.Keywords = strings.TrimSpace(kw)
	case []interface{}:
		var parts []string
		for _, item := range kw {
			if item != nil {
				s := strings.TrimSpace(fmt.Sprint(item))
				if s != "" {
					parts = append(parts, s)
				}
			}
		}
		b.Keywords = strings.Join(parts, ", ")
	}
	return nil
}

// ConsolidationReport captures an offline Dreaming / Consolidation pass over episodic memory.
type ConsolidationReport struct {
	ID                  string               `json:"id"`
	ChannelID           string               `json:"channel_id"`
	PrunedMessages      int                  `json:"pruned_messages"`
	DistilledFacts      []string             `json:"distilled_facts"`
	InsightSummary      string               `json:"insight_summary"`
	CrystallizedBeliefs []CrystallizedBelief `json:"crystallized_beliefs"`
	DreamPromptUsed     string               `json:"dream_prompt_used,omitempty"`
	IntentTrajectory    string               `json:"intent_trajectory,omitempty"`
	CompletedAt         time.Time            `json:"completed_at"`
}

// Channel represents an isolated conversation domain or historical scenario.
type Channel struct {
	ID             string    `json:"id"`
	EraID          string    `json:"era_id"`          // "era-1988-irc", "era-1997-aim", etc.
	Name           string    `json:"name"`
	Topic          string    `json:"topic"`
	Description    string    `json:"description"`
	SystemPrompt   string    `json:"system_prompt"`
	RetentionHours int       `json:"retention_hours"`
	MaxBufferTurns int       `json:"max_buffer_turns,omitempty"` // > 0 enforces FIFO buffer eviction (Stage 1)
	IsDirectMessage bool     `json:"is_direct_message"`          // 1:1 direct dialogue (Stage 2)
	AllowedRoles   []string  `json:"allowed_roles,omitempty"`    // Role-based context fencing (Stage 3 & 6)
	CreatedAt      time.Time `json:"created_at"`
}

// Message represents an immutable chat event in the system audit trail.
type Message struct {
	ID         string                 `json:"id"`
	ChannelID  string                 `json:"channel_id"`
	ThreadID   string                 `json:"thread_id,omitempty"` // empty for root messages
	SenderType string                 `json:"sender_type"`        // "user", "agent", "system"
	SenderID   string                 `json:"sender_id"`          // "lead-agent", "scribe-agent", "researcher-agent", "jason"
	SenderName string                 `json:"sender_name"`        // Display name
	AvatarURL  string                 `json:"avatar_url"`
	Content    string                 `json:"content"`
	TokenCount int                    `json:"token_count"`
	Embedding  []float32              `json:"embedding,omitempty"`
	IntentTags []IntentTag            `json:"intent_tags,omitempty"`
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt  time.Time              `json:"created_at"`
}

// Summary represents a compacted state checkpoint generated by the Scribe agent.
type Summary struct {
	ID                    string    `json:"id"`
	ChannelID             string    `json:"channel_id"`
	ThreadID              string    `json:"thread_id,omitempty"`
	CoveredStartMessageID string    `json:"covered_start_message_id"`
	CoveredEndMessageID   string    `json:"covered_end_message_id"`
	CondensedState        string    `json:"condensed_state"`
	OriginalTokens        int       `json:"original_tokens"`
	CompactedTokens       int       `json:"compacted_tokens"`
	CompressionRatio      float64   `json:"compression_ratio"` // e.g. 0.85 means 85% token reduction
	CreatedAt             time.Time `json:"created_at"`
}

// VectorSearchResult holds a retrieved message along with mathematical similarity.
type VectorSearchResult struct {
	Message    Message `json:"message"`
	Similarity float32 `json:"similarity"` // 1.0 = identical, 0.0 = orthogonal, -1.0 = opposite
	Distance   float32 `json:"distance"`   // 1.0 - Similarity
}

// RetentionPolicy defines data lifecycle rules for channels and threads.
type RetentionPolicy struct {
	ChannelID      string        `json:"channel_id"`
	MaxAge         time.Duration `json:"max_age"`
	CompactOnEvict bool          `json:"compact_on_evict"`
}

// TelemetrySpan tracks real-time memory pipeline actions and latency for UI visualization.
type TelemetrySpan struct {
	ID          string                 `json:"id"`
	EraID       string                 `json:"era_id"`
	ChannelID   string                 `json:"channel_id"`
	ThreadID    string                 `json:"thread_id,omitempty"`
	Action      string                 `json:"action"` // "FIFO_WRITE", "FIFO_EVICT", "ATTENTIONAL_SHIFT", "FIREWALL_EVAL", "FIREWALL_QUARANTINE", "VECTOR_SEARCH", "LLM_INFERENCE", "SCRIBE_COMPACT", "DREAM_CONSOLIDATION", "STORE_WRITE"
	ActiveStep  int                    `json:"active_step"` // 1, 2, 3, 4
	Title       string                 `json:"title"`
	Description string                 `json:"description"`
	LatencyMs   int64                  `json:"latency_ms"`
	Metrics     map[string]interface{} `json:"metrics,omitempty"`
	Payload     string                 `json:"payload,omitempty"`
	Timestamp   time.Time              `json:"timestamp"`
}

