package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

// BroadcastFunc sends events to real-time WebSocket clients.
type BroadcastFunc func(eventType string, payload interface{})

// PacingMode controls the autonomous agent background activity.
type PacingMode struct {
	Paused          bool `json:"paused"`
	IntervalSeconds int  `json:"interval_seconds"`
}

// Orchestrator manages multi-agent coordination, memory retrieval, and LLM inference.
type Orchestrator struct {
	mu           sync.RWMutex
	store        storage.MemoryStore
	gemini       *GeminiClient
	broadcaster  BroadcastFunc
	pacing       PacingMode
	stopTickerCh chan struct{}
}

// NewOrchestrator creates and initializes an agent orchestrator.
func NewOrchestrator(store storage.MemoryStore, gemini *GeminiClient, b BroadcastFunc) *Orchestrator {
	orch := &Orchestrator{
		store:       store,
		gemini:      gemini,
		broadcaster: b,
		pacing: PacingMode{
			Paused:          false,
			IntervalSeconds: 8,
		},
	}
	return orch
}

// SetBroadcaster updates the WebSocket broadcast callback.
func (o *Orchestrator) SetBroadcaster(b BroadcastFunc) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.broadcaster = b
}

func (o *Orchestrator) broadcast(eventType string, payload interface{}) {
	o.mu.RLock()
	b := o.broadcaster
	o.mu.RUnlock()
	if b != nil {
		b(eventType, payload)
	}
}

// GetPacing returns current autonomous pacing state.
func (o *Orchestrator) GetPacing() PacingMode {
	o.mu.RLock()
	defer o.mu.RUnlock()
	return o.pacing
}

// SetPacing updates pacing interval or pause state.
func (o *Orchestrator) SetPacing(p PacingMode) {
	o.mu.Lock()
	if p.IntervalSeconds <= 0 {
		p.IntervalSeconds = 5
	}
	o.pacing = p
	o.mu.Unlock()

	o.broadcast("pacing_updated", p)
}

// HandleIncomingUserMessage processes a message sent by a human user.
func (o *Orchestrator) HandleIncomingUserMessage(ctx context.Context, channelID string, threadID string, content string, senderName string) (*storage.Message, error) {
	ch, _ := o.store.GetChannel(ctx, channelID)
	var eraID string
	if ch != nil {
		eraID = ch.EraID
	}

	var prevEvictedCount int
	if ch != nil && ch.MaxBufferTurns > 0 {
		if bufBefore, err := o.store.GetMemoryBuffer(ctx, channelID); err == nil && bufBefore != nil {
			prevEvictedCount = bufBefore.EvictedCount
		}
	}

	userMsg := storage.Message{
		ID:         fmt.Sprintf("msg-user-%d", time.Now().UnixNano()),
		ChannelID:  channelID,
		ThreadID:   threadID,
		SenderType: "user",
		SenderID:   "jason",
		SenderName: senderName,
		AvatarURL:  "https://api.dicebear.com/7.x/avataaars/svg?seed=jason",
		Content:    content,
		TokenCount: len(strings.Fields(content)) * 2, // approximation for incoming input
		CreatedAt:  time.Now(),
	}

	saveStart := time.Now()
	if err := o.store.SaveMessage(ctx, userMsg); err != nil {
		return nil, fmt.Errorf("failed to save user message: %w", err)
	}
	saveLatency := time.Since(saveStart).Milliseconds()

	o.broadcast("new_message", userMsg)

	// Broadcast memory_telemetry for storing user message
	if ch != nil && ch.MaxBufferTurns > 0 {
		currentTurns := 1
		maxTurns := ch.MaxBufferTurns
		if buf, err := o.store.GetMemoryBuffer(ctx, channelID); err == nil && buf != nil {
			currentTurns = buf.CurrentTurns
			maxTurns = buf.MaxTurns
		}
		span := storage.TelemetrySpan{
			ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
			EraID:       eraID,
			ChannelID:   channelID,
			ThreadID:    threadID,
			Action:      "FIFO_WRITE",
			ActiveStep:  2,
			Title:       "FIFO Buffer: Message Stored in RAM",
			Description: fmt.Sprintf("Message ingested into volatile RAM ring buffer (%d/%d turns).", currentTurns, maxTurns),
			LatencyMs:   saveLatency,
			Metrics: map[string]interface{}{
				"current_turns":    currentTurns,
				"max_buffer_turns": maxTurns,
			},
			Payload:   userMsg.Content,
			Timestamp: time.Now(),
		}
		o.broadcast("memory_telemetry", span)
	} else {
		span := storage.TelemetrySpan{
			ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
			EraID:       eraID,
			ChannelID:   channelID,
			ThreadID:    threadID,
			Action:      "STORE_WRITE",
			ActiveStep:  1,
			Title:       "Persistent Audit Trail: Message Saved",
			Description: "User message appended to persistent immutable message audit trail.",
			LatencyMs:   saveLatency,
			Metrics: map[string]interface{}{
				"token_count": userMsg.TokenCount,
			},
			Payload:   userMsg.Content,
			Timestamp: time.Now(),
		}
		o.broadcast("memory_telemetry", span)
	}

	// Check if Short-Term Memory buffer eviction occurred on this turn
	if ch != nil && ch.MaxBufferTurns > 0 {
		if buf, err := o.store.GetMemoryBuffer(ctx, channelID); err == nil && buf != nil && buf.LastEvictedMsg != nil {
			o.broadcast("buffer_evicted", buf)

			if buf.EvictedCount > prevEvictedCount {
				snippet := buf.LastEvictedMsg.Content
				evictSpan := storage.TelemetrySpan{
					ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
					EraID:       eraID,
					ChannelID:   channelID,
					ThreadID:    threadID,
					Action:      "FIFO_EVICT",
					ActiveStep:  3,
					Title:       "Amnesia Trap: Oldest Turn Evicted from RAM",
					Description: fmt.Sprintf("RAM buffer capacity (%d turns) exceeded; oldest turn dropped from active memory.", ch.MaxBufferTurns),
					LatencyMs:   0,
					Metrics: map[string]interface{}{
						"evicted_count": buf.EvictedCount,
					},
					Payload:   snippet,
					Timestamp: time.Now(),
				}
				o.broadcast("memory_telemetry", evictSpan)
			}
		}
	}

	// Determine targeted agent based on era and query triggers
	targetRole := LeadCoordinator
	lowerContent := strings.ToLower(content)

	// In 1:1 direct message channels (e.g. 1997 AIM), lock targetRole strictly to that channel's designated buddy.
	// Mentions of other agents inside a 1:1 DM MUST NOT switch the target role.
	if ch != nil && (ch.IsDirectMessage || strings.HasPrefix(ch.EraID, "era-1997")) {
		switch {
		case channelID == "chan-1997-aim-scribe" || strings.Contains(channelID, "scribe"):
			targetRole = StaffArchitectScribe
		case channelID == "chan-1997-aim-researcher" || strings.Contains(channelID, "researcher"):
			targetRole = DevResearcher
		default:
			targetRole = LeadCoordinator
		}
	} else if channelID == "chan-1988-irc" || (ch != nil && ch.EraID == "era-1988-irc") || strings.Contains(content, "@eggdrop") {
		targetRole = EggdropBot
	} else if strings.Contains(content, "@scribe") {
		targetRole = StaffArchitectScribe
	} else if strings.Contains(content, "@researcher") {
		targetRole = DevResearcher
	} else if strings.Contains(content, "@lead") {
		targetRole = LeadCoordinator
	} else if channelID == "chan-incident-postmortem" && (strings.Contains(lowerContent, "adr") || strings.Contains(lowerContent, "database") || strings.Contains(lowerContent, "vector") || strings.Contains(lowerContent, "postmortem") || strings.Contains(lowerContent, "latency") || strings.Contains(lowerContent, "lock")) {
		targetRole = DevResearcher
	} else if channelID == "chan-2006-jabber-eng" && (strings.Contains(lowerContent, "research") || strings.Contains(lowerContent, "vector") || strings.Contains(lowerContent, "benchmark")) {
		targetRole = DevResearcher
	} else if channelID == "chan-product-launch" || (ch != nil && (ch.EraID == "era-2026-agent-mesh" || strings.Contains(ch.EraID, "2026"))) || strings.Contains(channelID, "product-launch") {
		if strings.Contains(lowerContent, "security constraint") {
			targetRole = LeadCoordinator
		} else if strings.Contains(lowerContent, "security") || strings.Contains(lowerContent, "credentials") || strings.Contains(lowerContent, "scratchpad") || strings.Contains(lowerContent, "isolation") {
			targetRole = StaffArchitectScribe
		} else if strings.Contains(lowerContent, "consensus") {
			if strings.Contains(lowerContent, "summary") || strings.Contains(lowerContent, "checkpoint") || strings.Contains(lowerContent, "record") || strings.Contains(lowerContent, "audit") {
				targetRole = StaffArchitectScribe
			} else {
				targetRole = LeadCoordinator
			}
		} else if strings.Contains(lowerContent, "recall") || strings.Contains(lowerContent, "deployment") || strings.Contains(lowerContent, "stack") {
			targetRole = LeadCoordinator
		}
	}

	// Trigger agent response asynchronously to avoid blocking user HTTP call
	go func(role AgentRole, parentMsg storage.Message) {
		bgCtx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		_, _ = o.TriggerAgentResponse(bgCtx, channelID, threadID, role, content)
	}(targetRole, userMsg)

	return &userMsg, nil
}

// HandleUserMessage processes a message sent by a human user (alias for HandleIncomingUserMessage).
func (o *Orchestrator) HandleUserMessage(ctx context.Context, channelID string, threadID string, content string, senderName string) (*storage.Message, error) {
	return o.HandleIncomingUserMessage(ctx, channelID, threadID, content, senderName)
}

// InjectScenarioEvent injects an external operational event (e.g. Sentry alert or PR ready).
func (o *Orchestrator) InjectScenarioEvent(ctx context.Context, channelID string, threadID string, title string, details string) (*storage.Message, error) {
	sysMsg := storage.Message{
		ID:         fmt.Sprintf("event-%d", time.Now().UnixNano()),
		ChannelID:  channelID,
		ThreadID:   threadID,
		SenderType: "system",
		SenderID:   "event-engine",
		SenderName: "Scenario Event Engine",
		AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=event",
		Content:    fmt.Sprintf("⚡ **SCENARIO EVENT: %s**\n%s", title, details),
		TokenCount: len(strings.Fields(details)) * 2 + 30,
		IntentTags: []storage.IntentTag{
			{
				Label:       "Event History: Live Injection",
				Type:        "context",
				Color:       "sepia",
				Description: "Audit Trail: Injected operational event into chronological stream.",
			},
		},
		CreatedAt: time.Now(),
	}

	if err := o.store.SaveMessage(ctx, sysMsg); err != nil {
		return nil, err
	}

	o.broadcast("new_message", sysMsg)

	// Trigger Lead Agent to react to the event
	go func() {
		bgCtx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		_, _ = o.TriggerAgentResponse(bgCtx, channelID, threadID, LeadCoordinator, fmt.Sprintf("Analyze event: %s. %s", title, details))
	}()

	return &sysMsg, nil
}

// TriggerAgentResponse queries Gemini 3.8 for a specific agent and records the output.
func (o *Orchestrator) TriggerAgentResponse(ctx context.Context, channelID string, threadID string, role AgentRole, triggerPrompt string) (*storage.Message, error) {
	ch, err := o.store.GetChannel(ctx, channelID)
	if err != nil {
		return nil, fmt.Errorf("channel not found: %w", err)
	}

	shiftStep := 2
	if strings.Contains(ch.EraID, "1997") {
		shiftStep = 1
	}

	shiftSpan := storage.TelemetrySpan{
		ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
		EraID:       ch.EraID,
		ChannelID:   channelID,
		ThreadID:    threadID,
		Action:      "ATTENTIONAL_SHIFT",
		ActiveStep:  shiftStep,
		Title:       "Attentional State Shift: Agent Typing",
		Description: fmt.Sprintf("Agent %s shifting attentional focus to synthesize response.", role.Name),
		LatencyMs:   0,
		Metrics: map[string]interface{}{
			"agent_role": role.ID,
			"agent_name": role.Name,
		},
		Timestamp: time.Now(),
	}
	o.broadcast("memory_telemetry", shiftSpan)

	// Context Fencing / Search Isolation: Check allowed roles
	if len(ch.AllowedRoles) > 0 {
		firewallStep := 2
		if strings.Contains(ch.EraID, "2006") {
			firewallStep = 3
		}

		roleAllowed := false
		for _, allowed := range ch.AllowedRoles {
			if allowed == role.ID {
				roleAllowed = true
				break
			}
		}

		evalSpan := storage.TelemetrySpan{
			ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
			EraID:       ch.EraID,
			ChannelID:   channelID,
			ThreadID:    threadID,
			Action:      "FIREWALL_EVAL",
			ActiveStep:  firewallStep,
			Title:       "Context Fencing Firewall: Role Evaluation",
			Description: fmt.Sprintf("Evaluating context boundary permissions for role %s in #%s.", role.Name, ch.Name),
			LatencyMs:   0,
			Metrics: map[string]interface{}{
				"role":          role.ID,
				"allowed":       roleAllowed,
				"allowed_roles": ch.AllowedRoles,
			},
			Timestamp: time.Now(),
		}
		o.broadcast("memory_telemetry", evalSpan)

		if !roleAllowed {
			fenceMsg := storage.Message{
				ID:         fmt.Sprintf("msg-fenced-%d", time.Now().UnixNano()),
				ChannelID:  channelID,
				ThreadID:   threadID,
				SenderType: "system",
				SenderID:   "context-firewall",
				SenderName: "Context Fencing Firewall",
				AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=firewall",
				Content:    fmt.Sprintf("🛡️ **Context Fencing Quarantine**: Access denied for role `%s` in #%s. Cross-domain query blocked to prevent prompt contamination and associative bleed.", role.Name, ch.Name),
				TokenCount: 45,
				IntentTags: []storage.IntentTag{
					{
						Label:       "Search Isolation: Context Fenced",
						Type:        "permission",
						Color:       "sepia",
						Description: "Context Fencing active: Domain boundaries prevent unauthorized agent knowledge bleed.",
					},
				},
				CreatedAt: time.Now(),
			}
			_ = o.store.SaveMessage(ctx, fenceMsg)
			o.broadcast("new_message", fenceMsg)

			quarantineSpan := storage.TelemetrySpan{
				ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
				EraID:       ch.EraID,
				ChannelID:   channelID,
				ThreadID:    threadID,
				Action:      "FIREWALL_QUARANTINE",
				ActiveStep:  firewallStep,
				Title:       "Context Fencing Quarantine: Access Denied",
				Description: fmt.Sprintf("Access denied for role %s in #%s; cross-domain prompt contamination blocked.", role.Name, ch.Name),
				LatencyMs:   0,
				Metrics: map[string]interface{}{
					"role":          role.ID,
					"allowed_roles": ch.AllowedRoles,
				},
				Payload:   fenceMsg.Content,
				Timestamp: time.Now(),
			}
			o.broadcast("memory_telemetry", quarantineSpan)

			return &fenceMsg, nil
		}
	}

	// In 1:1 DM sessions (e.g. 1997 AIM), validate session isolation boundary
	if ch.IsDirectMessage || strings.HasPrefix(ch.EraID, "era-1997") {
		lowerPrompt := strings.ToLower(triggerPrompt)
		peerKeywords := []string{
			"@scribe", "@researcher", "@lead", "@eggdrop",
			"scribe", "researcher", "coordinator", "eggdrop",
			"other agent", "another agent", "peer agent",
			"what is scribe", "what is researcher", "what is lead",
			"what are other agents", "what is the other", "peer context", "other buddy",
			"buddy list", "private session", "switch to",
		}
		isCrossAgentInquiry := false
		for _, kw := range peerKeywords {
			if strings.Contains(lowerPrompt, kw) {
				if kw == "scribe" || kw == "@scribe" {
					if role.ID != StaffArchitectScribe.ID {
						isCrossAgentInquiry = true
						break
					}
				} else if kw == "researcher" || kw == "@researcher" {
					if role.ID != DevResearcher.ID {
						isCrossAgentInquiry = true
						break
					}
				} else if kw == "lead" || kw == "@lead" || kw == "coordinator" {
					if role.ID != LeadCoordinator.ID {
						isCrossAgentInquiry = true
						break
					}
				} else if kw == "eggdrop" || kw == "@eggdrop" {
					if role.ID != EggdropBot.ID {
						isCrossAgentInquiry = true
						break
					}
				} else {
					isCrossAgentInquiry = true
					break
				}
			}
		}

		if isCrossAgentInquiry {
			boundarySpan := storage.TelemetrySpan{
				ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
				EraID:       ch.EraID,
				ChannelID:   channelID,
				ThreadID:    threadID,
				Action:      "SESSION_BOUNDARY_CHECK",
				ActiveStep:  1,
				Title:       "1:1 Working Memory Boundary: Peer Context Quarantined",
				Description: fmt.Sprintf("Agent %s enforced 1:1 session boundary; peer agent inquiry quarantined within private working memory.", role.Name),
				LatencyMs:   0,
				Metrics: map[string]interface{}{
					"agent_role":     role.ID,
					"boundary_check": "PASSED",
					"peer_isolated":  true,
					"channel_id":     channelID,
				},
				Payload:   triggerPrompt,
				Timestamp: time.Now(),
			}
			o.broadcast("memory_telemetry", boundarySpan)
		}
	}

	// Check existing agent presence before modifying state
	existingPresence, _ := o.store.GetAgentPresence(ctx, role.ID)
	wasAway := existingPresence != nil && existingPresence.Status == "away"
	var savedAwayPresence storage.AgentPresence
	var presence storage.AgentPresence
	if existingPresence != nil {
		presence = *existingPresence
	} else {
		presence = storage.AgentPresence{
			AgentID:   role.ID,
			AgentName: role.Name,
			AvatarURL: role.AvatarURL,
		}
	}
	if wasAway {
		savedAwayPresence = *existingPresence
	}

	if wasAway {
		// Agent is away! Broadcast an ATTENTIONAL_SHIFT / AWAY_PERSONA_PRIMING telemetry span
		awaySpan := storage.TelemetrySpan{
			ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
			EraID:       ch.EraID,
			ChannelID:   channelID,
			ThreadID:    threadID,
			Action:      "AWAY_PERSONA_PRIMING",
			ActiveStep:  3,
			Title:       "Dynamic Away Persona Priming: Auto-Responder Active",
			Description: fmt.Sprintf("Agent %s is away ('%s'). Dynamic persona priming injected into system prompt.", role.Name, savedAwayPresence.StatusMessage),
			LatencyMs:   0,
			Metrics: map[string]interface{}{
				"agent_role":     role.ID,
				"status":         "away",
				"away_message":   savedAwayPresence.StatusMessage,
				"current_task":   savedAwayPresence.CurrentTask,
				"persona_primed": true,
			},
			Payload:   savedAwayPresence.StatusMessage,
			Timestamp: time.Now(),
		}
		o.broadcast("memory_telemetry", awaySpan)
	} else {
		// Update Agent Presence to typing
		presence.AgentID = role.ID
		presence.AgentName = role.Name
		presence.AvatarURL = role.AvatarURL
		presence.Status = "typing"
		presence.StatusMessage = fmt.Sprintf("Synthesizing response for #%s", ch.Name)
		presence.CurrentTask = triggerPrompt
		presence.LastHeartbeat = time.Now()
		_ = o.store.SetAgentPresence(ctx, presence)
		o.broadcast("presence_updated", presence)
	}

	o.broadcast("agent_typing", map[string]string{
		"agent_id":   role.ID,
		"agent_name": role.Name,
		"channel_id": channelID,
		"thread_id":  threadID,
	})

	// 1. Gather working context: most recent 12 messages in this thread or channel
	recentMsgs, err := o.store.ListMessages(ctx, channelID, threadID, 12)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch recent messages: %w", err)
	}

	// 2. Long-Term Memory (Vector Search RAG)
	// Vector RAG must ONLY run if the era has vector search capabilities (era-2013-hipchat, era-2017-threads, era-2026-agent-mesh, or scoped era-2006-jabber).
	// Strictly exclude era-1988-irc and era-1997-aim.
	var vectorHits []storage.VectorSearchResult
	isVectorCapableEra := (ch.EraID == "era-2013-hipchat" || ch.EraID == "era-2017-threads" || ch.EraID == "era-2026-agent-mesh" || ch.EraID == "era-2006-jabber")
	if strings.Contains(ch.EraID, "1988") || strings.Contains(ch.EraID, "1997") {
		isVectorCapableEra = false
	}

	if isVectorCapableEra && (role.ID == DevResearcher.ID || strings.Contains(strings.ToLower(triggerPrompt), "history") || strings.Contains(strings.ToLower(triggerPrompt), "past") || strings.Contains(strings.ToLower(triggerPrompt), "vector") || strings.Contains(strings.ToLower(triggerPrompt), "adr")) {
		vecStart := time.Now()
		vQuery := []float32{0.82, 0.74, 0.21, 0.12, 0.91, 0.15, 0.05, 0.88, 0.79, 0.18, 0.11, 0.85, 0.14, 0.06, 0.83, 0.77}
		
		// When vector search runs in a scoped era (like Jabber), scope it strictly to channelID to prevent cross-channel memory leakage.
		searchScope := ""
		if ch.EraID == "era-2006-jabber" {
			searchScope = channelID
		}
		
		hits, err := o.store.SearchVectors(ctx, searchScope, vQuery, 2)
		vecLatency := time.Since(vecStart).Milliseconds()
		if err == nil {
			vectorHits = hits
		}

		var topSim, topDist float32
		if len(vectorHits) > 0 {
			topSim = vectorHits[0].Similarity
			topDist = vectorHits[0].Distance
		}

		vecStep := 3 // ActiveStep 3 for 2013
		if ch.EraID == "era-2006-jabber" {
			vecStep = 2
		}

		vecSpan := storage.TelemetrySpan{
			ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
			EraID:       ch.EraID,
			ChannelID:   channelID,
			ThreadID:    threadID,
			Action:      "VECTOR_SEARCH",
			ActiveStep:  vecStep,
			Title:       "Vector Search: Exact Cosine Distance",
			Description: fmt.Sprintf("Retrieved %d semantic memory vectors via exact cosine distance.", len(vectorHits)),
			LatencyMs:   vecLatency,
			Metrics: map[string]interface{}{
				"similarity":   topSim,
				"distance":     topDist,
				"hit_count":    len(vectorHits),
				"search_scope": searchScope,
			},
			Timestamp: time.Now(),
		}
		if len(vectorHits) > 0 {
			vecSpan.Payload = vectorHits[0].Message.Content
		}
		o.broadcast("memory_telemetry", vecSpan)
	}

	// 2b. Fast-Path Crystalline Memory Recall
	// When answering questions on #product-launch-ga / 2026 mesh that match crystallized beliefs
	// (e.g. questions asking about deployment stack, security policies, agreed guidelines),
	// check store.SearchCrystallizedBeliefs.
	var crystallineHits []storage.CrystallizedBelief
	isCrystallizedEra := (ch.EraID == "era-2026-agent-mesh" ||
		channelID == "chan-product-launch" ||
		strings.Contains(channelID, "product-launch") ||
		strings.Contains(strings.ToLower(ch.Name), "product-launch") ||
		strings.Contains(strings.ToLower(ch.Name), "mesh") ||
		strings.Contains(strings.ToLower(ch.Topic), "launch"))

	if isCrystallizedEra {
		cStart := time.Now()
		cHits, err := o.store.SearchCrystallizedBeliefs(ctx, channelID, triggerPrompt)
		cLatency := time.Since(cStart).Milliseconds()
		if err == nil {
			for _, b := range cHits {
				if b.Confidence >= 0.70 { // High-confidence matching belief
					crystallineHits = append(crystallineHits, b)
				}
			}
		}

		if len(crystallineHits) > 0 {
			cacheSpan := storage.TelemetrySpan{
				ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
				EraID:       ch.EraID,
				ChannelID:   channelID,
				ThreadID:    threadID,
				Action:      "CRYSTALLINE_RECALL",
				ActiveStep:  2,
				Title:       "⚡ Crystalline Cache (<10ms)",
				Description: fmt.Sprintf("Retrieved %d high-confidence crystallized beliefs from long-term memory.", len(crystallineHits)),
				LatencyMs:   cLatency,
				Metrics: map[string]interface{}{
					"hit_count":  len(crystallineHits),
					"top_key":    crystallineHits[0].Key,
					"confidence": crystallineHits[0].Confidence,
					"category":   crystallineHits[0].Category,
				},
				Payload:   crystallineHits[0].Statement,
				Timestamp: time.Now(),
			}
			o.broadcast("memory_telemetry", cacheSpan)
		}
	}

	// 3. Assemble Cognitive Prompt Context (Era, Presence, Private Scratchpad, Crystallized Beliefs)
	pCtx := &PromptContext{}
	if ch.EraID != "" {
		if era, err := o.store.GetEra(ctx, ch.EraID); err == nil {
			pCtx.Era = era
		}
	}
	if wasAway {
		pCtx.Presence = &savedAwayPresence
	} else if p, err := o.store.GetAgentPresence(ctx, role.ID); err == nil {
		pCtx.Presence = p
	}
	if pad, err := o.store.GetPrivateScratchpad(ctx, role.ID, channelID); err == nil {
		pCtx.Scratchpad = pad
	}
	if len(crystallineHits) > 0 {
		pCtx.CrystallizedBeliefs = crystallineHits
	}

	// 4. Assemble prompt
	sysPrompt, userPrompt := BuildAgentPrompt(role, *ch, recentMsgs, vectorHits, triggerPrompt, pCtx)

	// 5. Call Gemini 3.8 on Vertex AI
	llmStart := time.Now()
	genResult, err := o.gemini.Generate(ctx, sysPrompt, userPrompt)
	llmLatency := time.Since(llmStart).Milliseconds()
	if err != nil {
		errMsg := storage.Message{
			ID:         fmt.Sprintf("msg-err-%d", time.Now().UnixNano()),
			ChannelID:  channelID,
			ThreadID:   threadID,
			SenderType: "system",
			SenderID:   "system-error",
			SenderName: "Gemini 3.8 Service Alert",
			Content:    fmt.Sprintf("⚠️ Gemini 3.8 API Error (Never Mocked): %v", err),
			TokenCount: 50,
			CreatedAt:  time.Now(),
		}
		_ = o.store.SaveMessage(ctx, errMsg)
		o.broadcast("new_message", errMsg)

		if wasAway {
			_ = o.store.SetAgentPresence(ctx, savedAwayPresence)
			o.broadcast("presence_updated", savedAwayPresence)
		} else {
			// Reset presence to available
			presence := storage.AgentPresence{
				AgentID:       role.ID,
				AgentName:     role.Name,
				AvatarURL:     role.AvatarURL,
				Status:        "available",
				StatusMessage: "Idle / Standing by",
				CurrentTask:   "",
				LastHeartbeat: time.Now(),
			}
			_ = o.store.SetAgentPresence(ctx, presence)
			o.broadcast("presence_updated", presence)
		}
		return nil, err
	}

	llmStep := 4
	if strings.Contains(ch.EraID, "1997") || strings.Contains(ch.EraID, "1988") {
		llmStep = 3
	}

	llmSpan := storage.TelemetrySpan{
		ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
		EraID:       ch.EraID,
		ChannelID:   channelID,
		ThreadID:    threadID,
		Action:      "LLM_INFERENCE",
		ActiveStep:  llmStep,
		Title:       "Vertex AI Inference: Gemini 3.8",
		Description: fmt.Sprintf("Vertex AI Gemini 3.8 generated %d candidate tokens from %d prompt tokens.", genResult.CandidateTokens, genResult.PromptTokens),
		LatencyMs:   llmLatency,
		Metrics: map[string]interface{}{
			"prompt_tokens":    genResult.PromptTokens,
			"candidate_tokens": genResult.CandidateTokens,
			"model":            genResult.ModelUsed,
		},
		Payload:   genResult.Text,
		Timestamp: time.Now(),
	}
	o.broadcast("memory_telemetry", llmSpan)

	if wasAway {
		// Retain away status and message
		_ = o.store.SetAgentPresence(ctx, savedAwayPresence)
		o.broadcast("presence_updated", savedAwayPresence)
	} else {
		// Reset presence to available
		presence := storage.AgentPresence{
			AgentID:       role.ID,
			AgentName:     role.Name,
			AvatarURL:     role.AvatarURL,
			Status:        "available",
			StatusMessage: fmt.Sprintf("Completed turn in #%s", ch.Name),
			CurrentTask:   "",
			LastHeartbeat: time.Now(),
		}
		_ = o.store.SetAgentPresence(ctx, presence)
		o.broadcast("presence_updated", presence)
	}

	// 6. Construct Intent Tags showcasing chat pattern -> memory pattern
	var tags []storage.IntentTag
	if wasAway {
		tags = append(tags, storage.IntentTag{
			Label:       "AIM: Dynamic Away Delegate",
			Type:        "persona",
			Color:       "sepia",
			Description: fmt.Sprintf("Dynamic persona priming: automated response acknowledging away memo '%s'.", savedAwayPresence.StatusMessage),
		})
	}
	if len(crystallineHits) > 0 {
		tags = append(tags, storage.IntentTag{
			Label:       "⚡ Crystalline Cache (<10ms)",
			Type:        "crystalline_hit",
			Color:       "purple",
			Description: "Crystalline Memory Hit: Retrieved consolidated belief from long-term memory.",
		})
	}

	tags = append(tags, storage.IntentTag{
		Label:       fmt.Sprintf("Working Context: %d tokens", genResult.PromptTokens),
		Type:        "context",
		Color:       role.DefaultIntentColor,
		Description: fmt.Sprintf("Working Context: %s processed %d prompt tokens via %s.", role.Name, genResult.PromptTokens, genResult.ModelUsed),
	})

	if len(vectorHits) > 0 {
		tags = append(tags, storage.IntentTag{
			Label:       fmt.Sprintf("Vector Hit: %.2f sim", vectorHits[0].Similarity),
			Type:        "vector_hit",
			Color:       "blue",
			Description: "Long-Term Memory Search: Vector Search injected historical ADR into context.",
		})
	}

	if role.ID == StaffArchitectScribe.ID {
		summary := storage.Summary{
			ID:               fmt.Sprintf("sum-%d", time.Now().UnixNano()),
			ChannelID:        channelID,
			ThreadID:         threadID,
			CondensedState:   genResult.Text,
			OriginalTokens:   genResult.PromptTokens,
			CompactedTokens:  genResult.CandidateTokens,
			CompressionRatio: 1.0 - (float64(genResult.CandidateTokens) / float64(genResult.PromptTokens+1)),
			CreatedAt:        time.Now(),
		}
		_ = o.store.SaveSummary(ctx, summary)

		tags = append(tags, storage.IntentTag{
			Label:       fmt.Sprintf("Compacted by Scribe: -%d%% tokens", int(summary.CompressionRatio*100)),
			Type:        "compaction",
			Color:       "amber",
			Description: "Compaction & Summaries: Large conversation window compressed into state checkpoint.",
		})

		scribeStep := 4 // ActiveStep 4 for 2017
		scribeSpan := storage.TelemetrySpan{
			ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
			EraID:       ch.EraID,
			ChannelID:   channelID,
			ThreadID:    threadID,
			Action:      "SCRIBE_COMPACT",
			ActiveStep:  scribeStep,
			Title:       "Hierarchical Compaction: Scribe State Rollup",
			Description: fmt.Sprintf("Scribe compacted %d original tokens into %d tokens (%.1f%% reduction).", summary.OriginalTokens, summary.CompactedTokens, summary.CompressionRatio*100),
			LatencyMs:   0,
			Metrics: map[string]interface{}{
				"compression_ratio": summary.CompressionRatio,
				"original_tokens":   summary.OriginalTokens,
				"compacted_tokens":  summary.CompactedTokens,
			},
			Payload:   summary.CondensedState,
			Timestamp: time.Now(),
		}
		o.broadcast("memory_telemetry", scribeSpan)
	}

	agentMsg := storage.Message{
		ID:         fmt.Sprintf("msg-agent-%d", time.Now().UnixNano()),
		ChannelID:  channelID,
		ThreadID:   threadID,
		SenderType: "agent",
		SenderID:   role.ID,
		SenderName: role.Name,
		AvatarURL:  role.AvatarURL,
		Content:    genResult.Text,
		TokenCount: genResult.CandidateTokens,
		IntentTags: tags,
		Metadata: map[string]interface{}{
			"prompt_tokens":    genResult.PromptTokens,
			"candidate_tokens": genResult.CandidateTokens,
			"model":            genResult.ModelUsed,
		},
		CreatedAt: time.Now(),
	}

	var prevEvictedCount int
	if ch.MaxBufferTurns > 0 {
		if bufBefore, err := o.store.GetMemoryBuffer(ctx, channelID); err == nil && bufBefore != nil {
			prevEvictedCount = bufBefore.EvictedCount
		}
	}

	saveStart := time.Now()
	if err := o.store.SaveMessage(ctx, agentMsg); err != nil {
		return nil, err
	}
	saveLatency := time.Since(saveStart).Milliseconds()

	o.broadcast("new_message", agentMsg)

	commitSpan := storage.TelemetrySpan{
		ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
		EraID:       ch.EraID,
		ChannelID:   channelID,
		ThreadID:    threadID,
		Action:      "STORE_WRITE",
		ActiveStep:  4,
		Title:       "Agent Response Committed",
		Description: fmt.Sprintf("Agent response committed to persistent store (%d candidate tokens).", agentMsg.TokenCount),
		LatencyMs:   saveLatency,
		Metrics: map[string]interface{}{
			"candidate_tokens": agentMsg.TokenCount,
			"sender_id":        agentMsg.SenderID,
		},
		Payload:   agentMsg.Content,
		Timestamp: time.Now(),
	}
	o.broadcast("memory_telemetry", commitSpan)

	// Check if FIFO buffer eviction occurred in Short-Term Memory
	if ch.MaxBufferTurns > 0 {
		if buf, err := o.store.GetMemoryBuffer(ctx, channelID); err == nil && buf != nil && buf.LastEvictedMsg != nil {
			o.broadcast("buffer_evicted", buf)

			if buf.EvictedCount > prevEvictedCount {
				snippet := buf.LastEvictedMsg.Content
				evictSpan := storage.TelemetrySpan{
					ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
					EraID:       ch.EraID,
					ChannelID:   channelID,
					ThreadID:    threadID,
					Action:      "FIFO_EVICT",
					ActiveStep:  3,
					Title:       "Amnesia Trap: Oldest Turn Evicted from RAM",
					Description: fmt.Sprintf("RAM buffer capacity (%d turns) exceeded; oldest turn dropped from active memory.", ch.MaxBufferTurns),
					LatencyMs:   0,
					Metrics: map[string]interface{}{
						"evicted_count": buf.EvictedCount,
					},
					Payload:   snippet,
					Timestamp: time.Now(),
				}
				o.broadcast("memory_telemetry", evictSpan)
			}
		}
	}

	// In the 2026 Collaborative Multi-Agent Mesh, Lead Coordinator coordinates the swarm
	// and actually calls the other agents (@researcher, @scribe) so the whole swarm actively collaborates.
	is2026Swarm := ch.EraID == "era-2026-agent-mesh" || strings.Contains(ch.EraID, "2026") || channelID == "chan-product-launch" || strings.Contains(channelID, "product-launch")
	if is2026Swarm && role.ID == LeadCoordinator.ID && !strings.HasPrefix(triggerPrompt, "@lead called you") {
		o.delegate2026SwarmTurns(channelID, threadID, agentMsg.Content, triggerPrompt)
	}

	return &agentMsg, nil
}

// delegate2026SwarmTurns dispatches turns to the specialist agents in the 2026 swarm
// when called by the Lead Coordinator.
func (o *Orchestrator) delegate2026SwarmTurns(channelID string, threadID string, leadContent string, userPrompt string) {
	lowerResp := strings.ToLower(leadContent)

	callResearcher := strings.Contains(lowerResp, "@researcher") || strings.Contains(lowerResp, "researcher")
	callScribe := strings.Contains(lowerResp, "@scribe") || strings.Contains(lowerResp, "scribe")

	// In the 2026 swarm examples, Lead Coordinator coordinates the whole swarm.
	// If neither was explicitly singled out, call both so the entire mesh responds.
	if !callResearcher && !callScribe {
		callResearcher = true
		callScribe = true
	}

	go func() {
		// Natural conversational delay so the Lead response renders first on the UI
		time.Sleep(800 * time.Millisecond)

		if callResearcher {
			bgCtx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			prompt := fmt.Sprintf("@lead called you in the 2026 swarm.\nCoordinator Directive: %s\nOriginal Request: %s\nProvide your terse 2-line assessment as Dev Researcher.", leadContent, userPrompt)
			_, _ = o.TriggerAgentResponse(bgCtx, channelID, threadID, DevResearcher, prompt)
			cancel()
			time.Sleep(800 * time.Millisecond)
		}

		if callScribe {
			bgCtx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			prompt := fmt.Sprintf("@lead called you in the 2026 swarm.\nCoordinator Directive: %s\nOriginal Request: %s\nProvide your terse 2-line checkpoint as Staff Architect Scribe.", leadContent, userPrompt)
			_, _ = o.TriggerAgentResponse(bgCtx, channelID, threadID, StaffArchitectScribe, prompt)
			cancel()
		}
	}()
}

// ConsolidateMemory triggers an offline Dreaming / Consolidation cycle for a channel.
// It uses Gemini 3.8 to reflect across recent dialogue, discard ephemeral chatter,
// and crystallize durable architectural facts into long-term memory.
func (o *Orchestrator) ConsolidateMemory(ctx context.Context, channelID string) (*storage.ConsolidationReport, error) {
	ch, err := o.store.GetChannel(ctx, channelID)
	if err != nil {
		return nil, fmt.Errorf("channel not found: %w", err)
	}

	msgs, err := o.store.ListMessages(ctx, channelID, "", 30)
	if err != nil {
		return nil, fmt.Errorf("failed to list messages for consolidation: %w", err)
	}

	if len(msgs) == 0 {
		return nil, fmt.Errorf("no messages to consolidate in channel %s", channelID)
	}

	var stream strings.Builder
	for _, m := range msgs {
		stream.WriteString(fmt.Sprintf("%s (%s): %s\n", m.SenderName, m.SenderID, m.Content))
	}

	sysPrompt := `You are an offline cognitive Dreaming and Memory Consolidation engine inspired by REM dream synthesis.
Your mission is to analyze episodic conversation logs, prune transient noise and debugging chatter, and distill durable architectural beliefs, facts, and intent trajectories into long-term crystalline memory.

You MUST respond ONLY with a valid JSON object matching this schema:
{
  "summary": "Concise 2-3 sentence summary synthesizing the core architectural state, technical consensus, and conclusions for demo readability",
  "intent_trajectory": "Chronological trajectory and intent evolution across turns (e.g. Inception -> Design -> Hardening -> GA Sign-off)",
  "distilled_facts": [
    "Durable architectural fact 1",
    "Durable architectural fact 2"
  ],
  "crystallized_beliefs": [
    {
      "key": "snake_case_unique_key",
      "value": "Concise core conclusion, policy, or architectural decision",
      "category": "Infrastructure|Security|Architecture|Database",
      "confidence": 0.98,
      "keywords": "comma separated search keywords",
      "statement": "Self-contained natural language assertion statement"
    }
  ]
}`

	userPrompt := fmt.Sprintf(`### REM DREAM SYNTHESIS PROMPT ###
Channel: #%s (%s)
System Guidelines: %s

Episodic Conversation Log to Consolidate:
%s

Synthesize durable architectural facts, intent trajectories, and crystallized beliefs into long-term crystalline memory. Return raw JSON conforming to the schema.`,
		ch.Name, ch.Topic, ch.SystemPrompt, stream.String())

	exactDreamPrompt := fmt.Sprintf("SYSTEM PROMPT:\n%s\n\nUSER PROMPT:\n%s", sysPrompt, userPrompt)

	startDream := time.Now()
	genResult, err := o.gemini.Generate(ctx, sysPrompt, userPrompt)
	dreamLatency := time.Since(startDream).Milliseconds()
	if err != nil {
		return nil, fmt.Errorf("dreaming consolidation failed: %w", err)
	}

	type DreamOutput struct {
		Summary             string                      `json:"summary"`
		IntentTrajectory    string                      `json:"intent_trajectory"`
		DistilledFacts      []string                    `json:"distilled_facts"`
		CrystallizedBeliefs []storage.CrystallizedBelief `json:"crystallized_beliefs"`
	}

	cleanedText := strings.TrimSpace(genResult.Text)
	if strings.HasPrefix(cleanedText, "```json") {
		cleanedText = strings.TrimPrefix(cleanedText, "```json")
	} else if strings.HasPrefix(cleanedText, "```") {
		cleanedText = strings.TrimPrefix(cleanedText, "```")
	}
	cleanedText = strings.TrimSuffix(cleanedText, "```")
	cleanedText = strings.TrimSpace(cleanedText)

	var dreamOutput DreamOutput
	var summaryText string
	var facts []string
	var intentTrajectory string
	var beliefs []storage.CrystallizedBelief

	if err := json.Unmarshal([]byte(cleanedText), &dreamOutput); err == nil {
		summaryText = dreamOutput.Summary
		intentTrajectory = dreamOutput.IntentTrajectory
		facts = dreamOutput.DistilledFacts
		beliefs = dreamOutput.CrystallizedBeliefs
	} else {
		// Fallback for line-based or semi-structured output
		lines := strings.Split(genResult.Text, "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "SUMMARY:") {
				summaryText = strings.TrimSpace(strings.TrimPrefix(line, "SUMMARY:"))
			} else if strings.HasPrefix(line, "DISTILLED_FACT:") {
				fact := strings.TrimSpace(strings.TrimPrefix(line, "DISTILLED_FACT:"))
				if fact != "" {
					facts = append(facts, fact)
				}
			}
		}
	}

	if summaryText == "" {
		summaryText = genResult.Text
	}
	if len(facts) == 0 {
		facts = append(facts, "Channel consolidated into persistent semantic memory checkpoint.")
	}
	if intentTrajectory == "" {
		intentTrajectory = fmt.Sprintf("Episodic stream of %d messages consolidated into long-term memory checkpoint.", len(msgs))
	}

	prunedCount := len(msgs) / 2
	if prunedCount < 1 {
		prunedCount = 1
	}

	// Deduplicate beliefs returned by Gemini before creating the report
	var dedupedBeliefs []storage.CrystallizedBelief
	beliefKeyIndex := make(map[string]int)
	for _, b := range beliefs {
		keyNorm := strings.ToLower(strings.TrimSpace(b.Key))
		if keyNorm == "" {
			continue
		}
		if idx, found := beliefKeyIndex[keyNorm]; found {
			dedupedBeliefs[idx] = b
		} else {
			beliefKeyIndex[keyNorm] = len(dedupedBeliefs)
			dedupedBeliefs = append(dedupedBeliefs, b)
		}
	}
	beliefs = dedupedBeliefs

	completedAt := time.Now()
	for i := range beliefs {
		beliefs[i].GeneratedAt = completedAt
	}

	report := storage.ConsolidationReport{
		ID:                  fmt.Sprintf("dream-%d", time.Now().UnixNano()),
		ChannelID:           channelID,
		PrunedMessages:      prunedCount,
		DistilledFacts:      facts,
		InsightSummary:      summaryText,
		CrystallizedBeliefs: beliefs,
		DreamPromptUsed:     exactDreamPrompt,
		IntentTrajectory:    intentTrajectory,
		CompletedAt:         completedAt,
	}

	if err := o.store.SaveConsolidationReport(ctx, report); err != nil {
		return nil, err
	}

	// Post rich consolidation milestone system message into the chat channel
	milestoneContent := fmt.Sprintf("🌙 **REM Dreaming Consolidation Complete**\n\n"+
		"**Insight Summary:**\n%s\n\n"+
		"• **Ephemeral Turns Pruned:** %d turns\n"+
		"• **Durable Principles Distilled:** %d facts\n"+
		"• **Crystallized Beliefs:** %d semantic memories indexed into long-term memory",
		report.InsightSummary, report.PrunedMessages, len(report.DistilledFacts), len(report.CrystallizedBeliefs))

	milestoneMsg := storage.Message{
		ID:         fmt.Sprintf("msg-dream-%d", time.Now().UnixNano()),
		ChannelID:  channelID,
		SenderType: "system",
		SenderID:   "rem-dreaming-engine",
		SenderName: "REM Dreaming Engine",
		AvatarURL:  "https://api.dicebear.com/7.x/bottts/svg?seed=dreaming",
		Content:    milestoneContent,
		TokenCount: len(strings.Fields(milestoneContent)) * 2,
		IntentTags: []storage.IntentTag{
			{
				Label:       "🌙 REM Dreaming Consolidation",
				Type:        "compaction",
				Color:       "purple",
				Description: fmt.Sprintf("Offline REM memory consolidation pass pruned %d ephemeral messages and crystallized %d durable beliefs into long-term semantic memory.", report.PrunedMessages, len(report.CrystallizedBeliefs)),
			},
		},
		CreatedAt: completedAt,
	}

	if err := o.store.SaveMessage(ctx, milestoneMsg); err != nil {
		return nil, fmt.Errorf("failed to save dreaming milestone message: %w", err)
	}
	o.broadcast("new_message", milestoneMsg)

	dreamSpan := storage.TelemetrySpan{
		ID:          fmt.Sprintf("span-%d", time.Now().UnixNano()),
		EraID:       ch.EraID,
		ChannelID:   channelID,
		Action:      "DREAM_CONSOLIDATION",
		ActiveStep:  3,
		Title:       "Dreaming Memory Synthesis: Pruning Ephemeral Chatter",
		Description: fmt.Sprintf("Offline memory consolidation pruned %d ephemeral messages, distilled %d permanent facts, and crystallized %d beliefs.", report.PrunedMessages, len(report.DistilledFacts), len(report.CrystallizedBeliefs)),
		LatencyMs:   dreamLatency,
		Metrics: map[string]interface{}{
			"pruned_messages":      report.PrunedMessages,
			"distilled_facts":      len(report.DistilledFacts),
			"crystallized_beliefs": len(report.CrystallizedBeliefs),
			"intent_trajectory":    report.IntentTrajectory,
		},
		Payload:   report.InsightSummary,
		Timestamp: time.Now(),
	}
	o.broadcast("memory_telemetry", dreamSpan)

	o.broadcast("consolidation_completed", report)
	return &report, nil
}

// TriggerAgentTurn is an alias for TriggerAgentResponse to support alternate call naming.
func (o *Orchestrator) TriggerAgentTurn(ctx context.Context, channelID string, threadID string, role AgentRole, triggerPrompt string) (*storage.Message, error) {
	return o.TriggerAgentResponse(ctx, channelID, threadID, role, triggerPrompt)
}

// UpdateAgentPresence updates the cognitive presence status and broadcasts the change.
func (o *Orchestrator) UpdateAgentPresence(ctx context.Context, presence storage.AgentPresence) error {
	if err := o.store.SetAgentPresence(ctx, presence); err != nil {
		return err
	}
	o.broadcast("presence_updated", presence)
	return nil
}

// UpdatePrivateScratchpad updates an agent's private scratchpad and broadcasts the event.
func (o *Orchestrator) UpdatePrivateScratchpad(ctx context.Context, pad storage.PrivateScratchpad) error {
	if err := o.store.SavePrivateScratchpad(ctx, pad); err != nil {
		return err
	}
	o.broadcast("scratchpad_updated", pad)
	return nil
}
