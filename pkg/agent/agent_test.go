package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

type roundTripFunc func(req *http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

func TestAgentRoles(t *testing.T) {
	lead, ok := GetRoleByID("lead-agent")
	if !ok || lead.Name != "Lead Coordinator" {
		t.Fatalf("expected Lead Coordinator role, got %v", lead)
	}

	scribe, ok := GetRoleByID("scribe-agent")
	if !ok || scribe.Name != "Staff Architect Scribe" {
		t.Fatalf("expected Staff Architect Scribe role, got %v", scribe)
	}

	researcher, ok := GetRoleByID("researcher-agent")
	if !ok || researcher.Name != "Dev Researcher" {
		t.Fatalf("expected Dev Researcher role, got %v", researcher)
	}

	eggdrop, ok := GetRoleByID("eggdrop-bot")
	if !ok || eggdrop.Name != "Eggdrop Bot" {
		t.Fatalf("expected Eggdrop Bot role, got %v", eggdrop)
	}
}

func TestBuildAgentPrompt(t *testing.T) {
	ch := storage.Channel{
		Name:         "architecture-rfc",
		Topic:        "Transactional Outbox vs Spanner 2PC",
		SystemPrompt: "Evaluate consistency and token limits",
	}

	recent := []storage.Message{
		{
			SenderName: "Jason Davenport",
			SenderID:   "jason",
			Content:    "Should we use Kafka outbox?",
		},
	}

	vectorHits := []storage.VectorSearchResult{
		{
			Similarity: 0.95,
			Message: storage.Message{
				SenderName: "Dev Researcher",
				Content:    "ADR-019 documents that 2PC is required for ledger consistency.",
			},
		},
	}

	pCtx := &PromptContext{
		Era: &storage.Era{
			Year:          2017,
			Name:          "Threads & Scribe Compaction",
			Platform:      "Slack Threads",
			MemoryConcept: "Sub-Task Isolation",
			Description:   "Thread scratchpads preserve main channel context.",
		},
		Presence: &storage.AgentPresence{
			Status:        "available",
			StatusMessage: "Reviewing RFCs",
		},
		Scratchpad: &storage.PrivateScratchpad{
			InnerThoughts: []string{"Need to check Spanner 2PC latency trade-offs"},
			DraftPlan:     "Propose Spanner synchronous commit",
		},
	}

	sys, user := BuildAgentPrompt(DevResearcher, ch, recent, vectorHits, "Explain the ADR-019 rationale.", pCtx)

	if !strings.Contains(sys, "Dev Researcher") {
		t.Errorf("system prompt missing persona: %s", sys)
	}
	if !strings.Contains(sys, "2017 — Threads & Scribe Compaction") {
		t.Errorf("system prompt missing era context: %s", sys)
	}
	if !strings.Contains(sys, "Reviewing RFCs") {
		t.Errorf("system prompt missing presence status message: %s", sys)
	}
	if !strings.Contains(user, "ADR-019") {
		t.Errorf("user prompt missing vector memory hit: %s", user)
	}
	if !strings.Contains(user, "Private Cognitive Working Memory") {
		t.Errorf("user prompt missing private scratchpad: %s", user)
	}
	if !strings.Contains(user, "Need to check Spanner 2PC latency trade-offs") {
		t.Errorf("user prompt missing inner monologue thought: %s", user)
	}
	if !strings.Contains(user, "Recent Conversation Stream") {
		t.Errorf("user prompt missing working context: %s", user)
	}
	if !strings.Contains(sys, "Thread Isolation & Scribe Compaction Boundary") {
		t.Errorf("system prompt missing 2017 boundary directive: %s", sys)
	}

	// Verify AIM 1:1 directive
	chAIM := storage.Channel{
		ID:              "chan-1997-aim",
		EraID:           "era-1997-aim",
		Name:            "1997-aim-lead",
		IsDirectMessage: true,
	}
	sysAIM, _ := BuildAgentPrompt(LeadCoordinator, chAIM, nil, nil, "Hello", nil)
	if !strings.Contains(sysAIM, "STRICT MEMORY ISOLATION INVARIANT") {
		t.Errorf("AIM system prompt missing 1:1 memory isolation invariant: %s", sysAIM)
	}

	// Verify AIM Away Persona Priming directive
	pCtxAway := &PromptContext{
		Presence: &storage.AgentPresence{
			AgentID:       "scribe-agent",
			Status:        "away",
			StatusMessage: "Away: Compacting architectural RFC thread history",
			CurrentTask:   "Compaction cycle",
		},
	}
	sysAIMAway, _ := BuildAgentPrompt(StaffArchitectScribe, chAIM, nil, nil, "Are you there?", pCtxAway)
	if !strings.Contains(sysAIMAway, "Dynamic Away Persona Priming (ACTIVE)") {
		t.Errorf("AIM system prompt missing Dynamic Away Persona Priming: %s", sysAIMAway)
	}
	if !strings.Contains(sysAIMAway, "Away: Compacting architectural RFC thread history") {
		t.Errorf("AIM system prompt missing away memo: %s", sysAIMAway)
	}
	if !strings.Contains(sysAIMAway, "automated away-delegate") {
		t.Errorf("AIM system prompt missing auto-responder directive: %s", sysAIMAway)
	}

	// Verify 1988 IRC directive
	chIRC := storage.Channel{
		ID:    "chan-1988-irc",
		EraID: "era-1988-irc",
		Name:  "1988-irc",
	}
	sysIRC, _ := BuildAgentPrompt(EggdropBot, chIRC, nil, nil, "Hello", nil)
	if !strings.Contains(sysIRC, "volatile 5-turn RAM and evicted turns are unrecoverable") {
		t.Errorf("IRC system prompt missing volatile RAM directive: %s", sysIRC)
	}

	// Verify 2006 Campfire directive
	chCamp := storage.Channel{
		ID:    "chan-2006-campfire",
		EraID: "era-2006-campfire",
		Name:  "2006-campfire-billing",
	}
	sysCamp, _ := BuildAgentPrompt(LeadCoordinator, chCamp, nil, nil, "Hello", nil)
	if !strings.Contains(sysCamp, "Scoped Room & Topic Boundary") {
		t.Errorf("Campfire system prompt missing scoped room directive: %s", sysCamp)
	}

	// Verify 2013 Slack directive
	chSlack := storage.Channel{
		ID:    "chan-2013-slack",
		EraID: "era-2013-slack",
		Name:  "2013-slack",
	}
	sysSlack, _ := BuildAgentPrompt(DevResearcher, chSlack, nil, nil, "Hello", nil)
	if !strings.Contains(sysSlack, "Long-Term Memory Grounding Boundary") {
		t.Errorf("Slack system prompt missing grounding directive: %s", sysSlack)
	}

	// Verify 2026 Mesh directive
	chMesh := storage.Channel{
		ID:    "chan-2026-agent-mesh",
		EraID: "era-2026-agent-mesh",
		Name:  "2026-mesh",
	}
	sysMesh, _ := BuildAgentPrompt(LeadCoordinator, chMesh, nil, nil, "Hello", nil)
	if !strings.Contains(sysMesh, "Dual-Layer Memory & Privacy Boundary") {
		t.Errorf("Mesh system prompt missing dual-layer privacy directive: %s", sysMesh)
	}
}

func TestContextFencing(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()

	// Channel strictly limited to lead-agent and jason
	ch := storage.Channel{
		ID:           "chan-fenced",
		Name:         "apollo-billing",
		AllowedRoles: []string{"lead-agent", "jason"},
		CreatedAt:    time.Now(),
	}
	_ = store.CreateChannel(ctx, ch)

	gemini := NewGeminiClient(DefaultGeminiConfig())
	orch := NewOrchestrator(store, gemini, nil)

	// DevResearcher attempts to respond in the fenced channel
	msg, err := orch.TriggerAgentResponse(ctx, ch.ID, "", DevResearcher, "What is the billing balance?")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if msg.SenderID != "context-firewall" {
		t.Fatalf("expected context-firewall to block access, got sender: %s", msg.SenderID)
	}
	if !strings.Contains(msg.Content, "Context Fencing Quarantine") {
		t.Fatalf("expected quarantine notice in content, got: %s", msg.Content)
	}
}

func TestOrchestratorPacing(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	_ = store.ResetAndSeed(ctx)

	var lastEvent string
	var lastPayload interface{}
	broadcaster := func(evt string, p interface{}) {
		lastEvent = evt
		lastPayload = p
	}

	gemini := NewGeminiClient(DefaultGeminiConfig())
	orch := NewOrchestrator(store, gemini, broadcaster)

	// Test default pacing
	pacing := orch.GetPacing()
	if pacing.Paused || pacing.IntervalSeconds <= 0 {
		t.Fatalf("unexpected default pacing: %+v", pacing)
	}

	// Update pacing
	orch.SetPacing(PacingMode{Paused: true, IntervalSeconds: 15})
	updated := orch.GetPacing()
	if !updated.Paused || updated.IntervalSeconds != 15 {
		t.Fatalf("pacing not updated: %+v", updated)
	}
	if lastEvent != "pacing_updated" {
		t.Fatalf("expected pacing_updated broadcast, got %s", lastEvent)
	}
	_ = lastPayload
}

func TestOrchestratorUserMessage(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	_ = store.ResetAndSeed(ctx)

	eventCount := 0
	broadcaster := func(evt string, p interface{}) {
		if evt == "new_message" {
			eventCount++
		}
	}

	gemini := NewGeminiClient(DefaultGeminiConfig())
	orch := NewOrchestrator(store, gemini, broadcaster)

	msg, err := orch.HandleIncomingUserMessage(ctx, "chan-incident-postmortem", "", "Investigate the latency spike", "Jason Davenport")
	if err != nil {
		t.Fatalf("failed to handle user message: %v", err)
	}

	if msg.SenderID != "jason" {
		t.Fatalf("expected sender jason, got %s", msg.SenderID)
	}

	// Wait briefly for broadcast
	time.Sleep(50 * time.Millisecond)
	if eventCount == 0 {
		t.Fatalf("expected new_message broadcast to trigger")
	}
}

func TestOrchestratorAIMAndEraRouting(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	_ = store.ResetAndSeed(ctx)

	var lastTargetRole string
	broadcaster := func(evt string, p interface{}) {
		if evt == "agent_typing" {
			if m, ok := p.(map[string]string); ok {
				lastTargetRole = m["agent_id"]
			}
		}
	}

	gemini := NewGeminiClient(DefaultGeminiConfig())
	orch := NewOrchestrator(store, gemini, broadcaster)

	// 1. AIM Scribe channel should route to scribe-agent
	_, err := orch.HandleIncomingUserMessage(ctx, "chan-1997-aim-scribe", "", "Check rollup checkpoint", "Jason")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	time.Sleep(50 * time.Millisecond)
	if lastTargetRole != StaffArchitectScribe.ID {
		t.Fatalf("expected routing to %s, got %s", StaffArchitectScribe.ID, lastTargetRole)
	}

	// 2. AIM Researcher channel should route to researcher-agent
	_, err = orch.HandleIncomingUserMessage(ctx, "chan-1997-aim-researcher", "", "Check Spanner vector index", "Jason")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	time.Sleep(50 * time.Millisecond)
	if lastTargetRole != DevResearcher.ID {
		t.Fatalf("expected routing to %s, got %s", DevResearcher.ID, lastTargetRole)
	}

	// 3. IRC channel should route to eggdrop-bot
	_, err = orch.HandleIncomingUserMessage(ctx, "chan-1988-irc", "", "/names", "Jason")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	time.Sleep(50 * time.Millisecond)
	if lastTargetRole != EggdropBot.ID {
		t.Fatalf("expected routing to %s, got %s", EggdropBot.ID, lastTargetRole)
	}

	// 4. In chan-1997-aim (Lead session), mentioning @researcher must NOT switch to DevResearcher!
	_, err = orch.HandleIncomingUserMessage(ctx, "chan-1997-aim", "", "Hey @researcher what is your status?", "Jason")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	time.Sleep(50 * time.Millisecond)
	if lastTargetRole != LeadCoordinator.ID {
		t.Fatalf("expected routing to %s even when @researcher is mentioned in 1:1 session, got %s", LeadCoordinator.ID, lastTargetRole)
	}

	// 5. In chan-1997-aim-scribe, mentioning @lead must NOT switch to LeadCoordinator!
	_, err = orch.HandleIncomingUserMessage(ctx, "chan-1997-aim-scribe", "", "Hey @lead please check this", "Jason")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	time.Sleep(50 * time.Millisecond)
	if lastTargetRole != StaffArchitectScribe.ID {
		t.Fatalf("expected routing to %s even when @lead is mentioned, got %s", StaffArchitectScribe.ID, lastTargetRole)
	}
}

func TestMemoryTelemetryBroadcasting(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	var telemetrySpans []storage.TelemetrySpan
	var mu sync.Mutex
	broadcaster := func(evt string, p interface{}) {
		if evt == "memory_telemetry" {
			if span, ok := p.(storage.TelemetrySpan); ok {
				mu.Lock()
				telemetrySpans = append(telemetrySpans, span)
				mu.Unlock()
			}
		}
	}

	gemini := NewGeminiClient(DefaultGeminiConfig())
	orch := NewOrchestrator(store, gemini, broadcaster)

	getSpansByAction := func(action string) []storage.TelemetrySpan {
		mu.Lock()
		defer mu.Unlock()
		var res []storage.TelemetrySpan
		for _, s := range telemetrySpans {
			if s.Action == action {
				res = append(res, s)
			}
		}
		return res
	}

	// 1. Verify STORE_WRITE on standard persistent channel
	_, err := orch.HandleIncomingUserMessage(ctx, "chan-incident-postmortem", "", "Investigate latency audit trail", "Jason")
	if err != nil {
		t.Fatalf("HandleIncomingUserMessage failed: %v", err)
	}

	storeWrites := getSpansByAction("STORE_WRITE")
	if len(storeWrites) == 0 {
		t.Fatalf("expected STORE_WRITE telemetry span")
	}
	sw := storeWrites[len(storeWrites)-1]
	if sw.ActiveStep != 1 {
		t.Errorf("expected STORE_WRITE ActiveStep 1, got %d", sw.ActiveStep)
	}
	if sw.Title != "Persistent Audit Trail: Message Saved" {
		t.Errorf("expected Title 'Persistent Audit Trail: Message Saved', got %s", sw.Title)
	}
	if sw.ChannelID != "chan-incident-postmortem" {
		t.Errorf("expected ChannelID 'chan-incident-postmortem', got %s", sw.ChannelID)
	}
	if sw.Metrics["token_count"] == nil {
		t.Errorf("expected token_count in metrics")
	}

	// 2. Verify FIFO_WRITE on 1988 IRC channel
	_, err = orch.HandleIncomingUserMessage(ctx, "chan-1988-irc", "", "IRC message 1", "Jason")
	if err != nil {
		t.Fatalf("HandleIncomingUserMessage on IRC failed: %v", err)
	}

	fifoWrites := getSpansByAction("FIFO_WRITE")
	if len(fifoWrites) == 0 {
		t.Fatalf("expected FIFO_WRITE telemetry span")
	}
	fw := fifoWrites[len(fifoWrites)-1]
	if fw.ActiveStep != 2 {
		t.Errorf("expected FIFO_WRITE ActiveStep 2, got %d", fw.ActiveStep)
	}
	if fw.Title != "FIFO Buffer: Message Stored in RAM" {
		t.Errorf("expected Title 'FIFO Buffer: Message Stored in RAM', got %s", fw.Title)
	}
	if fw.Metrics["max_buffer_turns"] == nil || fw.Metrics["current_turns"] == nil {
		t.Errorf("expected current_turns and max_buffer_turns in metrics: %+v", fw.Metrics)
	}

	// 3. Verify FIFO_EVICT when RAM buffer is exceeded
	// chan-1988-irc has MaxBufferTurns = 5.
	for i := 2; i <= 6; i++ {
		_, _ = orch.HandleIncomingUserMessage(ctx, "chan-1988-irc", "", fmt.Sprintf("IRC overflow turn %d", i), "Jason")
	}

	fifoEvicts := getSpansByAction("FIFO_EVICT")
	if len(fifoEvicts) == 0 {
		t.Fatalf("expected FIFO_EVICT telemetry span after filling buffer")
	}
	fe := fifoEvicts[0]
	if fe.ActiveStep != 3 {
		t.Errorf("expected FIFO_EVICT ActiveStep 3, got %d", fe.ActiveStep)
	}
	if fe.Title != "Amnesia Trap: Oldest Turn Evicted from RAM" {
		t.Errorf("expected Title 'Amnesia Trap: Oldest Turn Evicted from RAM', got %s", fe.Title)
	}
	if fe.Metrics["evicted_count"] == nil {
		t.Errorf("expected evicted_count in metrics")
	}
	if fe.Payload == "" {
		t.Errorf("expected payload with evicted message snippet")
	}

	// 4. Verify ATTENTIONAL_SHIFT and FIREWALL_EVAL / FIREWALL_QUARANTINE in 2006 Campfire
	// DevResearcher is denied in chan-2006-campfire (AllowedRoles: lead-agent, scribe-agent, jason)
	_, _ = orch.TriggerAgentResponse(ctx, "chan-2006-campfire", "", DevResearcher, "Query billing ledger")

	shifts := getSpansByAction("ATTENTIONAL_SHIFT")
	var campfireShift *storage.TelemetrySpan
	for _, s := range shifts {
		if s.ChannelID == "chan-2006-campfire" && s.Metrics["agent_role"] == DevResearcher.ID {
			copied := s
			campfireShift = &copied
			break
		}
	}
	if campfireShift == nil {
		t.Fatalf("expected ATTENTIONAL_SHIFT telemetry span for DevResearcher in chan-2006-campfire")
	}
	if campfireShift.ActiveStep != 2 {
		t.Errorf("expected ATTENTIONAL_SHIFT ActiveStep 2, got %d", campfireShift.ActiveStep)
	}
	if campfireShift.Title != "Attentional State Shift: Agent Typing" {
		t.Errorf("expected Title 'Attentional State Shift: Agent Typing', got %s", campfireShift.Title)
	}

	firewallEvals := getSpansByAction("FIREWALL_EVAL")
	var campfireEval *storage.TelemetrySpan
	for _, s := range firewallEvals {
		if s.ChannelID == "chan-2006-campfire" {
			copied := s
			campfireEval = &copied
			break
		}
	}
	if campfireEval == nil {
		t.Fatalf("expected FIREWALL_EVAL telemetry span for chan-2006-campfire")
	}
	if campfireEval.ActiveStep != 3 { // ActiveStep 3 for 2006
		t.Errorf("expected FIREWALL_EVAL ActiveStep 3 for 2006, got %d", campfireEval.ActiveStep)
	}

	firewallQuarantines := getSpansByAction("FIREWALL_QUARANTINE")
	var campfireQuarantine *storage.TelemetrySpan
	for _, s := range firewallQuarantines {
		if s.ChannelID == "chan-2006-campfire" {
			copied := s
			campfireQuarantine = &copied
			break
		}
	}
	if campfireQuarantine == nil {
		t.Fatalf("expected FIREWALL_QUARANTINE telemetry span for chan-2006-campfire")
	}
	if campfireQuarantine.ActiveStep != 3 { // ActiveStep 3 for 2006
		t.Errorf("expected FIREWALL_QUARANTINE ActiveStep 3 for 2006, got %d", campfireQuarantine.ActiveStep)
	}
	if campfireQuarantine.Title != "Context Fencing Quarantine: Access Denied" {
		t.Errorf("expected Title 'Context Fencing Quarantine: Access Denied', got %s", campfireQuarantine.Title)
	}

	// 5. Verify ATTENTIONAL_SHIFT for 1997 AIM (ActiveStep 1)
	_, _ = orch.TriggerAgentResponse(ctx, "chan-1997-aim", "", LeadCoordinator, "AIM check")
	aimShifts := getSpansByAction("ATTENTIONAL_SHIFT")
	foundAimShift := false
	for _, s := range aimShifts {
		if s.ChannelID == "chan-1997-aim" {
			foundAimShift = true
			if s.ActiveStep != 1 {
				t.Errorf("expected ATTENTIONAL_SHIFT ActiveStep 1 for 1997 AIM, got %d", s.ActiveStep)
			}
		}
	}
	if !foundAimShift {
		t.Errorf("expected ATTENTIONAL_SHIFT for 1997 AIM")
	}

	// 6. Verify VECTOR_SEARCH span (DevResearcher in chan-incident-postmortem)
	_, _ = orch.TriggerAgentResponse(ctx, "chan-incident-postmortem", "", DevResearcher, "What is past history on Spanner?")
	vectorSearches := getSpansByAction("VECTOR_SEARCH")
	if len(vectorSearches) == 0 {
		t.Fatalf("expected VECTOR_SEARCH telemetry span")
	}
	vs := vectorSearches[0]
	if vs.ActiveStep != 3 {
		t.Errorf("expected VECTOR_SEARCH ActiveStep 3, got %d", vs.ActiveStep)
	}
	if vs.Title != "Spanner Vector Search: Exact Cosine Distance" {
		t.Errorf("expected Title 'Spanner Vector Search: Exact Cosine Distance', got %s", vs.Title)
	}
	if vs.Metrics["similarity"] == nil || vs.Metrics["distance"] == nil || vs.Metrics["hit_count"] == nil {
		t.Errorf("expected similarity, distance, and hit_count in metrics: %+v", vs.Metrics)
	}

	// 7. Verify SESSION_BOUNDARY_CHECK in 1997 AIM when inquiring about peer agents
	_, _ = orch.TriggerAgentResponse(ctx, "chan-1997-aim", "", LeadCoordinator, "What is @researcher doing in private?")
	boundaryChecks := getSpansByAction("SESSION_BOUNDARY_CHECK")
	if len(boundaryChecks) == 0 {
		t.Fatalf("expected SESSION_BOUNDARY_CHECK telemetry span")
	}
	bc := boundaryChecks[0]
	if bc.ActiveStep != 1 {
		t.Errorf("expected SESSION_BOUNDARY_CHECK ActiveStep 1, got %d", bc.ActiveStep)
	}
	if bc.Metrics["boundary_check"] != "PASSED" || bc.Metrics["peer_isolated"] != true {
		t.Errorf("expected boundary_check PASSED and peer_isolated true in metrics: %+v", bc.Metrics)
	}

	// 8. Verify Vector Search is strictly suppressed for 1988 IRC and 1997 AIM
	priorVsCount := len(getSpansByAction("VECTOR_SEARCH"))
	_, _ = orch.TriggerAgentResponse(ctx, "chan-1988-irc", "", EggdropBot, "What is the past history?")
	_, _ = orch.TriggerAgentResponse(ctx, "chan-1997-aim", "", LeadCoordinator, "Tell me the past history")
	postVsCount := len(getSpansByAction("VECTOR_SEARCH"))
	if postVsCount != priorVsCount {
		t.Errorf("expected zero vector searches in 1988 IRC and 1997 AIM, but count grew from %d to %d", priorVsCount, postVsCount)
	}

	// 9. Verify Scoped Vector Search in Campfire Eng
	_, _ = orch.TriggerAgentResponse(ctx, "chan-2006-campfire-eng", "", DevResearcher, "What is past history on vector index?")
	newVs := getSpansByAction("VECTOR_SEARCH")
	if len(newVs) <= priorVsCount {
		t.Fatalf("expected new VECTOR_SEARCH span for campfire eng")
	}
	campVs := newVs[len(newVs)-1]
	if campVs.Metrics["search_scope"] != "chan-2006-campfire-eng" {
		t.Errorf("expected search_scope to be chan-2006-campfire-eng, got %v", campVs.Metrics["search_scope"])
	}

	// 10. Verify Fast-Path Crystalline Recall in 2026 Mesh / #product-launch-ga
	_, _ = orch.TriggerAgentResponse(ctx, "chan-product-launch", "", LeadCoordinator, "What is our deployment stack?")
	recalls := getSpansByAction("CRYSTALLINE_RECALL")
	if len(recalls) == 0 {
		t.Fatalf("expected CRYSTALLINE_RECALL telemetry span for chan-product-launch")
	}
	cr := recalls[len(recalls)-1]
	if cr.ActiveStep != 2 {
		t.Errorf("expected CRYSTALLINE_RECALL ActiveStep 2, got %d", cr.ActiveStep)
	}
	if cr.Title != "⚡ Crystalline Cache (<10ms)" {
		t.Errorf("expected Title '⚡ Crystalline Cache (<10ms)', got %s", cr.Title)
	}
	if cr.Metrics["top_key"] != "deployment_stack" {
		t.Errorf("expected top_key deployment_stack, got %v", cr.Metrics["top_key"])
	}
}

func TestFastPathCrystallineRecallAndIntentTag(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	os.Setenv("GCP_ACCESS_TOKEN", "test-token-fastpath")
	defer os.Unsetenv("GCP_ACCESS_TOKEN")

	cfg := GeminiConfig{
		ProjectID: "davenport-boutique",
		Location:  "us-central1",
		Model:     "gemini-3.8-flash",
	}
	gemini := NewGeminiClient(cfg)
	gemini.SetTransport(roundTripFunc(func(r *http.Request) (*http.Response, error) {
		resp := map[string]interface{}{
			"candidates": []map[string]interface{}{
				{
					"content": map[string]interface{}{
						"parts": []map[string]interface{}{
							{"text": "Our deployment stack is standardized on Cloud Run with Vertex AI Gemini 3.8 Flash in davenport-boutique."},
						},
					},
					"finishReason": "STOP",
				},
			},
			"usageMetadata": map[string]interface{}{
				"promptTokenCount":     120,
				"candidatesTokenCount": 30,
				"totalTokenCount":      150,
			},
		}
		data, _ := json.Marshal(resp)
		header := make(http.Header)
		header.Set("Content-Type", "application/json")
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     header,
			Body:       io.NopCloser(bytes.NewReader(data)),
		}, nil
	}))
	orch := NewOrchestrator(store, gemini, nil)

	// Call TriggerAgentTurn with question matching crystallized belief
	msg, err := orch.TriggerAgentTurn(ctx, "chan-product-launch", "", LeadCoordinator, "What is our deployment stack?")
	if err != nil {
		t.Fatalf("TriggerAgentTurn failed: %v", err)
	}

	if len(msg.IntentTags) == 0 {
		t.Fatalf("expected intent tags on agent response")
	}

	// Verify crystalline cache hit intent tag is prepended
	firstTag := msg.IntentTags[0]
	if firstTag.Type != "crystalline_hit" {
		t.Errorf("expected first intent tag type 'crystalline_hit', got %s", firstTag.Type)
	}
	if firstTag.Label != "⚡ Crystalline Cache (<10ms)" {
		t.Errorf("expected label '⚡ Crystalline Cache (<10ms)', got %s", firstTag.Label)
	}
	if firstTag.Color != "purple" {
		t.Errorf("expected color 'purple', got %s", firstTag.Color)
	}
	if !strings.Contains(firstTag.Description, "Crystalline Memory Hit") {
		t.Errorf("expected description to mention Crystalline Memory Hit, got %s", firstTag.Description)
	}
}

func TestConsolidateMemory_REMSynthesis(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	var capturedUserPrompt string
	var capturedSysPrompt string

	// Simulated Gemini 3.8 Flash responding with structured REM dream synthesis JSON
	dreamJSON := `{
  "summary": "Swarm standardized on Cloud Run, Terraform, and Cloud Spanner with dual-layer memory.",
  "intent_trajectory": "Exploration -> Hardening -> GA Sign-off",
  "distilled_facts": [
    "Cloud Run is our production container target in davenport-boutique.",
    "Spanner vector indexing uses exact cosine distance with TREE_AH index."
  ],
  "crystallized_beliefs": [
    {
      "key": "cloud_run_prod_target",
      "value": "Cloud Run container target in davenport-boutique",
      "category": "Infrastructure",
      "confidence": 0.99,
      "keywords": "cloud run, container, production, davenport-boutique",
      "statement": "Cloud Run is our production container target in davenport-boutique."
    },
    {
      "key": "zero_secrets_rule",
      "value": "ADC auth with zero secrets in code",
      "category": "Security",
      "confidence": 0.99,
      "keywords": "adc, secrets, auth, security",
      "statement": "Zero API keys in code; always use Application Default Credentials (ADC)."
    }
  ]
}`

	os.Setenv("GCP_ACCESS_TOKEN", "test-token-dream")
	defer os.Unsetenv("GCP_ACCESS_TOKEN")

	cfg := GeminiConfig{
		ProjectID: "davenport-boutique",
		Location:  "us-central1",
		Model:     "gemini-3.8-flash",
	}
	gemini := NewGeminiClient(cfg)
	gemini.SetTransport(roundTripFunc(func(r *http.Request) (*http.Response, error) {
		var req GenerateContentRequest
		_ = json.NewDecoder(r.Body).Decode(&req)
		if len(req.Contents) > 0 && len(req.Contents[0].Parts) > 0 {
			capturedUserPrompt = req.Contents[0].Parts[0].Text
		}
		if req.SystemInstruction != nil && len(req.SystemInstruction.Parts) > 0 {
			capturedSysPrompt = req.SystemInstruction.Parts[0].Text
		}

		resp := map[string]interface{}{
			"candidates": []map[string]interface{}{
				{
					"content": map[string]interface{}{
						"parts": []map[string]interface{}{
							{"text": dreamJSON},
						},
					},
					"finishReason": "STOP",
				},
			},
			"usageMetadata": map[string]interface{}{
				"promptTokenCount":     500,
				"candidatesTokenCount": 150,
				"totalTokenCount":      650,
			},
		}
		data, _ := json.Marshal(resp)
		header := make(http.Header)
		header.Set("Content-Type", "application/json")
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     header,
			Body:       io.NopCloser(bytes.NewReader(data)),
		}, nil
	}))
	orch := NewOrchestrator(store, gemini, nil)

	report, err := orch.ConsolidateMemory(ctx, "chan-product-launch")
	if err != nil {
		t.Fatalf("ConsolidateMemory failed: %v", err)
	}

	// 1. Verify DreamPromptUsed contains REM prompt template instructions and schema
	if !strings.Contains(report.DreamPromptUsed, "### REM DREAM SYNTHESIS PROMPT ###") {
		t.Errorf("expected REM dream prompt template marker in DreamPromptUsed, got: %s", report.DreamPromptUsed)
	}
	if !strings.Contains(capturedUserPrompt, "### REM DREAM SYNTHESIS PROMPT ###") {
		t.Errorf("expected captured prompt to contain REM template marker, got: %s", capturedUserPrompt)
	}
	if !strings.Contains(capturedSysPrompt, "crystallized_beliefs") {
		t.Errorf("expected sysPrompt to specify crystallized_beliefs schema")
	}

	// 2. Verify parsed fields
	if report.InsightSummary != "Swarm standardized on Cloud Run, Terraform, and Cloud Spanner with dual-layer memory." {
		t.Errorf("unexpected InsightSummary: %s", report.InsightSummary)
	}
	if report.IntentTrajectory != "Exploration -> Hardening -> GA Sign-off" {
		t.Errorf("unexpected IntentTrajectory: %s", report.IntentTrajectory)
	}
	if len(report.DistilledFacts) != 2 {
		t.Errorf("expected 2 DistilledFacts, got %d", len(report.DistilledFacts))
	}
	if len(report.CrystallizedBeliefs) != 2 {
		t.Fatalf("expected 2 CrystallizedBeliefs, got %d", len(report.CrystallizedBeliefs))
	}
	if report.CrystallizedBeliefs[0].Key != "cloud_run_prod_target" {
		t.Errorf("expected first belief key 'cloud_run_prod_target', got %s", report.CrystallizedBeliefs[0].Key)
	}

	// 3. Verify beliefs are saved to store and searchable
	hits, err := store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "cloud_run_prod_target")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected to find saved crystallized belief 'cloud_run_prod_target', got %v (err: %v)", hits, err)
	}
	if hits[0].Key != "cloud_run_prod_target" {
		t.Errorf("expected top hit 'cloud_run_prod_target', got %s", hits[0].Key)
	}
	if hits[0].Category != "Infrastructure" {
		t.Errorf("expected category 'Infrastructure', got %s", hits[0].Category)
	}
}

func TestConsolidateMemory_Deduplication(t *testing.T) {
	ctx := context.Background()
	store := storage.NewInMemStore()
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	// JSON response where Gemini outputs duplicate crystallized beliefs (same key, different casing, or multiple copies)
	duplicateDreamJSON := `{
  "summary": "Swarm standardized on Cloud Spanner and Cloud Run.",
  "intent_trajectory": "Design -> Implementation",
  "distilled_facts": [
    "Spanner is used for persistence.",
    "Spanner is used for persistence."
  ],
  "crystallized_beliefs": [
    {
      "key": "cloud_run_prod_target",
      "value": "Cloud Run container target in davenport-boutique",
      "category": "Infrastructure",
      "confidence": 0.95,
      "keywords": "cloud run, container",
      "statement": "Initial statement."
    },
    {
      "key": "CLOUD_RUN_PROD_TARGET",
      "value": "Cloud Run container target in davenport-boutique (updated)",
      "category": "Infrastructure",
      "confidence": 0.99,
      "keywords": "cloud run, container, production",
      "statement": "Updated statement."
    },
    {
      "key": "spanner_vector_search",
      "value": "Cloud Spanner vector search with exact cosine distance",
      "category": "Database",
      "confidence": 0.98,
      "keywords": "spanner, vector, cosine",
      "statement": "Spanner handles vector indexing."
    },
    {
      "key": "spanner_vector_search",
      "value": "Cloud Spanner vector search with exact cosine distance (repeat)",
      "category": "Database",
      "confidence": 0.98,
      "keywords": "spanner, vector, cosine",
      "statement": "Spanner handles vector indexing."
    }
  ]
}`

	os.Setenv("GCP_ACCESS_TOKEN", "test-token-dream-dedup")
	defer os.Unsetenv("GCP_ACCESS_TOKEN")

	cfg := GeminiConfig{
		ProjectID: "davenport-boutique",
		Location:  "us-central1",
		Model:     "gemini-3.8-flash",
	}
	gemini := NewGeminiClient(cfg)
	gemini.SetTransport(roundTripFunc(func(r *http.Request) (*http.Response, error) {
		resp := map[string]interface{}{
			"candidates": []map[string]interface{}{
				{
					"content": map[string]interface{}{
						"parts": []map[string]interface{}{
							{"text": duplicateDreamJSON},
						},
					},
					"finishReason": "STOP",
				},
			},
			"usageMetadata": map[string]interface{}{
				"promptTokenCount":     500,
				"candidatesTokenCount": 150,
				"totalTokenCount":      650,
			},
		}
		data, _ := json.Marshal(resp)
		header := make(http.Header)
		header.Set("Content-Type", "application/json")
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     header,
			Body:       io.NopCloser(bytes.NewReader(data)),
		}, nil
	}))
	orch := NewOrchestrator(store, gemini, nil)

	// Cycle 1: ConsolidateMemory with duplicate beliefs from Gemini
	report1, err := orch.ConsolidateMemory(ctx, "chan-product-launch")
	if err != nil {
		t.Fatalf("ConsolidateMemory cycle 1 failed: %v", err)
	}

	// 1. Verify report has deduplicated beliefs
	if len(report1.CrystallizedBeliefs) != 2 {
		t.Fatalf("expected 2 deduplicated beliefs in report, got %d: %+v", len(report1.CrystallizedBeliefs), report1.CrystallizedBeliefs)
	}

	// 2. Verify SearchCrystallizedBeliefs returns top hit and zero duplicates for a specific query
	hits, err := store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "cloud_run_prod_target")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected hits for 'cloud_run_prod_target', got %v (err: %v)", hits, err)
	}
	if !strings.EqualFold(hits[0].Key, "cloud_run_prod_target") {
		t.Errorf("expected top hit 'cloud_run_prod_target', got %s", hits[0].Key)
	}
	queryKeys := make(map[string]int)
	for _, h := range hits {
		k := strings.ToLower(h.Key)
		queryKeys[k]++
		if queryKeys[k] > 1 {
			t.Errorf("duplicate key %s found in search results", k)
		}
	}

	// 3. Cycle 2: Call ConsolidateMemory again (simulating repeated dreaming cycles)
	report2, err := orch.ConsolidateMemory(ctx, "chan-product-launch")
	if err != nil {
		t.Fatalf("ConsolidateMemory cycle 2 failed: %v", err)
	}
	if len(report2.CrystallizedBeliefs) != 2 {
		t.Fatalf("expected 2 deduplicated beliefs in report 2, got %d", len(report2.CrystallizedBeliefs))
	}

	// 4. Verify searching across all beliefs in the channel produces zero duplicates
	allHits, err := store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "")
	if err != nil {
		t.Fatalf("SearchCrystallizedBeliefs empty query failed: %v", err)
	}

	keyCounts := make(map[string]int)
	for _, b := range allHits {
		normKey := strings.ToLower(b.Key)
		keyCounts[normKey]++
	}

	for k, count := range keyCounts {
		if count > 1 {
			t.Errorf("found duplicate belief key %q with count %d after repeated ConsolidateMemory cycles", k, count)
		}
	}

	if keyCounts["cloud_run_prod_target"] != 1 {
		t.Errorf("expected cloud_run_prod_target count 1, got %d", keyCounts["cloud_run_prod_target"])
	}
	if keyCounts["spanner_vector_search"] != 1 {
		t.Errorf("expected spanner_vector_search count 1, got %d", keyCounts["spanner_vector_search"])
	}
}

