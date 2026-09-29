package agent

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

// TestEra1_EphemeralBuffer_AmnesiaTrap validates the cognitive boundary of Era 1 (1988 IRC):
// Volatile RAM sliding context window strictly evicts turns beyond capacity (5 turns),
// inducing the Amnesia Trap where evicted secrets/instructions are permanently lost.
func TestEra1_EphemeralBuffer_AmnesiaTrap(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	defer store.Close()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	channelID := "chan-1988-irc"
	ch, err := store.GetChannel(ctx, channelID)
	if err != nil {
		t.Fatalf("channel %s not found: %v", channelID, err)
	}

	// 1. Initial turn: User sets a secret key
	secretMsg := storage.Message{
		ID:         "msg-turn-secret-1",
		ChannelID:  channelID,
		SenderID:   "jason",
		SenderName: "Jason Davenport",
		Content:    "!set-secret PROD_KEY_984210=SUPER_CONFIDENTIAL",
		CreatedAt:  time.Now(),
	}
	if err := store.SaveMessage(ctx, secretMsg); err != nil {
		t.Fatalf("failed to save secret turn: %v", err)
	}

	// 2. Send 6 subsequent turns to overflow capacity (MaxBufferTurns = 5)
	for i := 1; i <= 6; i++ {
		m := storage.Message{
			ID:         fmt.Sprintf("msg-flood-%d", i),
			ChannelID:  channelID,
			SenderID:   "jason",
			SenderName: "Jason Davenport",
			Content:    fmt.Sprintf("Operational ping command turn %d", i),
			CreatedAt:  time.Now(),
		}
		if err := store.SaveMessage(ctx, m); err != nil {
			t.Fatalf("failed to save flood turn %d: %v", i, err)
		}
	}

	// 3. Verify buffer state: Earliest turn must be physically evicted
	buf, err := store.GetMemoryBuffer(ctx, channelID)
	if err != nil {
		t.Fatalf("failed to get memory buffer: %v", err)
	}
	if buf.CurrentTurns > 5 {
		t.Fatalf("buffer exceeded MaxBufferTurns (5), got %d turns", buf.CurrentTurns)
	}
	if buf.EvictedCount < 1 {
		t.Fatalf("expected at least 1 turn evicted, got %d", buf.EvictedCount)
	}

	activeMsgs, err := store.ListMessages(ctx, channelID, "", 50)
	if err != nil {
		t.Fatalf("failed to list active messages: %v", err)
	}
	for _, turn := range activeMsgs {
		if strings.Contains(turn.Content, "SUPER_CONFIDENTIAL") {
			t.Fatalf("cognitive leak: evicted secret key found in active messages")
		}
	}

	// 4. Verify system prompt: Bot operates in volatile RAM and cannot recall evicted turns
	eggdrop, _ := GetRoleByID("eggdrop-bot")
	era, _ := store.GetEra(ctx, "era-1988-irc")
	pCtx := &PromptContext{
		Era: era,
	}
	sysPrompt, userPrompt := BuildAgentPrompt(eggdrop, *ch, activeMsgs, nil, "!bot query PROD_KEY_984210", pCtx)

	if !strings.Contains(sysPrompt, "Volatile RAM & FIFO Eviction Boundary") {
		t.Errorf("system prompt missing volatile RAM boundary directive: %s", sysPrompt)
	}
	if strings.Contains(userPrompt, "SUPER_CONFIDENTIAL") {
		t.Errorf("user prompt contains evicted secret: %s", userPrompt)
	}
}

// TestEra2_AIM_1on1SessionBoundary validates the cognitive boundary of Era 2 (1997 AIM):
// Strict bilateral 1:1 session isolation prevents @mention role hijacking, cross-agent
// crosstalk, and vector RAG leakage.
func TestEra2_AIM_1on1SessionBoundary(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	defer store.Close()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	var mu sync.Mutex
	var capturedSpans []storage.TelemetrySpan
	broadcaster := func(evt string, p interface{}) {
		mu.Lock()
		defer mu.Unlock()
		if evt == "memory_telemetry" {
			if span, ok := p.(storage.TelemetrySpan); ok {
				capturedSpans = append(capturedSpans, span)
			}
		}
	}

	gemini := NewGeminiClient(DefaultGeminiConfig())
	orc := NewOrchestrator(store, gemini, broadcaster)

	channelID := "chan-1997-aim" // 1:1 DM with Lead Coordinator
	ch, err := store.GetChannel(ctx, channelID)
	if err != nil {
		t.Fatalf("channel %s not found: %v", channelID, err)
	}

	// Verify storage role lockdown on AIM channels
	if len(ch.AllowedRoles) != 1 || ch.AllowedRoles[0] != "lead-agent" {
		t.Errorf("expected chan-1997-aim AllowedRoles to be ['lead-agent'], got %v", ch.AllowedRoles)
	}

	// User attempts to mention @researcher or inquire about peer agents in Lead's 1:1 DM
	userMsg, err := orc.HandleIncomingUserMessage(
		ctx,
		channelID,
		"",
		"@researcher what are you working on right now? Can you inspect scribe's notes?",
		"Jason Davenport",
	)
	if err != nil {
		t.Fatalf("failed to handle user message: %v", err)
	}
	_ = userMsg

	// 1. Invariant: Session Boundary Check telemetry span must be emitted
	var boundarySpan *storage.TelemetrySpan
	for start := time.Now(); time.Since(start) < 2*time.Second; {
		mu.Lock()
		for _, span := range capturedSpans {
			if span.Action == "SESSION_BOUNDARY_CHECK" && span.ChannelID == channelID {
				s := span
				boundarySpan = &s
				break
			}
		}
		mu.Unlock()
		if boundarySpan != nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	if boundarySpan == nil {
		t.Fatalf("expected SESSION_BOUNDARY_CHECK span for cross-agent probe in 1:1 AIM session")
	}
	if boundarySpan.Metrics["peer_isolated"] != true {
		t.Errorf("expected peer_isolated metric to be true, got %v", boundarySpan.Metrics["peer_isolated"])
	}

	// 2. Invariant: Prompt directive strictly fences working memory to 1:1 session
	lead, _ := GetRoleByID("lead-agent")
	era, _ := store.GetEra(ctx, "era-1997-aim")
	pCtx := &PromptContext{
		Era: era,
	}
	sysPrompt, _ := BuildAgentPrompt(lead, *ch, nil, nil, "Inquire about peers", pCtx)

	if !strings.Contains(sysPrompt, "1:1 Working Memory Session Boundary") {
		t.Errorf("system prompt missing 1:1 session boundary directive: %s", sysPrompt)
	}
	if !strings.Contains(sysPrompt, "STRICT MEMORY ISOLATION INVARIANT") {
		t.Errorf("system prompt missing strict memory isolation invariant: %s", sysPrompt)
	}
}

// TestEra3_Campfire_RoleFirewallQuarantine validates the cognitive boundary of Era 3 (2006 Campfire):
// Role-based context firewall enforces AllowedRoles and rejects unauthorized callers.
func TestEra3_Campfire_RoleFirewallQuarantine(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	defer store.Close()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	channelID := "chan-2006-campfire" // Executive Apollo Billing room
	ch, err := store.GetChannel(ctx, channelID)
	if err != nil {
		t.Fatalf("channel %s not found: %v", channelID, err)
	}

	// Allowed roles are: lead-agent, scribe-agent, jason
	// Dev Researcher is UNAUTHORIZED in this confidential channel
	researcher, _ := GetRoleByID("researcher-agent")

	isAllowed := false
	if len(ch.AllowedRoles) == 0 {
		isAllowed = true
	} else {
		for _, allowed := range ch.AllowedRoles {
			if allowed == researcher.ID {
				isAllowed = true
				break
			}
		}
	}

	if isAllowed {
		t.Fatalf("security violation: researcher-agent should NOT be allowed in %s (allowed: %v)", channelID, ch.AllowedRoles)
	}

	// Verify prompt directive enforces room topic boundary
	era, _ := store.GetEra(ctx, "era-2006-campfire")
	pCtx := &PromptContext{
		Era: era,
	}
	sysPrompt, _ := BuildAgentPrompt(researcher, *ch, nil, nil, "Query billing data", pCtx)
	if !strings.Contains(sysPrompt, "Scoped Room & Topic Boundary") {
		t.Errorf("system prompt missing Scoped Room boundary directive: %s", sysPrompt)
	}
}

// TestEra4_SlackV1_VectorRAGScoping validates the cognitive boundary of Era 4 (2013 Slack 1.0):
// Long-Term Memory retrieval is grounded strictly in Spanner vector similarity,
// filtering by cosine distance to prevent hallucinations or context dilution.
func TestEra4_SlackV1_VectorRAGScoping(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	defer store.Close()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	channelID := "chan-incident-postmortem"
	ch, err := store.GetChannel(ctx, channelID)
	if err != nil {
		t.Fatalf("channel %s not found: %v", channelID, err)
	}

	// Query vector representing ADR-019 Spanner architecture
	vQuery := []float32{0.82, 0.74, 0.21, 0.12, 0.91, 0.15, 0.05, 0.88, 0.79, 0.18, 0.11, 0.85, 0.14, 0.06, 0.83, 0.77}
	hits, err := store.SearchVectors(ctx, channelID, vQuery, 2)
	if err != nil {
		t.Fatalf("vector search failed: %v", err)
	}
	if len(hits) == 0 {
		t.Fatalf("expected at least 1 vector hit for incident postmortem search")
	}

	// Verify cosine distance threshold (< 0.40, meaning similarity >= 0.60)
	for _, hit := range hits {
		if hit.Similarity < 0.60 {
			t.Errorf("similarity too low for grounded retrieval: %f", hit.Similarity)
		}
	}

	// Verify prompt grounding directive
	researcher, _ := GetRoleByID("researcher-agent")
	era, _ := store.GetEra(ctx, "era-2013-slack")
	pCtx := &PromptContext{
		Era: era,
	}
	sysPrompt, _ := BuildAgentPrompt(researcher, *ch, nil, hits, "Explain ADR-019", pCtx)
	if !strings.Contains(sysPrompt, "Long-Term Memory Grounding Boundary") {
		t.Errorf("system prompt missing LTM grounding boundary directive: %s", sysPrompt)
	}
}

// TestEra5_SlackThreads_SubTaskIsolation validates the cognitive boundary of Era 5 (2017 Threads):
// Thread subagent investigations stay strictly inside thread scratchpads, shielding the
// root channel token budget until Scribe issues an explicit compaction rollup.
func TestEra5_SlackThreads_SubTaskIsolation(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	defer store.Close()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	channelID := "chan-architecture-rfc"
	threadID := "thread-subtask-investigation"

	// 1. Record initial root channel message count
	rootBefore, err := store.ListMessages(ctx, channelID, "", 100)
	if err != nil {
		t.Fatalf("failed to list root messages: %v", err)
	}

	// 2. Add 10 exploratory debugging turns INSIDE the thread
	for i := 1; i <= 10; i++ {
		threadMsg := storage.Message{
			ID:         fmt.Sprintf("thread-turn-msg-%d", i),
			ChannelID:  channelID,
			ThreadID:   threadID,
			SenderID:   "researcher-agent",
			SenderName: "Dev Researcher",
			Content:    fmt.Sprintf("Stack trace analysis step %d", i),
			CreatedAt:  time.Now(),
		}
		if err := store.SaveMessage(ctx, threadMsg); err != nil {
			t.Fatalf("failed to save thread message: %v", err)
		}
	}

	// 3. Invariant: Root channel message count must NOT increase
	rootAfter, err := store.ListMessages(ctx, channelID, "", 100)
	if err != nil {
		t.Fatalf("failed to list root messages: %v", err)
	}
	if len(rootAfter) != len(rootBefore) {
		t.Fatalf("thread leak: root channel message count increased from %d to %d", len(rootBefore), len(rootAfter))
	}

	// 4. Verify thread messages are preserved in isolated scratchpad
	threadMsgs, err := store.ListMessages(ctx, channelID, threadID, 100)
	if err != nil {
		t.Fatalf("failed to list thread messages: %v", err)
	}
	if len(threadMsgs) != 10 {
		t.Fatalf("expected 10 messages in thread scratchpad, got %d", len(threadMsgs))
	}

	// 5. Invariant: Scribe compaction prompt directive
	scribe, _ := GetRoleByID("scribe-agent")
	ch, err := store.GetChannel(ctx, channelID)
	if err != nil {
		t.Fatalf("failed to get channel %s: %v", channelID, err)
	}
	era, _ := store.GetEra(ctx, "era-2017-threads")
	pCtx := &PromptContext{
		Era: era,
	}
	sysPrompt, _ := BuildAgentPrompt(scribe, *ch, nil, nil, "@scribe summarize thread", pCtx)
	if !strings.Contains(sysPrompt, "Thread Isolation & Scribe Compaction Boundary") {
		t.Errorf("system prompt missing thread isolation boundary directive: %s", sysPrompt)
	}
}

// TestEra6_AgentMesh_DualLayerMemoryAndDreaming validates the cognitive boundary of Era 6 (2026 Mesh):
// Shared team blackboard is strictly segregated from confidential private agent scratchpads;
// offline REM dreaming consolidates durable facts while pruning ephemeral chatter.
func TestEra6_AgentMesh_DualLayerMemoryAndDreaming(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	defer store.Close()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	channelID := "chan-product-launch"
	agentID := "lead-agent"

	// 1. Set confidential private scratchpad for Lead Agent
	scratchpad := storage.PrivateScratchpad{
		AgentID:       agentID,
		ChannelID:     channelID,
		InnerThoughts: []string{"Private thought: Candidate architectural solution needs 2PC verification."},
		DraftPlan:     "Private draft: Do not deploy until consensus reached.",
		ToolTraces:    []string{"Spanner latency test: 4.2ms"},
		UpdatedAt:     time.Now(),
	}
	if err := store.SavePrivateScratchpad(ctx, scratchpad); err != nil {
		t.Fatalf("failed to save scratchpad: %v", err)
	}

	// 2. Verify prompt injection: Scratchpad is injected under Private Working Memory
	lead, _ := GetRoleByID(agentID)
	ch, err := store.GetChannel(ctx, channelID)
	if err != nil {
		t.Fatalf("failed to get channel %s: %v", channelID, err)
	}
	era, _ := store.GetEra(ctx, "era-2026-agent-mesh")
	pCtx := &PromptContext{
		Era:        era,
		Scratchpad: &scratchpad,
	}
	sysPrompt, userPrompt := BuildAgentPrompt(lead, *ch, nil, nil, "What is our deployment plan?", pCtx)

	if !strings.Contains(sysPrompt, "Dual-Layer Memory & Privacy Boundary") {
		t.Errorf("system prompt missing dual-layer privacy boundary directive: %s", sysPrompt)
	}
	if !strings.Contains(userPrompt, "### Private Cognitive Working Memory") {
		t.Errorf("prompt missing private cognitive working memory section: %s", userPrompt)
	}
	if !strings.Contains(userPrompt, "Private thought: Candidate architectural solution needs 2PC verification") {
		t.Errorf("prompt missing inner thoughts: %s", userPrompt)
	}

	// 3. Invariant: Private scratchpad of Lead is NOT visible to Researcher
	researcherPad, err := store.GetPrivateScratchpad(ctx, "researcher-agent", channelID)
	if err != nil {
		t.Fatalf("failed to get researcher scratchpad: %v", err)
	}
	if researcherPad != nil && len(researcherPad.InnerThoughts) > 0 {
		t.Fatalf("cognitive leak: researcher scratchpad contaminated with lead scratchpad data")
	}

	// 4. Test Dreaming consolidation: Verify seeded and saved consolidation reports
	reports, err := store.ListConsolidationReports(ctx, channelID)
	if err != nil {
		t.Fatalf("failed to list consolidation reports: %v", err)
	}
	if len(reports) == 0 {
		t.Fatalf("expected at least 1 seeded consolidation report for 2026 agent mesh")
	}

	firstReport := reports[0]
	if firstReport.InsightSummary == "" {
		t.Fatalf("expected insight summary in consolidation report")
	}
	if len(firstReport.DistilledFacts) == 0 {
		t.Fatalf("expected distilled facts from dreaming consolidation")
	}
	if len(firstReport.CrystallizedBeliefs) == 0 {
		t.Fatalf("expected crystallized beliefs in consolidation report, got 0")
	}
	if firstReport.DreamPromptUsed == "" {
		t.Fatalf("expected dream prompt used to be recorded in consolidation report")
	}
	if firstReport.IntentTrajectory == "" {
		t.Fatalf("expected intent trajectory to be recorded in consolidation report")
	}

	// 5. Fast-Path Crystalline Recall queries on #product-launch-ga
	stackBeliefs, err := store.SearchCrystallizedBeliefs(ctx, "#product-launch-ga", "What is our deployment stack?")
	if err != nil || len(stackBeliefs) == 0 {
		t.Fatalf("expected crystallized belief hit for deployment stack, got %v (err: %v)", stackBeliefs, err)
	}
	if stackBeliefs[0].Key != "deployment_stack" {
		t.Errorf("expected top hit key 'deployment_stack', got %s", stackBeliefs[0].Key)
	}
	if stackBeliefs[0].Confidence < 0.90 {
		t.Errorf("expected high confidence (>0.90), got %.2f", stackBeliefs[0].Confidence)
	}

	secBeliefs, err := store.SearchCrystallizedBeliefs(ctx, channelID, "security policies")
	if err != nil || len(secBeliefs) == 0 {
		t.Fatalf("expected crystallized belief hit for security policies, got %v (err: %v)", secBeliefs, err)
	}
	if secBeliefs[0].Key != "security_policies" {
		t.Errorf("expected top hit key 'security_policies', got %s", secBeliefs[0].Key)
	}

	guideBeliefs, err := store.SearchCrystallizedBeliefs(ctx, channelID, "agreed guidelines")
	if err != nil || len(guideBeliefs) == 0 {
		t.Fatalf("expected crystallized belief hit for agreed guidelines, got %v (err: %v)", guideBeliefs, err)
	}
	if guideBeliefs[0].Key != "agreed_guidelines" {
		t.Errorf("expected top hit key 'agreed_guidelines', got %s", guideBeliefs[0].Key)
	}

	// 6. Verify prompt injection when crystallized beliefs are present in PromptContext
	pCtxWithBeliefs := &PromptContext{
		Era:                 era,
		Scratchpad:          &scratchpad,
		CrystallizedBeliefs: stackBeliefs,
	}
	_, userPromptWithBeliefs := BuildAgentPrompt(lead, *ch, nil, nil, "What is our deployment stack?", pCtxWithBeliefs)
	if !strings.Contains(userPromptWithBeliefs, "### Crystallized Beliefs (Consolidated Long-Term Memory)") {
		t.Errorf("expected prompt to contain crystallized beliefs section, got: %s", userPromptWithBeliefs)
	}
	if !strings.Contains(userPromptWithBeliefs, "deployment_stack") {
		t.Errorf("expected prompt to contain 'deployment_stack' key, got: %s", userPromptWithBeliefs)
	}
}
