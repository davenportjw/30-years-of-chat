package storage

import (
	"context"
	"time"
)

// SeedTalkScenarios populates the storage backend with realistic data
// representing the 30-year evolution of chat and agent memory.
func SeedTalkScenarios(ctx context.Context, store MemoryStore) error {
	baseTime := time.Now().Add(-2 * time.Hour)

	// ==========================================
	// 0. Seed the 6 Historical Eras
	// ==========================================
	eras := []Era{
		{
			ID:             "era-1988-irc",
			Year:           1988,
			Name:           "The Ephemeral Buffer",
			Platform:       "IRC & Unix talk",
			ChatParadigm:   "Line-Buffered Daemon Streams",
			MemoryConcept:  "Short-Term Memory & FIFO Eviction",
			Description:    "Volatile in-memory FIFO sliding window that retains the latest message turns within a bounded context buffer.",
			ActiveFeatures: []string{"fifo_buffer", "terminal_mode", "eviction_gauge"},
		},
		{
			ID:             "era-1997-aim",
			Year:           1997,
			Name:           "The 1:1 Direct Session & Presence",
			Platform:       "AOL Instant Messenger & ICQ",
			ChatParadigm:   "Stateful 1:1 DMs & Buddy Presence",
			MemoryConcept:  "Working Memory & Attentional State",
			Description:    "Direct user-agent session isolation. Introduces agent presence (available, away, typing) as attentional liveness, and away messages as dynamic system prompt persona priming.",
			ActiveFeatures: []string{"buddy_list", "presence_state", "away_message", "1on1_session"},
		},
		{
			ID:             "era-2006-jabber",
			Year:           2006,
			Name:           "Scoped Rooms & Context Fencing",
			Platform:       "Jabber & Scoped Rooms",
			ChatParadigm:   "Project-Scoped Multi-User Rooms",
			MemoryConcept:  "Search Isolation & Context Fencing",
			Description:    "Domain-partitioned memory rooms. Isolates project topics and applies role-based permissions across channel perimeters.",
			ActiveFeatures: []string{"context_fencing", "topic_isolation", "role_permissions"},
		},
		{
			ID:             "era-2013-hipchat",
			Year:           2013,
			Name:           "The Searchable Vector Archive",
			Platform:       "HipChat & Cloud Archive",
			ChatParadigm:   "Persistent Cloud Log & Webhooks",
			MemoryConcept:  "Long-Term Memory (LTM): Vector Search RAG",
			Description:    "Append-only persistent cloud event storage. Autonomous agents query vector indexes via cosine distance to recall past incidents and ADRs, triggered by inbound telemetry webhooks.",
			ActiveFeatures: []string{"vector_search", "vector_rag", "webhooks", "event_log"},
		},
		{
			ID:             "era-2017-threads",
			Year:           2017,
			Name:           "Threads & Scribe Compaction",
			Platform:       "Discord Forums & Threaded Chat",
			ChatParadigm:   "Thread Branching & Collapsible Scratchpads",
			MemoryConcept:  "Sub-Task Isolation & Hierarchical State Rollup",
			Description:    "Branching complex investigations into thread scratchpads preserves main-channel token budgets. A Scribe agent rolls up resolved threads into compact checkpoints (-96% tokens).",
			ActiveFeatures: []string{"threads", "scribe_compaction", "token_meter", "hierarchical_rollup"},
		},
		{
			ID:             "era-2026-agent-mesh",
			Year:           2026,
			Name:           "Collaborative Multi-Agent Mesh",
			Platform:       "Agents of Chat Workspace",
			ChatParadigm:   "Shared Canvas with Autonomous Swarm",
			MemoryConcept:  "Dual-Layer Memory: Shared Blackboard vs Private Inner Monologue",
			Description:    "Modern end-state: Human commander orchestrates Lead, Scribe, and Researcher agents. Features private cognitive scratchpads, role fencing, and background Dreaming memory consolidation.",
			ActiveFeatures: []string{"dual_layer_memory", "private_scratchpad", "dreaming_consolidation", "multi_agent_mesh"},
		},
	}

	for _, era := range eras {
		if inMem, ok := store.(*InMemStore); ok {
			if err := inMem.CreateEra(ctx, era); err != nil {
				return err
			}
		}
	}

	// Semantic prototype vectors for realistic cosine similarity search
	vInc := []float32{0.82, 0.74, 0.21, 0.12, 0.91, 0.15, 0.05, 0.88, 0.79, 0.18, 0.11, 0.85, 0.14, 0.06, 0.83, 0.77}
	vNet := []float32{0.78, 0.81, 0.19, 0.14, 0.84, 0.22, 0.08, 0.82, 0.85, 0.16, 0.12, 0.81, 0.18, 0.09, 0.79, 0.83}
	vDB := []float32{0.85, 0.68, 0.25, 0.10, 0.95, 0.11, 0.03, 0.91, 0.72, 0.22, 0.09, 0.89, 0.12, 0.04, 0.88, 0.71}
	vArch := []float32{0.12, 0.24, 0.88, 0.92, 0.14, 0.86, 0.22, 0.15, 0.22, 0.89, 0.94, 0.12, 0.85, 0.25, 0.18, 0.28}
	vDBArch := []float32{0.18, 0.29, 0.82, 0.87, 0.21, 0.81, 0.28, 0.21, 0.27, 0.84, 0.89, 0.19, 0.82, 0.31, 0.22, 0.32}
	vProd := []float32{0.22, 0.15, 0.31, 0.25, 0.12, 0.28, 0.92, 0.88, 0.21, 0.18, 0.32, 0.24, 0.11, 0.29, 0.89, 0.85}
	vBasic := []float32{0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50}

	// ==========================================
	// Scenario 1: #1988-irc-terminal
	// Epoch: 1988 IRC — Ephemeral Short-Term Memory Buffer
	// ==========================================
	chanIRC := Channel{
		ID:             "chan-1988-irc",
		EraID:          "era-1988-irc",
		Name:           "1988-irc-terminal",
		Topic:          "irc.funet.fi #dev — Line-buffered daemon stream (Max Capacity: 5 turns)",
		Description:    "Demonstrates Short-Term Memory (STM) and FIFO buffer displacement. Once 5 turns are reached, older turns drop off.",
		SystemPrompt:   "You are an early IRC Eggdrop bot responding to channel triggers. You have zero persistent memory; only the immediate sliding window buffer is visible to you.",
		RetentionHours: 1,
		MaxBufferTurns: 5,
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanIRC); err != nil {
		return err
	}

	ircMsgs := []Message{
		{
			ID:         "msg-irc-01",
			ChannelID:  chanIRC.ID,
			SenderType: "system",
			SenderID:   "ircd",
			SenderName: "irc.funet.fi",
			AvatarURL:  "https://api.dicebear.com/7.x/identicon/svg?seed=ircd",
			Content:    "*** Connected to irc.funet.fi (1988-10-14). Channel mode: +nt #dev. Buffer: 5 turns allocated in volatile daemon RAM.",
			TokenCount: 65,
			Embedding:  vBasic,
			IntentTags: []IntentTag{
				{
					Label:       "STM: Ephemeral Buffer (FIFO)",
					Type:        "context",
					Color:       "sepia",
					Description: "Short-Term Memory pattern: Ephemeral volatile buffer with fixed turn capacity.",
				},
			},
			CreatedAt: baseTime.Add(1 * time.Minute),
		},
		{
			ID:         "msg-irc-02",
			ChannelID:  chanIRC.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "jason",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "!bot info --sys",
			TokenCount: 30,
			Embedding:  vBasic,
			IntentTags: []IntentTag{
				{
					Label:       "Sensory Input: Command Trigger",
					Type:        "context",
					Color:       "slate",
					Description: "Stateless command trigger evaluated by early bot logic.",
				},
			},
			CreatedAt: baseTime.Add(2 * time.Minute),
		},
		{
			ID:         "msg-irc-03",
			ChannelID:  chanIRC.ID,
			SenderType: "agent",
			SenderID:   "eggdrop-bot",
			SenderName: "Eggdrop Bot",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=eggdrop",
			Content:    "[Eggdrop v1.1] System OK. Memory: 512KB volatile RAM. Active turns: 3/5. Notice: When message 6 arrives, message 1 will be permanently evicted from working context.",
			TokenCount: 95,
			Embedding:  vBasic,
			IntentTags: []IntentTag{
				{
					Label:       "Amnesia Warning: Recency Bias",
					Type:        "context",
					Color:       "amber",
					Description: "Demonstrates context window saturation and impending FIFO eviction.",
				},
			},
			CreatedAt: baseTime.Add(3 * time.Minute),
		},
		{
			ID:         "msg-irc-04",
			ChannelID:  chanIRC.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "jason",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "!set-var PROD_SECRET_KEY=948201",
			TokenCount: 45,
			Embedding:  vBasic,
			IntentTags: []IntentTag{
				{
					Label:       "Volatile Fact Ingestion",
					Type:        "context",
					Color:       "amber",
					Description: "Fact stored ONLY in transient buffer; will be forgotten upon buffer overflow.",
				},
			},
			CreatedAt: baseTime.Add(4 * time.Minute),
		},
	}
	for _, m := range ircMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// ==========================================
	// Scenario 2: #1997-aim-direct-chat
	// Epoch: 1997 AIM — Working Memory & Attentional Presence
	// ==========================================
	chanAIMLead := Channel{
		ID:              "chan-1997-aim",
		EraID:           "era-1997-aim",
		Name:            "1997-aim-lead",
		Topic:           "1:1 Direct Message: Jason Davenport <-> Lead Coordinator",
		Description:     "Dedicated 1:1 working memory session with Lead Coordinator.",
		SystemPrompt:    "You are the Lead Coordinator in a private 1-on-1 direct messaging session. Your focus is direct assistance, maintaining session state, and reporting active presence.",
		RetentionHours:  24,
		IsDirectMessage: true,
		AllowedRoles:    []string{"lead-agent"},
		CreatedAt:       baseTime,
	}
	if err := store.CreateChannel(ctx, chanAIMLead); err != nil {
		return err
	}

	chanAIMScribe := Channel{
		ID:              "chan-1997-aim-scribe",
		EraID:           "era-1997-aim",
		Name:            "1997-aim-scribe",
		Topic:           "1:1 Direct Message: Jason Davenport <-> Staff Architect Scribe",
		Description:     "Dedicated 1:1 working memory session with Staff Architect Scribe.",
		SystemPrompt:    "You are the Staff Architect Scribe in a private 1-on-1 direct messaging session. Your focus is architectural memory compaction, hierarchical rollups, and system design clarity.",
		RetentionHours:  24,
		IsDirectMessage: true,
		AllowedRoles:    []string{"scribe-agent"},
		CreatedAt:       baseTime,
	}
	if err := store.CreateChannel(ctx, chanAIMScribe); err != nil {
		return err
	}

	chanAIMResearcher := Channel{
		ID:              "chan-1997-aim-researcher",
		EraID:           "era-1997-aim",
		Name:            "1997-aim-researcher",
		Topic:           "1:1 Direct Message: Jason Davenport <-> Dev Researcher",
		Description:     "Dedicated 1:1 working memory session with Dev Researcher.",
		SystemPrompt:    "You are Dev Researcher in a private 1-on-1 direct messaging session. Your focus is technical deep-dives, vector search retrieval, and ADR citation.",
		RetentionHours:  24,
		IsDirectMessage: true,
		AllowedRoles:    []string{"researcher-agent"},
		CreatedAt:       baseTime,
	}
	if err := store.CreateChannel(ctx, chanAIMResearcher); err != nil {
		return err
	}

	aimMsgs := []Message{
		// Lead Coordinator 1:1
		{
			ID:         "msg-aim-01",
			ChannelID:  chanAIMLead.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Hey @lead-agent, are you available to review the multi-agent deployment script?",
			TokenCount: 50,
			Embedding:  vProd,
			IntentTags: []IntentTag{
				{
					Label:       "Working Memory: 1:1 Session",
					Type:        "context",
					Color:       "amber",
					Description: "Dedicated working memory partition tracks private user-agent dialogue state.",
				},
			},
			CreatedAt: baseTime.Add(10 * time.Minute),
		},
		{
			ID:         "msg-aim-02",
			ChannelID:  chanAIMLead.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "🔔 **[Away Message Status: Available]**\nI'm online and reviewing your request. In 1:1 working memory mode, my attention is dedicated exclusively to this dialogue session without multi-user cross-talk contamination.",
			TokenCount: 110,
			Embedding:  vProd,
			IntentTags: []IntentTag{
				{
					Label:       "Presence: Attentional State",
					Type:        "permission",
					Color:       "green",
					Description: "Presence as attentional liveness: Agent communicates active cognitive availability.",
				},
			},
			CreatedAt: baseTime.Add(11 * time.Minute),
		},
		// Scribe 1:1
		{
			ID:         "msg-aim-scribe-01",
			ChannelID:  chanAIMScribe.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Scribe, how does hierarchical state rollup prevent context window saturation?",
			TokenCount: 45,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Working Memory: 1:1 Session",
					Type:        "context",
					Color:       "amber",
					Description: "Dedicated working memory partition tracks private user-agent dialogue state.",
				},
			},
			CreatedAt: baseTime.Add(12 * time.Minute),
		},
		{
			ID:         "msg-aim-scribe-02",
			ChannelID:  chanAIMScribe.ID,
			SenderType: "agent",
			SenderID:   "scribe-agent",
			SenderName: "Staff Architect Scribe",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=scribe",
			Content:    "🔔 **[Away Message Status: Available]**\nBy aggregating event turn deltas into structured summaries, we achieve over 95% token compression while maintaining complete causal continuity in working memory.",
			TokenCount: 105,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Compaction: Hierarchical Rollup",
					Type:        "compaction",
					Color:       "sepia",
					Description: "Scribe generates structured summaries of active threads.",
				},
			},
			CreatedAt: baseTime.Add(13 * time.Minute),
		},
		// Dev Researcher 1:1
		{
			ID:         "msg-aim-research-01",
			ChannelID:  chanAIMResearcher.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Dev Researcher, can you verify our vector index status for long-term memory retrieval?",
			TokenCount: 52,
			Embedding:  vInc,
			IntentTags: []IntentTag{
				{
					Label:       "Working Memory: 1:1 Session",
					Type:        "context",
					Color:       "amber",
					Description: "Dedicated working memory partition tracks private user-agent dialogue state.",
				},
			},
			CreatedAt: baseTime.Add(14 * time.Minute),
		},
		{
			ID:         "msg-aim-research-02",
			ChannelID:  chanAIMResearcher.ID,
			SenderType: "agent",
			SenderID:   "researcher-agent",
			SenderName: "Dev Researcher",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
			Content:    "🔔 **[Away Message Status: Available]**\nYes! Vector indexes are partitioned with cosine distance metrics. ADR-019 and historical incident post-mortems are indexed and ready for retrieval.",
			TokenCount: 115,
			Embedding:  vInc,
			IntentTags: []IntentTag{
				{
					Label:       "Long-Term Memory: Vector RAG",
					Type:        "rag",
					Color:       "blue",
					Description: "Dev Researcher pulls embeddings from vector index.",
				},
			},
			CreatedAt: baseTime.Add(15 * time.Minute),
		},
	}
	for _, m := range aimMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// ==========================================
	// Scenario 3: #2006-jabber-rooms
	// Epoch: 2006 Jabber — Scoped Rooms & Context Fencing
	// ==========================================
	chanJabberLobby := Channel{
		ID:             "chan-2006-jabber-lobby",
		EraID:          "era-2006-jabber",
		Name:           "2006-jabber-lobby",
		Topic:          "Watercooler & Company Announcements",
		Description:    "General open lobby room for company-wide chat. No restrictive context fence.",
		SystemPrompt:   "You are in the general lobby. Company announcements, welcoming team members, and general questions live here.",
		RetentionHours: 48,
		AllowedRoles:   []string{},
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanJabberLobby); err != nil {
		return err
	}

	chanJabberEng := Channel{
		ID:             "chan-2006-jabber-eng",
		EraID:          "era-2006-jabber",
		Name:           "2006-jabber-eng",
		Topic:          "Frontend & Services Architecture",
		Description:    "Engineering discussions for services, infrastructure, and user interfaces.",
		SystemPrompt:   "You are in the engineering room. Discussions center on code compilation, frontend widgets, and service deployment.",
		RetentionHours: 48,
		AllowedRoles:   []string{"lead-agent", "scribe-agent", "researcher-agent", "jason"},
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanJabberEng); err != nil {
		return err
	}

	chanJabberBilling := Channel{
		ID:             "chan-2006-jabber-billing",
		EraID:          "era-2006-jabber",
		Name:           "2006-jabber-billing",
		Topic:          "Project Apollo: Billing Engine & Consistency Rules [Confidential]",
		Description:    "Domain-scoped group room enforcing context fencing. Quarantines billing architectural parameters from other rooms.",
		SystemPrompt:   "You are the Apollo billing engineering room. All discussion is strictly scoped to ledger consistency and idempotency. Reject out-of-domain marketing or frontend queries.",
		RetentionHours: 48,
		AllowedRoles:   []string{"lead-agent", "scribe-agent", "jason"},
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanJabberBilling); err != nil {
		return err
	}

	jabberMsgs := []Message{
		// General Lobby
		{
			ID:         "msg-camp-lobby-01",
			ChannelID:  chanJabberLobby.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Welcome everyone to Jabber. Remember that confidential project topics must stay fenced to their respective rooms.",
			TokenCount: 65,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Scoped Rooms: Web 2.0 Group Chat",
					Type:        "scoping",
					Color:       "sepia",
					Description: "General room accessible to all team members.",
				},
			},
			CreatedAt: baseTime.Add(14 * time.Minute),
		},
		{
			ID:         "msg-camp-lobby-02",
			ChannelID:  chanJabberLobby.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "Understood! Announcements and general inquiries live here in #general-lobby, while billing ledger discussions are strictly fenced in #billing-confidential.",
			TokenCount: 75,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Unfenced: Open Retrieval",
					Type:        "scoping",
					Color:       "green",
					Description: "No role quarantine active in lobby room.",
				},
			},
			CreatedAt: baseTime.Add(15 * time.Minute),
		},
		// Engineering
		{
			ID:         "msg-camp-eng-01",
			ChannelID:  chanJabberEng.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Frontend build pipeline migrated to Flutter Web with WebSockets.",
			TokenCount: 55,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Domain Scoping: Engineering",
					Type:        "scoping",
					Color:       "sepia",
					Description: "Technical room for engineering discussions.",
				},
			},
			CreatedAt: baseTime.Add(15 * time.Minute),
		},
		{
			ID:         "msg-camp-eng-02",
			ChannelID:  chanJabberEng.ID,
			SenderType: "agent",
			SenderID:   "researcher-agent",
			SenderName: "Dev Researcher",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
			Content:    "Confirmed! Vector index embeddings match the schema requirements and service latency is within SLA.",
			TokenCount: 70,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Engineering Scope",
					Type:        "rag",
					Color:       "blue",
					Description: "Dev Researcher participating in engineering discussions.",
				},
			},
			CreatedAt: baseTime.Add(16 * time.Minute),
		},
		// Billing Confidential
		{
			ID:         "msg-camp-01",
			ChannelID:  chanJabberBilling.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Team: Welcome to the Apollo Billing room. Remember: all discussion here is strictly fenced to financial transaction consistency. No frontend UI discussions allowed here.",
			TokenCount: 80,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Search Isolation: Domain Fenced",
					Type:        "scoping",
					Color:       "sepia",
					Description: "Context Fencing pattern: Room topic establishes rigid cognitive perimeter.",
				},
			},
			CreatedAt: baseTime.Add(17 * time.Minute),
		},
		{
			ID:         "msg-camp-02",
			ChannelID:  chanJabberBilling.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "Understood. Context fencing active for #billing-confidential. Knowledge retrieval queries are restricted to ledger domain models to prevent associative bleed.",
			TokenCount: 90,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Fencing: Anti-Associative Bleed",
					Type:        "permission",
					Color:       "sepia",
					Description: "Fencing prevents irrelevant memories from contaminating attention.",
				},
			},
			CreatedAt: baseTime.Add(18 * time.Minute),
		},
	}
	for _, m := range jabberMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// ==========================================
	// Scenario 4: #2013-hipchat-archive (Incident Post-Mortem)
	// Epoch: 2013 HipChat — Long-Term Memory (LTM) & Vector RAG
	// ==========================================
	chanHipchat := Channel{
		ID:             "chan-incident-postmortem",
		EraID:          "era-2013-hipchat",
		Name:           "2013-hipchat-archive",
		Topic:          "P0 Production Outage: Auth Gateway 504 Latency & Lock Exhaustion",
		Description:    "War room for incident triage. Demonstrates Vector Search (RAG) and sensory webhook alert perception.",
		SystemPrompt:   "You are an incident response engineering team. Focus on fast triage, root cause analysis, mitigation, and post-mortem generation.",
		RetentionHours: 72,
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanHipchat); err != nil {
		return err
	}

	hipchatMsgs := []Message{
		{
			ID:         "msg-inc-01",
			ChannelID:  chanHipchat.ID,
			SenderType: "system",
			SenderID:   "sentry-bot",
			SenderName: "Sentry Alerts",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=sentry",
			Content:    "🚨 **CRITICAL WEBHOOK ALERT**: HTTP 504 Gateway Timeout rate exceeded 18.4% on `service-auth-proxy`. p99 latency spiked to 9,420ms.",
			TokenCount: 142,
			Embedding:  vInc,
			IntentTags: []IntentTag{
				{
					Label:       "Webhook Ingestion: Sensory Stimulus",
					Type:        "context",
					Color:       "sepia",
					Description: "Machine event webhook injects perception directly into agent attention.",
				},
			},
			CreatedAt: baseTime.Add(20 * time.Minute),
		},
		{
			ID:         "msg-inc-02",
			ChannelID:  chanHipchat.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "@lead-agent @researcher-agent auth service is shedding load. Initiate P0 incident procedure immediately.",
			TokenCount: 88,
			Embedding:  vInc,
			IntentTags: []IntentTag{
				{
					Label:       "Human In Loop: Dispatch",
					Type:        "context",
					Color:       "slate",
					Description: "Human incident commander activates autonomous multi-agent response.",
				},
			},
			CreatedAt: baseTime.Add(21 * time.Minute),
		},
		{
			ID:         "msg-inc-03",
			ChannelID:  chanHipchat.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "Incident Commander active. Status: P0 declared. Objectives:\n1. Isolate blast radius\n2. Scribe: maintain rolling timeline\n3. Researcher: query past post-mortems for lock contention.",
			TokenCount: 210,
			Embedding:  vInc,
			IntentTags: []IntentTag{
				{
					Label:       "Working Context: Active Goals",
					Type:        "context",
					Color:       "amber",
					Description: "Working Context: Agent coordinates active goals without polluting long-term memory.",
				},
			},
			CreatedAt: baseTime.Add(22 * time.Minute),
		},
		{
			ID:         "msg-inc-04",
			ChannelID:  chanHipchat.ID,
			SenderType: "agent",
			SenderID:   "researcher-agent",
			SenderName: "Dev Researcher",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
			Content:    "Querying vector index for `connection pool exhausted lock contention`...\nFound high-relevance match:\n• **INC-2026-04**: Batch reconciliation worker saturated `auth_tokens` row locks during token expiry sweep.\n• Recommended fix: Throttle batch worker concurrency from 64 to 8.",
			TokenCount: 320,
			Embedding:  vDB,
			IntentTags: []IntentTag{
				{
					Label:       "Vector Hit: 0.94 sim",
					Type:        "vector_hit",
					Color:       "blue",
					Description: "Long-Term Memory Search: Vector Search retrieved incident post-mortem from 5 months ago.",
				},
			},
			CreatedAt: baseTime.Add(24 * time.Minute),
		},
		{
			ID:         "msg-inc-05",
			ChannelID:  chanHipchat.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "Confirmed. Batch worker `cron-token-reap` was deployed at 02:00 UTC with unthrottled worker threads. Scaling replica count to 0 to relieve DB connection lockup.",
			TokenCount: 165,
			Embedding:  vDB,
			IntentTags: []IntentTag{
				{
					Label:       "Action: Mitigation",
					Type:        "context",
					Color:       "green",
					Description: "State transition: Incident state moves from Triage to Mitigated.",
				},
			},
			CreatedAt: baseTime.Add(26 * time.Minute),
		},
		{
			ID:         "msg-inc-06",
			ChannelID:  chanHipchat.ID,
			SenderType: "system",
			SenderID:   "datadog-bot",
			SenderName: "Telemetry Bot",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=telemetry",
			Content:    "✅ Latency recovered: p99 dropped from 9,420ms to 42ms. 504 errors: 0.00%. All auth health checks passing.",
			TokenCount: 95,
			Embedding:  vNet,
			IntentTags: []IntentTag{
				{
					Label:       "Telemetry: Resolved",
					Type:        "context",
					Color:       "green",
					Description: "Event History: Automated verification confirms resolution.",
				},
			},
			CreatedAt: baseTime.Add(29 * time.Minute),
		},
	}
	for _, m := range hipchatMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// ==========================================
	// Scenario 5: #2017-threads-compaction
	// Epoch: 2017 Threads — Sub-Task Scratchpad & Scribe Compaction
	// ==========================================
	chanThreads := Channel{
		ID:             "chan-architecture-rfc",
		EraID:          "era-2017-threads",
		Name:           "2017-threads-compaction",
		Topic:          "RFC 042: Event-Driven Transactional Outbox vs Synchronous 2PC",
		Description:    "Deep architectural review. Demonstrates threads as isolated working scratchpads, rolled up by Scribe.",
		SystemPrompt:   "You are principal software architects reviewing system design documents, evaluating latency, consistency, and token efficiency.",
		RetentionHours: 168,
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanThreads); err != nil {
		return err
	}

	rfcRootMsgs := []Message{
		{
			ID:         "msg-rfc-root-01",
			ChannelID:  chanThreads.ID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "Team: RFC 042 is up for review. We need to decide between a Kafka Transactional Outbox pattern or relying on multi-region synchronous distributed transactions for the new billing ledger.",
			TokenCount: 175,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Root Context: Architecture Review",
					Type:        "scoping",
					Color:       "sepia",
					Description: "Channels pattern: Scoped context boundaries prevent irrelevant conversation from leaking.",
				},
			},
			CreatedAt: baseTime.Add(35 * time.Minute),
		},
		{
			ID:         "msg-rfc-root-02",
			ChannelID:  chanThreads.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "I'm branching the deep transactional analysis into a dedicated thread: **'RFC 042: Consistency vs Latency Trade-offs'**. This isolates 40+ iterative reasoning turns so our main channel context window remains concise.",
			TokenCount: 220,
			Embedding:  vArch,
			IntentTags: []IntentTag{
				{
					Label:       "Thread Branch: Active Scratchpad",
					Type:        "context",
					Color:       "amber",
					Description: "Threads pattern: Dedicated scratchpad keeps deep deliberation organized.",
				},
			},
			CreatedAt: baseTime.Add(37 * time.Minute),
		},
	}
	for _, m := range rfcRootMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// Thread messages inside "thread-rfc-042"
	threadID := "thread-rfc-042"
	rfcThreadMsgs := []Message{
		{
			ID:         "msg-rfc-th-01",
			ChannelID:  chanThreads.ID,
			ThreadID:   threadID,
			SenderType: "user",
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
			Content:    "@researcher-agent didn't we encounter serious double-charge race conditions when trying asynchronous messaging in 2025?",
			TokenCount: 110,
			Embedding:  vDBArch,
			IntentTags: []IntentTag{
				{
					Label:       "Query: Long-Term Memory",
					Type:        "context",
					Color:       "slate",
					Description: "Prompting agent to retrieve past architectural decisions.",
				},
			},
			CreatedAt: baseTime.Add(40 * time.Minute),
		},
		{
			ID:         "msg-rfc-th-02",
			ChannelID:  chanThreads.ID,
			ThreadID:   threadID,
			SenderType: "agent",
			SenderID:   "researcher-agent",
			SenderName: "Dev Researcher",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
			Content:    "🔍 **Retrieved from Vector Index (ADR-019)**:\nYes! In March 2025, async event broker lag caused duplicate webhook dispatch to Stripe during an outage. ADR-019 concluded:\n*'For financial accounting and balance mutations, synchronous transactions with idempotency keys are mandatory to guarantee external consistency.'*",
			TokenCount: 340,
			Embedding:  vDBArch,
			IntentTags: []IntentTag{
				{
					Label:       "Vector Hit: 0.96 sim",
					Type:        "vector_hit",
					Color:       "blue",
					Description: "Long-term RAG: Researcher retrieved exact ADR-019 memory without polluting prompt with irrelevant docs.",
				},
			},
			CreatedAt: baseTime.Add(42 * time.Minute),
		},

	}
	for _, m := range rfcThreadMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// Canonical compaction summary
	rfcSummary := Summary{
		ID:                    "sum-rfc-01",
		ChannelID:             chanThreads.ID,
		ThreadID:              threadID,
		CoveredStartMessageID: "msg-rfc-th-01",
		CoveredEndMessageID:   "msg-rfc-th-02",
		CondensedState:        "CONSENSUS REACHED (RFC 042): Adopt synchronous 2PC with idempotency keys for financial mutations per ADR-019. Async outbox rejected due to webhook duplicate billing hazard.",
		OriginalTokens:        9800,
		CompactedTokens:       380,
		CompressionRatio:      0.961,
		CreatedAt:             baseTime.Add(46 * time.Minute),
	}
	if err := store.SaveSummary(ctx, rfcSummary); err != nil {
		return err
	}

	// ==========================================
	// Scenario 6: #2026-agent-mesh
	// Epoch: 2026 Agent Mesh — Shared vs Private Memory & Dreaming
	// ==========================================
	chanMesh := Channel{
		ID:             "chan-product-launch",
		EraID:          "era-2026-agent-mesh",
		Name:           "2026-agent-mesh",
		Topic:          "Agents of Chat GA Launch: Multi-Agent Mesh & Dreaming Consolidation",
		Description:    "Autonomous multi-agent workspace showing shared blackboard, private inner monologues, and Dreaming consolidation.",
		SystemPrompt:   "You are an agile software delivery team coordinating product launch deliverables, security audits, and deployment sign-offs. Keep all responses extremely terse (2 to 3 lines maximum) for live demo readability.",
		RetentionHours: 48,
		CreatedAt:      baseTime,
	}
	if err := store.CreateChannel(ctx, chanMesh); err != nil {
		return err
	}

	meshMsgs := []Message{
		{
			ID:         "msg-launch-01",
			ChannelID:  chanMesh.ID,
			SenderType: "agent",
			SenderID:   "lead-agent",
			SenderName: "Lead Coordinator",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Content:    "🚀 **GA Launch Checklist Status [Shared Team Blackboard]**:\n- [x] BigQuery Vector Search schemas verified\n- [x] WebSocket multi-agent streaming operational\n- [x] Secret Manager credential fencing confirmed\n- [ ] Cloud Run production verification probe passed",
			TokenCount: 260,
			Embedding:  vProd,
			IntentTags: []IntentTag{
				{
					Label:       "Shared Memory: Team Blackboard",
					Type:        "context",
					Color:       "amber",
					Description: "Shared Memory: Public transcript visible to all team agents and the human Commander.",
				},
				{
					Label:       "Permission: Role Fencing",
					Type:        "permission",
					Color:       "sepia",
					Description: "Context fencing blocks credentials from leaking into unprivileged agent prompts.",
				},
			},
			CreatedAt: baseTime.Add(50 * time.Minute),
		},
		{
			ID:         "msg-launch-02",
			ChannelID:  chanMesh.ID,
			SenderType: "agent",
			SenderID:   "researcher-agent",
			SenderName: "Dev Researcher",
			AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
			Content:    "Security Audit complete. Verified that zero API keys or service account tokens are exposed in Git history or client-side assets. All auth adheres to Google Cloud ADC.",
			TokenCount: 195,
			Embedding:  vProd,
			IntentTags: []IntentTag{
				{
					Label:       "Security: Zero Secrets Verified",
					Type:        "permission",
					Color:       "green",
					Description: "Audit Trail: Security sign-off permanently recorded in BigQuery event log.",
				},
			},
			CreatedAt: baseTime.Add(55 * time.Minute),
		},
	}
	for _, m := range meshMsgs {
		if err := store.SaveMessage(ctx, m); err != nil {
			return err
		}
	}

	// ==========================================
	// 7. Seed Presences, Private Scratchpad & Dreaming Report
	// ==========================================
	presences := []AgentPresence{
		{
			AgentID:       "lead-agent",
			AgentName:     "Lead Coordinator",
			AvatarURL:     "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
			Status:        "available",
			StatusMessage: "Coordinating multi-agent workflow & working memory",
			CurrentTask:   "Monitoring deployment queues",
			LastHeartbeat: time.Now(),
		},
		{
			AgentID:       "scribe-agent",
			AgentName:     "Staff Architect Scribe",
			AvatarURL:     "https://api.dicebear.com/7.x/bottts/svg?seed=scribe",
			Status:        "available",
			StatusMessage: "Compacting event histories & generating rollups",
			CurrentTask:   "Watching thread closures",
			LastHeartbeat: time.Now(),
		},
		{
			AgentID:       "researcher-agent",
			AgentName:     "Dev Researcher",
			AvatarURL:     "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
			Status:        "available",
			StatusMessage: "Querying vector indexes",
			CurrentTask:   "Indexing architectural decisions",
			LastHeartbeat: time.Now(),
		},
	}
	for _, p := range presences {
		if err := store.SetAgentPresence(ctx, p); err != nil {
			return err
		}
	}

	leadScratchpad := PrivateScratchpad{
		AgentID:   "lead-agent",
		ChannelID: chanMesh.ID,
		InnerThoughts: []string{
			"Checked vector table schema; cosine distance metrics verified",
			"Must ensure zero API keys are emitted into public WebSocket channel",
			"Scribe compaction verified at 96% token reduction",
		},
		DraftPlan: "Finalize Cloud Run staging deploy and probe live health endpoint",
		ToolTraces: []string{
			"gcloud run services describe agents-of-chat --region us-central1 -> STATUS: Ready",
		},
		UpdatedAt: time.Now(),
	}
	if err := store.SavePrivateScratchpad(ctx, leadScratchpad); err != nil {
		return err
	}

	dreamReport := ConsolidationReport{
		ID:             "dream-report-01",
		ChannelID:      chanMesh.ID,
		PrunedMessages: 14,
		DistilledFacts: []string{
			"ADC auth is mandatory for Vertex AI Gemini 3.8 calls in davenport-boutique",
			"Vector indexing uses COSINE distance for sub-15ms fast-path recall",
			"Scribe compaction achieves -96% token reduction on threads",
		},
		InsightSummary: "Nightly dreaming consolidation cycle completed: 14 transient debug messages pruned, 3 core architectural principles distilled into persistent semantic memory.",
		CompletedAt:    time.Now().Add(-10 * time.Minute),
		CrystallizedBeliefs: []CrystallizedBelief{
			{
				Key:         "deployment_stack",
				Value:       "Cloud Run & Vertex AI Gemini 3.8 Flash in davenport-boutique",
				Category:    "Infrastructure",
				Confidence:  0.98,
				Keywords:    "deployment, stack, cloud run, vertex ai, gemini 3.8, infrastructure, davenport-boutique",
				Statement:   "The production deployment stack runs on Cloud Run with Vertex AI Gemini 3.8 Flash in project davenport-boutique.",
				GeneratedAt: time.Now().Add(-10 * time.Minute),
			},
			{
				Key:         "security_policies",
				Value:       "Application Default Credentials (ADC) with zero secrets in code",
				Category:    "Security",
				Confidence:  0.99,
				Keywords:    "security, policy, policies, adc, credentials, zero secrets, api keys, auth",
				Statement:   "Security policies strictly require Google Cloud Application Default Credentials (ADC) with zero hardcoded API keys or secrets.",
				GeneratedAt: time.Now().Add(-10 * time.Minute),
			},
			{
				Key:         "agreed_guidelines",
				Value:       "Dual-layer memory separating shared blackboard from private inner monologue",
				Category:    "Architecture",
				Confidence:  0.97,
				Keywords:    "guidelines, agreed, dual-layer, blackboard, scratchpad, inner monologue, isolation",
				Statement:   "Agreed guidelines mandate dual-layer memory with public blackboard posts segregated from private agent inner thoughts.",
				GeneratedAt: time.Now().Add(-10 * time.Minute),
			},
			{
				Key:         "db_vector_search",
				Value:       "BigQuery and In-Memory vector indexing with Cosine Distance",
				Category:    "Database",
				Confidence:  0.98,
				Keywords:    "Vector Index, Cosine, BigQuery, Fast-Path",
				Statement:   "Vector indexing uses COSINE distance for sub-15ms fast-path recall.",
				GeneratedAt: time.Now().Add(-10 * time.Minute),
			},
			{
				Key:         "arch_scribe_compaction",
				Value:       "Scribe compaction token reduction",
				Category:    "Architecture",
				Confidence:  0.96,
				Keywords:    "Scribe, Compaction, Token Reduction, Rollup",
				Statement:   "Scribe compaction achieves -96% token reduction on threads without semantic degradation.",
				GeneratedAt: time.Now().Add(-10 * time.Minute),
			},
		},
		DreamPromptUsed: "SYSTEM PROMPT:\nYou are an offline cognitive Dreaming and Memory Consolidation engine.\nYour task is to analyze episodic chat transcripts, prune ephemeral noise/greetings,\nand distill durable architectural facts and key decisions into long-term semantic memory.\nProvide your output in exactly this format:\nSUMMARY: <single concise paragraph summarizing architectural state>\nDISTILLED_FACT: <fact 1>\nDISTILLED_FACT: <fact 2>\nDISTILLED_FACT: <fact 3>\n\nUSER PROMPT:\nConsolidate the following conversation from channel #mesh-coordination (2026 Collaborative Multi-Agent Mesh):\nLead Coordinator: Swarm consensus reached: standardizing on Cloud Run, Terraform, and BigQuery with Gemini 3.8.\nResearcher Agent: Validated cosine distance vector indexing.\nScribe Agent: Thread state rollups completed with -96% token reduction.",
		IntentTrajectory: "Episodic chatter -> Tool trace isolation -> REM sleep dreaming -> Crystalline semantic extraction -> Fast-path vector index",
	}
	if err := store.SaveConsolidationReport(ctx, dreamReport); err != nil {
		return err
	}

	return nil
}
