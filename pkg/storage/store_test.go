package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"testing"
	"time"
)

func TestMathVectorCalculations(t *testing.T) {
	v1 := []float32{1.0, 0.0, 0.0}
	v2 := []float32{1.0, 0.0, 0.0}
	v3 := []float32{0.0, 1.0, 0.0}
	v4 := []float32{-1.0, 0.0, 0.0}

	simIdentical, err := CosineSimilarity(v1, v2)
	if err != nil || math.Abs(float64(simIdentical-1.0)) > 1e-5 {
		t.Fatalf("expected identical similarity ~1.0, got %f (err: %v)", simIdentical, err)
	}

	simOrthogonal, err := CosineSimilarity(v1, v3)
	if err != nil || math.Abs(float64(simOrthogonal-0.0)) > 1e-5 {
		t.Fatalf("expected orthogonal similarity ~0.0, got %f (err: %v)", simOrthogonal, err)
	}

	simOpposite, err := CosineSimilarity(v1, v4)
	if err != nil || math.Abs(float64(simOpposite-(-1.0))) > 1e-5 {
		t.Fatalf("expected opposite similarity ~-1.0, got %f (err: %v)", simOpposite, err)
	}
}

func TestMemoryStoreThreadIsolation(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	ch := Channel{
		ID:        "chan-test",
		Name:      "test-channel",
		CreatedAt: time.Now(),
	}
	if err := store.CreateChannel(ctx, ch); err != nil {
		t.Fatalf("failed to create channel: %v", err)
	}

	// 2 root messages
	m1 := Message{
		ID:        "m1",
		ChannelID: ch.ID,
		Content:   "Root message 1",
		CreatedAt: time.Now(),
	}
	m2 := Message{
		ID:        "m2",
		ChannelID: ch.ID,
		Content:   "Root message 2",
		CreatedAt: time.Now().Add(1 * time.Second),
	}
	// 2 thread messages in "thread-xyz"
	m3 := Message{
		ID:        "m3",
		ChannelID: ch.ID,
		ThreadID:  "thread-xyz",
		Content:   "Thread branch message 1",
		CreatedAt: time.Now().Add(2 * time.Second),
	}
	m4 := Message{
		ID:        "m4",
		ChannelID: ch.ID,
		ThreadID:  "thread-xyz",
		Content:   "Thread branch message 2",
		CreatedAt: time.Now().Add(3 * time.Second),
	}

	for _, m := range []Message{m1, m2, m3, m4} {
		if err := store.SaveMessage(ctx, m); err != nil {
			t.Fatalf("failed to save message %s: %v", m.ID, err)
		}
	}

	// Verify root messages do NOT contain thread messages (scratchpad isolation)
	rootMsgs, err := store.ListMessages(ctx, ch.ID, "", 10)
	if err != nil {
		t.Fatalf("failed to list root messages: %v", err)
	}
	if len(rootMsgs) != 2 {
		t.Fatalf("expected 2 root messages, got %d", len(rootMsgs))
	}
	if rootMsgs[0].ID != "m1" || rootMsgs[1].ID != "m2" {
		t.Fatalf("unexpected root message IDs: %v", rootMsgs)
	}

	// Verify thread messages
	thMsgs, err := store.ListMessages(ctx, ch.ID, "thread-xyz", 10)
	if err != nil {
		t.Fatalf("failed to list thread messages: %v", err)
	}
	if len(thMsgs) != 2 {
		t.Fatalf("expected 2 thread messages, got %d", len(thMsgs))
	}
	if thMsgs[0].ID != "m3" || thMsgs[1].ID != "m4" {
		t.Fatalf("unexpected thread message IDs: %v", thMsgs)
	}
}

func TestVectorSearch(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	ch := Channel{ID: "chan-vectors", Name: "vectors", CreatedAt: time.Now()}
	_ = store.CreateChannel(ctx, ch)

	// Save messages with distinct embeddings
	mAuth := Message{
		ID:        "msg-auth",
		ChannelID: ch.ID,
		Content:   "Auth token failure and connection timeout",
		Embedding: []float32{0.9, 0.8, 0.1, 0.1},
		CreatedAt: time.Now(),
	}
	mUI := Message{
		ID:        "msg-ui",
		ChannelID: ch.ID,
		Content:   "Flutter web sepia theme styling",
		Embedding: []float32{0.1, 0.1, 0.9, 0.8},
		CreatedAt: time.Now(),
	}

	_ = store.SaveMessage(ctx, mAuth)
	_ = store.SaveMessage(ctx, mUI)

	// Search with query vector close to auth
	queryVector := []float32{0.85, 0.75, 0.15, 0.1}
	results, err := store.SearchVectors(ctx, ch.ID, queryVector, 5)
	if err != nil {
		t.Fatalf("vector search failed: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 search results, got %d", len(results))
	}

	// Top result should be msg-auth with high similarity
	top := results[0]
	if top.Message.ID != "msg-auth" {
		t.Fatalf("expected top result msg-auth, got %s", top.Message.ID)
	}
	if top.Similarity < 0.95 {
		t.Fatalf("expected similarity > 0.95, got %f", top.Similarity)
	}
}

func TestCompactionAndRetention(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	ch := Channel{ID: "chan-retention", Name: "retention", CreatedAt: time.Now()}
	_ = store.CreateChannel(ctx, ch)

	// Create an old message and a recent message
	oldMsg := Message{
		ID:        "msg-old",
		ChannelID: ch.ID,
		Content:   "Ancient history from 48 hours ago",
		CreatedAt: time.Now().Add(-48 * time.Hour),
	}
	newMsg := Message{
		ID:        "msg-new",
		ChannelID: ch.ID,
		Content:   "Fresh context from 10 minutes ago",
		CreatedAt: time.Now().Add(-10 * time.Minute),
	}
	_ = store.SaveMessage(ctx, oldMsg)
	_ = store.SaveMessage(ctx, newMsg)

	// Scribe creates compaction summary covering the old message
	sum := Summary{
		ID:                    "sum-01",
		ChannelID:             ch.ID,
		CoveredStartMessageID: "msg-old",
		CoveredEndMessageID:   "msg-old",
		CondensedState:        "Compacted summary of ancient history",
		OriginalTokens:        4000,
		CompactedTokens:       250,
		CreatedAt:             time.Now(),
	}
	if err := store.SaveSummary(ctx, sum); err != nil {
		t.Fatalf("failed to save summary: %v", err)
	}

	// Apply retention policy: prune messages older than 24 hours
	pruned, err := store.ApplyRetentionPolicy(ctx, ch.ID, 24)
	if err != nil {
		t.Fatalf("retention pruning failed: %v", err)
	}
	if pruned != 1 {
		t.Fatalf("expected 1 message pruned, got %d", pruned)
	}

	// Verify old message is evicted from active stream
	msgs, _ := store.ListMessages(ctx, ch.ID, "", 10)
	if len(msgs) != 1 || msgs[0].ID != "msg-new" {
		t.Fatalf("expected only msg-new to remain, got %v", msgs)
	}

	// Verify summary remains intact for long-term memory
	latestSum, err := store.GetLatestSummary(ctx, ch.ID, "")
	if err != nil || latestSum.ID != "sum-01" {
		t.Fatalf("summary should persist after message pruning: %v", err)
	}
}

func TestSeedDataIntegrity(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("seed failed: %v", err)
	}

	// Verify 10 channels across the 6 eras (including AIM buddies and Campfire multi-rooms)
	channels, err := store.ListChannels(ctx)
	if err != nil {
		t.Fatalf("failed to list channels: %v", err)
	}
	if len(channels) != 10 {
		t.Fatalf("expected 10 talk channels for the 6 eras, got %d", len(channels))
	}

	// Verify 6 registered eras
	eras, err := store.ListEras(ctx)
	if err != nil {
		t.Fatalf("failed to list eras: %v", err)
	}
	if len(eras) != 6 {
		t.Fatalf("expected 6 eras, got %d", len(eras))
	}

	// Verify incident channel has messages
	incMsgs, err := store.ListMessages(ctx, "chan-incident-postmortem", "", 50)
	if err != nil || len(incMsgs) == 0 {
		t.Fatalf("expected incident messages, got %v (err: %v)", len(incMsgs), err)
	}

	// Verify architecture RFC thread isolation and compaction
	sum, err := store.GetLatestSummary(ctx, "chan-architecture-rfc", "thread-rfc-042")
	if err != nil {
		t.Fatalf("expected RFC thread summary: %v", err)
	}
	if sum.CompressionRatio < 0.90 {
		t.Fatalf("expected >90%% compression ratio, got %f", sum.CompressionRatio)
	}

	rfcRoot, err := store.ListMessages(ctx, "chan-architecture-rfc", "", 50)
	if err != nil || len(rfcRoot) != 2 {
		t.Fatalf("expected 2 root RFC messages, got %d", len(rfcRoot))
	}

	rfcThread, err := store.ListMessages(ctx, "chan-architecture-rfc", "thread-rfc-042", 50)
	if err != nil || len(rfcThread) != 3 {
		t.Fatalf("expected 3 thread RFC messages, got %d", len(rfcThread))
	}

	// Verify AIM buddy 1:1 channels
	aimLeadMsgs, err := store.ListMessages(ctx, "chan-1997-aim", "", 10)
	if err != nil || len(aimLeadMsgs) != 2 {
		t.Fatalf("expected 2 AIM lead messages, got %d", len(aimLeadMsgs))
	}
	aimScribeMsgs, err := store.ListMessages(ctx, "chan-1997-aim-scribe", "", 10)
	if err != nil || len(aimScribeMsgs) != 2 {
		t.Fatalf("expected 2 AIM scribe messages, got %d", len(aimScribeMsgs))
	}
	aimResearcherMsgs, err := store.ListMessages(ctx, "chan-1997-aim-researcher", "", 10)
	if err != nil || len(aimResearcherMsgs) != 2 {
		t.Fatalf("expected 2 AIM researcher messages, got %d", len(aimResearcherMsgs))
	}

	// Verify Campfire multi-rooms
	campLobbyMsgs, err := store.ListMessages(ctx, "chan-2006-campfire-lobby", "", 10)
	if err != nil || len(campLobbyMsgs) != 2 {
		t.Fatalf("expected 2 Campfire lobby messages, got %d", len(campLobbyMsgs))
	}
	campEngMsgs, err := store.ListMessages(ctx, "chan-2006-campfire-eng", "", 10)
	if err != nil || len(campEngMsgs) != 2 {
		t.Fatalf("expected 2 Campfire eng messages, got %d", len(campEngMsgs))
	}
	campBilling, err := store.GetChannel(ctx, "chan-2006-campfire")
	if err != nil || len(campBilling.AllowedRoles) != 3 {
		t.Fatalf("expected Campfire billing room to have 3 allowed roles, got %v", campBilling)
	}

	// Verify AIM 1:1 Channel AllowedRoles strict boundaries
	aimLead, err := store.GetChannel(ctx, "chan-1997-aim")
	if err != nil || len(aimLead.AllowedRoles) != 1 || aimLead.AllowedRoles[0] != "lead-agent" {
		t.Fatalf("expected chan-1997-aim to allow only lead-agent, got %v", aimLead.AllowedRoles)
	}
	aimScribe, err := store.GetChannel(ctx, "chan-1997-aim-scribe")
	if err != nil || len(aimScribe.AllowedRoles) != 1 || aimScribe.AllowedRoles[0] != "scribe-agent" {
		t.Fatalf("expected chan-1997-aim-scribe to allow only scribe-agent, got %v", aimScribe.AllowedRoles)
	}
	aimResearcher, err := store.GetChannel(ctx, "chan-1997-aim-researcher")
	if err != nil || len(aimResearcher.AllowedRoles) != 1 || aimResearcher.AllowedRoles[0] != "researcher-agent" {
		t.Fatalf("expected chan-1997-aim-researcher to allow only researcher-agent, got %v", aimResearcher.AllowedRoles)
	}

	// Verify Campfire engineering role restrictions
	campEng, err := store.GetChannel(ctx, "chan-2006-campfire-eng")
	if err != nil || len(campEng.AllowedRoles) != 4 {
		t.Fatalf("expected Campfire engineering room to have 4 allowed roles, got %v", campEng.AllowedRoles)
	}
}

func TestFIFOBuffersAndEviction(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	ch := Channel{
		ID:             "chan-fifo-test",
		Name:           "fifo-test",
		MaxBufferTurns: 3, // Capacity of 3 turns
		CreatedAt:      time.Now(),
	}
	if err := store.CreateChannel(ctx, ch); err != nil {
		t.Fatalf("failed to create channel: %v", err)
	}

	// Insert 3 messages (fits in buffer)
	for i := 1; i <= 3; i++ {
		msg := Message{
			ID:        fmt.Sprintf("msg-%d", i),
			ChannelID: ch.ID,
			Content:   fmt.Sprintf("Turn %d", i),
			CreatedAt: time.Now().Add(time.Duration(i) * time.Second),
		}
		if err := store.SaveMessage(ctx, msg); err != nil {
			t.Fatalf("failed to save msg %d: %v", i, err)
		}
	}

	msgs, _ := store.ListMessages(ctx, ch.ID, "", 10)
	if len(msgs) != 3 {
		t.Fatalf("expected 3 messages, got %d", len(msgs))
	}

	buf, _ := store.GetMemoryBuffer(ctx, ch.ID)
	if buf.CurrentTurns != 3 || buf.EvictedCount != 0 {
		t.Fatalf("expected 3 turns and 0 evictions, got %d turns, %d evictions", buf.CurrentTurns, buf.EvictedCount)
	}

	// Insert 4th message -> should evict msg-1 (the Amnesia Trap)
	msg4 := Message{
		ID:        "msg-4",
		ChannelID: ch.ID,
		Content:   "Turn 4 (causes overflow)",
		CreatedAt: time.Now().Add(4 * time.Second),
	}
	if err := store.SaveMessage(ctx, msg4); err != nil {
		t.Fatalf("failed to save msg 4: %v", err)
	}

	msgs, _ = store.ListMessages(ctx, ch.ID, "", 10)
	if len(msgs) != 3 {
		t.Fatalf("expected buffer to cap at 3 messages, got %d", len(msgs))
	}
	if msgs[0].ID != "msg-2" || msgs[2].ID != "msg-4" {
		t.Fatalf("expected oldest msg-1 evicted, remaining: %v", msgs)
	}

	buf, _ = store.GetMemoryBuffer(ctx, ch.ID)
	if buf.EvictedCount != 1 || buf.LastEvictedMsg == nil || buf.LastEvictedMsg.ID != "msg-1" {
		t.Fatalf("expected eviction telemetry of msg-1, got %+v", buf)
	}
}

func TestAgentPresenceLifecycle(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	p := AgentPresence{
		AgentID:       "lead-agent",
		AgentName:     "Lead Coordinator",
		Status:        "available",
		StatusMessage: "Ready for tasks",
		LastHeartbeat: time.Now(),
	}
	if err := store.SetAgentPresence(ctx, p); err != nil {
		t.Fatalf("failed to set presence: %v", err)
	}

	retrieved, err := store.GetAgentPresence(ctx, "lead-agent")
	if err != nil || retrieved.Status != "available" {
		t.Fatalf("failed to get presence: %v", err)
	}

	// Update to typing
	p.Status = "typing"
	p.CurrentTask = "Synthesizing mitigation"
	_ = store.SetAgentPresence(ctx, p)

	retrieved, _ = store.GetAgentPresence(ctx, "lead-agent")
	if retrieved.Status != "typing" || retrieved.CurrentTask != "Synthesizing mitigation" {
		t.Fatalf("expected updated status typing, got %+v", retrieved)
	}

	list, _ := store.ListAgentPresences(ctx)
	if len(list) != 1 {
		t.Fatalf("expected 1 presence, got %d", len(list))
	}
}

func TestPrivateScratchpads(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	pad := PrivateScratchpad{
		AgentID:       "lead-agent",
		ChannelID:     "chan-launch",
		InnerThoughts: []string{"Thinking step 1", "Thinking step 2"},
		DraftPlan:     "Execute staging deploy",
		ToolTraces:    []string{"kubectl get pods -> OK"},
	}
	if err := store.SavePrivateScratchpad(ctx, pad); err != nil {
		t.Fatalf("failed to save scratchpad: %v", err)
	}

	retrieved, err := store.GetPrivateScratchpad(ctx, "lead-agent", "chan-launch")
	if err != nil {
		t.Fatalf("failed to get scratchpad: %v", err)
	}
	if len(retrieved.InnerThoughts) != 2 || retrieved.DraftPlan != "Execute staging deploy" {
		t.Fatalf("unexpected scratchpad contents: %+v", retrieved)
	}
}

func TestDreamingAndConsolidation(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	rep := ConsolidationReport{
		ID:             "report-01",
		ChannelID:      "chan-test",
		PrunedMessages: 8,
		DistilledFacts: []string{"Fact 1", "Fact 2"},
		InsightSummary: "Summary of consolidated insights",
		CompletedAt:    time.Now(),
	}
	if err := store.SaveConsolidationReport(ctx, rep); err != nil {
		t.Fatalf("failed to save consolidation report: %v", err)
	}

	reports, err := store.ListConsolidationReports(ctx, "chan-test")
	if err != nil || len(reports) != 1 {
		t.Fatalf("expected 1 report, got %d (err: %v)", len(reports), err)
	}
	if reports[0].PrunedMessages != 8 {
		t.Fatalf("expected 8 pruned messages, got %d", reports[0].PrunedMessages)
	}
}

func TestCrystallizedBeliefs(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	beliefs := []CrystallizedBelief{
		{
			Key:        "deployment_stack",
			Value:      "Cloud Run & Vertex AI Gemini 3.8 Flash in davenport-boutique",
			Category:   "Infrastructure",
			Confidence: 0.98,
			Keywords:   "deployment, stack, cloud run, vertex ai, gemini 3.8",
			Statement:  "The production deployment stack runs on Cloud Run with Vertex AI Gemini 3.8 Flash in project davenport-boutique.",
		},
		{
			Key:        "security_policies",
			Value:      "Application Default Credentials (ADC) with zero secrets in code",
			Category:   "Security",
			Confidence: 0.99,
			Keywords:   "security, policy, policies, adc, credentials, zero secrets, api keys, auth",
			Statement:  "Security policies strictly require Google Cloud Application Default Credentials (ADC) with zero hardcoded API keys or secrets.",
		},
		{
			Key:        "agreed_guidelines",
			Value:      "Dual-layer memory separating shared blackboard from private inner monologue",
			Category:   "Architecture",
			Confidence: 0.97,
			Keywords:   "guidelines, agreed, dual-layer, blackboard, scratchpad, inner monologue, isolation",
			Statement:  "Agreed guidelines mandate dual-layer memory with public blackboard posts segregated from private agent inner thoughts.",
		},
	}

	if err := store.SaveCrystallizedBeliefs(ctx, "chan-product-launch", beliefs); err != nil {
		t.Fatalf("failed to save crystallized beliefs: %v", err)
	}

	// 1. Exact Key Match
	hits, err := store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "deployment_stack")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected hits for deployment_stack, got %v (err: %v)", hits, err)
	}
	if hits[0].Key != "deployment_stack" {
		t.Fatalf("expected top hit deployment_stack, got %s", hits[0].Key)
	}

	// 2. Natural language query matching key & keywords
	hits, err = store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "What is our deployment stack?")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected hits for 'What is our deployment stack?', got %v (err: %v)", hits, err)
	}
	if hits[0].Key != "deployment_stack" {
		t.Fatalf("expected top hit deployment_stack, got %s", hits[0].Key)
	}

	// 3. Security policies query
	hits, err = store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "Tell me about security policies and ADC")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected hits for security policies query, got %v (err: %v)", hits, err)
	}
	if hits[0].Key != "security_policies" {
		t.Fatalf("expected top hit security_policies, got %s", hits[0].Key)
	}

	// 4. Agreed guidelines query
	hits, err = store.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "What are the agreed guidelines?")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected hits for agreed guidelines query, got %v (err: %v)", hits, err)
	}
	if hits[0].Key != "agreed_guidelines" {
		t.Fatalf("expected top hit agreed_guidelines, got %s", hits[0].Key)
	}

	// 5. Channel normalization: #product-launch-ga matches chan-product-launch
	hits, err = store.SearchCrystallizedBeliefs(ctx, "#product-launch-ga", "deployment")
	if err != nil || len(hits) == 0 {
		t.Fatalf("expected channel normalization to find hits for #product-launch-ga, got %v (err: %v)", hits, err)
	}
	if hits[0].Key != "deployment_stack" {
		t.Fatalf("expected deployment_stack hit for #product-launch-ga, got %s", hits[0].Key)
	}

	// 6. Test Seeded beliefs via ResetAndSeed
	storeSeeded := NewInMemStore()
	if err := storeSeeded.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to ResetAndSeed: %v", err)
	}

	seededHits, err := storeSeeded.SearchCrystallizedBeliefs(ctx, "chan-product-launch", "security policy")
	if err != nil || len(seededHits) == 0 {
		t.Fatalf("expected seeded hits for security policy, got %v (err: %v)", seededHits, err)
	}
	if seededHits[0].Key != "security_policies" {
		t.Fatalf("expected security_policies as top hit, got %s", seededHits[0].Key)
	}
}

func TestCrystallizedBeliefUnmarshalJSON(t *testing.T) {
	// Case 1: Keywords as comma-separated string
	jsonString := `{
		"key": "cloud_run_stack",
		"value": "Cloud Run with Vertex AI Gemini 3.8",
		"category": "Infrastructure",
		"confidence": 0.98,
		"keywords": "Cloud Run, Terraform, Gemini 3.8 Flash, orchestration, deployment",
		"statement": "Production stack runs on Cloud Run."
	}`
	var belief1 CrystallizedBelief
	if err := json.Unmarshal([]byte(jsonString), &belief1); err != nil {
		t.Fatalf("failed to unmarshal string keywords: %v", err)
	}
	if belief1.Keywords != "Cloud Run, Terraform, Gemini 3.8 Flash, orchestration, deployment" {
		t.Errorf("unexpected keywords: %s", belief1.Keywords)
	}

	// Case 2: Keywords as JSON array
	jsonArray := `{
		"key": "cloud_run_stack",
		"value": "Cloud Run with Vertex AI Gemini 3.8",
		"category": "Infrastructure",
		"confidence": 0.98,
		"keywords": ["Cloud Run", "Terraform", "Gemini 3.8 Flash", "orchestration", "deployment"],
		"statement": "Production stack runs on Cloud Run."
	}`
	var belief2 CrystallizedBelief
	if err := json.Unmarshal([]byte(jsonArray), &belief2); err != nil {
		t.Fatalf("failed to unmarshal array keywords: %v", err)
	}
	if belief2.Keywords != "Cloud Run, Terraform, Gemini 3.8 Flash, orchestration, deployment" {
		t.Errorf("unexpected keywords from array: %s", belief2.Keywords)
	}
}

func TestSearchCrystallizedBeliefs_Deduplication(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	// 1. Insert duplicate beliefs with differing case and confidence into the store
	b1 := CrystallizedBelief{
		Key:        "cloud_run_scaling",
		Value:      "Automatic autoscaling up to 1000 instances",
		Category:   "Infrastructure",
		Confidence: 0.90,
		Keywords:   "cloud run, autoscaling, serverless",
		Statement:  "Cloud Run automatically autoscales based on concurrency.",
	}
	b2 := CrystallizedBelief{
		Key:        "CLOUD_RUN_SCALING",
		Value:      "Automatic autoscaling up to 1000 instances with min instances",
		Category:   "Infrastructure",
		Confidence: 0.98,
		Keywords:   "cloud run, autoscaling, concurrency",
		Statement:  "Cloud Run automatically autoscales with min instances enabled.",
	}
	b3 := CrystallizedBelief{
		Key:        "spanner_leader",
		Value:      "Paxos leader election for multi-region consistency",
		Category:   "Database",
		Confidence: 0.95,
		Keywords:   "spanner, paxos, consensus",
		Statement:  "Cloud Spanner uses Paxos for replication consensus.",
	}

	if err := store.SaveCrystallizedBeliefs(ctx, "chan-arch-1", []CrystallizedBelief{b1, b2, b3}); err != nil {
		t.Fatalf("failed to save beliefs: %v", err)
	}

	// Also add across another channel to test multi-channel candidate aggregation deduplication
	b4 := CrystallizedBelief{
		Key:        "cloud_run_scaling",
		Value:      "Another channel version of cloud run scaling",
		Category:   "Infrastructure",
		Confidence: 0.85,
		Keywords:   "cloud run, autoscaling",
		Statement:  "Duplicate belief across channels.",
	}
	if err := store.SaveCrystallizedBeliefs(ctx, "chan-arch-2", []CrystallizedBelief{b4}); err != nil {
		t.Fatalf("failed to save beliefs in chan-arch-2: %v", err)
	}

	// Test 1: Query with specific search term
	hits, err := store.SearchCrystallizedBeliefs(ctx, "", "cloud run scaling")
	if err != nil || len(hits) == 0 {
		t.Fatalf("SearchCrystallizedBeliefs failed: %v", err)
	}
	if !strings.EqualFold(hits[0].Key, "cloud_run_scaling") {
		t.Errorf("expected top hit key cloud_run_scaling, got %s", hits[0].Key)
	}
	hitsSeen := make(map[string]int)
	for _, h := range hits {
		k := strings.ToLower(h.Key)
		hitsSeen[k]++
		if hitsSeen[k] > 1 {
			t.Errorf("found duplicate key %q in search results", k)
		}
	}

	// Test 2: Query with empty string across all channels
	allHits, err := store.SearchCrystallizedBeliefs(ctx, "", "")
	if err != nil {
		t.Fatalf("SearchCrystallizedBeliefs with empty query failed: %v", err)
	}

	seenKeys := make(map[string]int)
	for _, hit := range allHits {
		norm := strings.ToLower(hit.Key)
		seenKeys[norm]++
	}

	for k, count := range seenKeys {
		if count > 1 {
			t.Errorf("found duplicate key %q with count %d in SearchCrystallizedBeliefs results", k, count)
		}
	}

	if seenKeys["cloud_run_scaling"] != 1 {
		t.Errorf("expected cloud_run_scaling to appear exactly once, got %d", seenKeys["cloud_run_scaling"])
	}
	if seenKeys["spanner_leader"] != 1 {
		t.Errorf("expected spanner_leader to appear exactly once, got %d", seenKeys["spanner_leader"])
	}
}

func TestCrystallizedBelief_GeneratedAt(t *testing.T) {
	ctx := context.Background()
	store := NewInMemStore()

	// 1. Verify JSON Unmarshal with generated_at timestamp
	jsonWithTime := `{
		"key": "cloud_run_metrics",
		"value": "Sub-50ms p95 latency on Cloud Run",
		"category": "Performance",
		"confidence": 0.99,
		"keywords": "cloud run, metrics, latency",
		"statement": "Production metrics show sub-50ms p95 latency.",
		"generated_at": "2026-09-29T08:00:00Z"
	}`
	var belief CrystallizedBelief
	if err := json.Unmarshal([]byte(jsonWithTime), &belief); err != nil {
		t.Fatalf("failed to unmarshal belief with generated_at: %v", err)
	}
	expectedTime, _ := time.Parse(time.RFC3339, "2026-09-29T08:00:00Z")
	if !belief.GeneratedAt.Equal(expectedTime) {
		t.Fatalf("expected GeneratedAt %v, got %v", expectedTime, belief.GeneratedAt)
	}

	// 2. Verify Seeded ConsolidationReport has populated GeneratedAt for each CrystallizedBelief
	if err := store.ResetAndSeed(ctx); err != nil {
		t.Fatalf("failed to seed store: %v", err)
	}

	reports, err := store.ListConsolidationReports(ctx, "chan-product-launch")
	if err != nil || len(reports) == 0 {
		t.Fatalf("expected seeded consolidation reports, got %v (err: %v)", reports, err)
	}

	seededReport := reports[0]
	if len(seededReport.CrystallizedBeliefs) == 0 {
		t.Fatalf("expected crystallized beliefs in seeded report")
	}

	for _, b := range seededReport.CrystallizedBeliefs {
		if b.GeneratedAt.IsZero() {
			t.Errorf("expected seeded belief %s to have non-zero GeneratedAt, got zero", b.Key)
		}
		// Seeded time should be around 10 minutes ago
		diff := time.Since(b.GeneratedAt)
		if diff < 5*time.Minute || diff > 15*time.Minute {
			t.Errorf("expected seeded belief %s GeneratedAt ~10m ago, got diff %v", b.Key, diff)
		}
	}
}

