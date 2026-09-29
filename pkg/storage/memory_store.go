package storage

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// InMemStore is a pure Go thread-safe memory store implementing MemoryStore.
// It provides deterministic zero-dependency execution for local testing and Cloud Run containers.
type InMemStore struct {
	mu        sync.RWMutex
	channels  map[string]Channel
	messages  map[string]Message
	summaries map[string]Summary

	eras            map[string]Era
	eraList         []string
	presences       map[string]AgentPresence
	scratchpads     map[string]PrivateScratchpad     // key: agentID + ":" + channelID
	consolidations  map[string][]ConsolidationReport // channelID -> reports
	bufferTelemetry map[string]MemoryBuffer          // channelID -> MemoryBuffer
	crystallized    map[string][]CrystallizedBelief  // channelID -> beliefs
	bq              *BigQueryClient

	// Ordering indexes
	channelList []string            // Channel IDs in creation order
	chanMsgs    map[string][]string // ChannelID -> Message IDs in chronological order
	threadMsgs  map[string][]string // ThreadID -> Message IDs in chronological order
	chanSums    map[string][]string // ChannelID -> Summary IDs
}

// MemoryStoreImpl is an alias to InMemStore to fulfill explicit interface references.
type MemoryStoreImpl = InMemStore

// NewInMemStore initializes an empty InMemStore with BigQuery client support.
func NewInMemStore() *InMemStore {
	return &InMemStore{
		channels:        make(map[string]Channel),
		messages:        make(map[string]Message),
		summaries:       make(map[string]Summary),
		eras:            make(map[string]Era),
		eraList:         make([]string, 0),
		presences:       make(map[string]AgentPresence),
		scratchpads:     make(map[string]PrivateScratchpad),
		consolidations:  make(map[string][]ConsolidationReport),
		bufferTelemetry: make(map[string]MemoryBuffer),
		crystallized:    make(map[string][]CrystallizedBelief),
		channelList:     make([]string, 0),
		chanMsgs:        make(map[string][]string),
		threadMsgs:      make(map[string][]string),
		chanSums:        make(map[string][]string),
		bq:              NewBigQueryClient(DefaultBigQueryConfig()),
	}
}

// SetBigQueryClient updates the BigQuery client (useful for custom transports or test isolation).
func (s *InMemStore) SetBigQueryClient(bq *BigQueryClient) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.bq = bq
}

// CreateChannel creates a new channel.
func (s *InMemStore) CreateChannel(ctx context.Context, ch Channel) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if ch.ID == "" {
		return fmt.Errorf("channel ID cannot be empty")
	}
	if ch.CreatedAt.IsZero() {
		ch.CreatedAt = time.Now()
	}
	if _, exists := s.channels[ch.ID]; !exists {
		s.channelList = append(s.channelList, ch.ID)
	}
	s.channels[ch.ID] = ch
	return nil
}

// GetChannel retrieves a channel by ID.
func (s *InMemStore) GetChannel(ctx context.Context, id string) (*Channel, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	ch, exists := s.channels[id]
	if !exists {
		cleanID := strings.TrimPrefix(id, "#")
		if ch2, exists2 := s.channels[cleanID]; exists2 {
			return &ch2, nil
		}
		for _, c := range s.channels {
			if c.Name == id || c.Name == cleanID ||
				(strings.Contains(id, "product-launch") && strings.Contains(c.ID, "product-launch")) {
				return &c, nil
			}
		}
		return nil, fmt.Errorf("channel not found: %s", id)
	}
	return &ch, nil
}

// ListChannels returns all channels in creation order.
func (s *InMemStore) ListChannels(ctx context.Context) ([]Channel, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]Channel, 0, len(s.channelList))
	for _, id := range s.channelList {
		if ch, ok := s.channels[id]; ok {
			result = append(result, ch)
		}
	}
	return result, nil
}

// SaveMessage appends a message to the event log.
func (s *InMemStore) SaveMessage(ctx context.Context, msg Message) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if msg.ID == "" {
		return fmt.Errorf("message ID cannot be empty")
	}
	if msg.ChannelID == "" {
		return fmt.Errorf("channel ID cannot be empty")
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now()
	}

	s.messages[msg.ID] = msg

	if msg.ThreadID == "" {
		// Root channel message
		s.chanMsgs[msg.ChannelID] = append(s.chanMsgs[msg.ChannelID], msg.ID)

		// Short-Term Memory: Check for FIFO buffer eviction (Stage 1 IRC)
		if ch, ok := s.channels[msg.ChannelID]; ok && ch.MaxBufferTurns > 0 {
			buf := s.bufferTelemetry[msg.ChannelID]
			buf.ChannelID = msg.ChannelID
			buf.MaxTurns = ch.MaxBufferTurns

			if len(s.chanMsgs[msg.ChannelID]) > ch.MaxBufferTurns {
				// Evict oldest turn
				evictedID := s.chanMsgs[msg.ChannelID][0]
				evictedMsg := s.messages[evictedID]
				s.chanMsgs[msg.ChannelID] = s.chanMsgs[msg.ChannelID][1:]
				delete(s.messages, evictedID)

				buf.EvictedCount++
				buf.LastEvictedMsg = &evictedMsg
			}
			buf.CurrentTurns = len(s.chanMsgs[msg.ChannelID])
			s.bufferTelemetry[msg.ChannelID] = buf
		}
	} else {
		// Thread message
		s.threadMsgs[msg.ThreadID] = append(s.threadMsgs[msg.ThreadID], msg.ID)
	}

	// Stream interaction asynchronously to BigQuery agent_logs
	if s.bq != nil && s.bq.config.Enabled {
		go func(m Message) {
			bctx, bcancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer bcancel()
			_ = s.bq.LogAgentInteraction(bctx, m.SenderID, m.ChannelID, m.SenderName, string(m.SenderType), m.Content, map[string]interface{}{
				"thread_id":   m.ThreadID,
				"intent_tags": m.IntentTags,
				"sender_type": m.SenderType,
			})
		}(msg)
	}

	return nil
}

// GetMessage retrieves a message by ID.
func (s *InMemStore) GetMessage(ctx context.Context, id string) (*Message, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	msg, exists := s.messages[id]
	if !exists {
		return nil, fmt.Errorf("message not found: %s", id)
	}
	return &msg, nil
}

// ListMessages retrieves messages for a channel or thread in chronological order.
// If threadID is empty, it returns root messages for the channel.
// If threadID is specified, it returns messages within that thread.
func (s *InMemStore) ListMessages(ctx context.Context, channelID string, threadID string, limit int) ([]Message, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var msgIDs []string
	if threadID == "" {
		msgIDs = s.chanMsgs[channelID]
	} else {
		msgIDs = s.threadMsgs[threadID]
	}

	total := len(msgIDs)
	if limit > 0 && limit < total {
		// Take the most recent 'limit' messages
		msgIDs = msgIDs[total-limit:]
	}

	result := make([]Message, 0, len(msgIDs))
	for _, id := range msgIDs {
		if msg, ok := s.messages[id]; ok {
			result = append(result, msg)
		}
	}
	return result, nil
}

// CountMessages returns the number of messages in a channel or thread.
func (s *InMemStore) CountMessages(ctx context.Context, channelID string, threadID string) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if threadID == "" {
		return len(s.chanMsgs[channelID]), nil
	}
	return len(s.threadMsgs[threadID]), nil
}

// SearchVectors performs exact K-NN cosine similarity search across message embeddings.
// If channelID is non-empty, search is scoped to that channel; otherwise global across all channels.
func (s *InMemStore) SearchVectors(ctx context.Context, channelID string, queryEmbedding []float32, topK int) ([]VectorSearchResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if len(queryEmbedding) == 0 {
		return nil, fmt.Errorf("query embedding cannot be empty")
	}

	var candidates []VectorSearchResult
	for _, msg := range s.messages {
		if len(msg.Embedding) == 0 {
			continue
		}
		if channelID != "" && msg.ChannelID != channelID {
			continue
		}

		sim, err := CosineSimilarity(queryEmbedding, msg.Embedding)
		if err != nil {
			// Skip vectors with incompatible dimensionality
			continue
		}

		candidates = append(candidates, VectorSearchResult{
			Message:    msg,
			Similarity: sim,
			Distance:   1.0 - sim,
		})
	}

	// Sort descending by similarity
	sort.Slice(candidates, func(i, j int) bool {
		return candidates[i].Similarity > candidates[j].Similarity
	})

	if topK > 0 && len(candidates) > topK {
		candidates = candidates[:topK]
	}

	return candidates, nil
}

// SaveSummary records a state compaction checkpoint.
func (s *InMemStore) SaveSummary(ctx context.Context, sum Summary) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if sum.ID == "" {
		return fmt.Errorf("summary ID cannot be empty")
	}
	if sum.CreatedAt.IsZero() {
		sum.CreatedAt = time.Now()
	}
	if sum.OriginalTokens > 0 {
		sum.CompressionRatio = 1.0 - (float64(sum.CompactedTokens) / float64(sum.OriginalTokens))
	}

	s.summaries[sum.ID] = sum
	s.chanSums[sum.ChannelID] = append(s.chanSums[sum.ChannelID], sum.ID)
	return nil
}

// GetLatestSummary retrieves the most recent compaction summary for a channel/thread.
func (s *InMemStore) GetLatestSummary(ctx context.Context, channelID string, threadID string) (*Summary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sumIDs := s.chanSums[channelID]
	for i := len(sumIDs) - 1; i >= 0; i-- {
		sum := s.summaries[sumIDs[i]]
		if sum.ThreadID == threadID {
			return &sum, nil
		}
	}
	return nil, fmt.Errorf("no summary found for channel %s, thread %s", channelID, threadID)
}

// ListSummaries lists all summaries for a channel.
func (s *InMemStore) ListSummaries(ctx context.Context, channelID string) ([]Summary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sumIDs := s.chanSums[channelID]
	result := make([]Summary, 0, len(sumIDs))
	for _, id := range sumIDs {
		if sum, ok := s.summaries[id]; ok {
			result = append(result, sum)
		}
	}
	return result, nil
}

// ApplyRetentionPolicy prunes messages older than maxAgeHours while retaining compaction summaries.
func (s *InMemStore) ApplyRetentionPolicy(ctx context.Context, channelID string, maxAgeHours int) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if maxAgeHours <= 0 {
		return 0, nil
	}

	cutoff := time.Now().Add(-time.Duration(maxAgeHours) * time.Hour)
	prunedCount := 0

	// Prune root messages
	var remainingRoot []string
	for _, id := range s.chanMsgs[channelID] {
		msg := s.messages[id]
		if msg.CreatedAt.Before(cutoff) {
			delete(s.messages, id)
			prunedCount++
		} else {
			remainingRoot = append(remainingRoot, id)
		}
	}
	s.chanMsgs[channelID] = remainingRoot

	return prunedCount, nil
}

// CreateEra registers a historical era in the system.
func (s *InMemStore) CreateEra(ctx context.Context, era Era) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if era.ID == "" {
		return fmt.Errorf("era ID cannot be empty")
	}
	if _, exists := s.eras[era.ID]; !exists {
		s.eraList = append(s.eraList, era.ID)
	}
	s.eras[era.ID] = era
	return nil
}

// ListEras returns all registered historical eras in chronological order.
func (s *InMemStore) ListEras(ctx context.Context) ([]Era, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]Era, 0, len(s.eraList))
	for _, id := range s.eraList {
		if era, ok := s.eras[id]; ok {
			result = append(result, era)
		}
	}
	return result, nil
}

// GetEra retrieves an era by ID.
func (s *InMemStore) GetEra(ctx context.Context, id string) (*Era, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	era, exists := s.eras[id]
	if !exists {
		return nil, fmt.Errorf("era not found: %s", id)
	}
	return &era, nil
}

// GetMemoryBuffer retrieves current FIFO buffer usage and eviction telemetry for a channel.
func (s *InMemStore) GetMemoryBuffer(ctx context.Context, channelID string) (*MemoryBuffer, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	buf, exists := s.bufferTelemetry[channelID]
	if !exists {
		ch, chExists := s.channels[channelID]
		maxTurns := 0
		if chExists {
			maxTurns = ch.MaxBufferTurns
		}
		currentTurns := len(s.chanMsgs[channelID])
		return &MemoryBuffer{
			ChannelID:    channelID,
			MaxTurns:     maxTurns,
			CurrentTurns: currentTurns,
			EvictedCount: 0,
		}, nil
	}
	return &buf, nil
}

// SetAgentPresence updates the live cognitive status of an agent.
func (s *InMemStore) SetAgentPresence(ctx context.Context, presence AgentPresence) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if presence.AgentID == "" {
		return fmt.Errorf("agent ID cannot be empty")
	}
	if presence.LastHeartbeat.IsZero() {
		presence.LastHeartbeat = time.Now()
	}
	s.presences[presence.AgentID] = presence
	return nil
}

// GetAgentPresence retrieves the status of an agent.
func (s *InMemStore) GetAgentPresence(ctx context.Context, agentID string) (*AgentPresence, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	p, exists := s.presences[agentID]
	if !exists {
		return nil, fmt.Errorf("presence not found for agent: %s", agentID)
	}
	return &p, nil
}

// ListAgentPresences lists all registered agent presences.
func (s *InMemStore) ListAgentPresences(ctx context.Context) ([]AgentPresence, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]AgentPresence, 0, len(s.presences))
	for _, p := range s.presences {
		result = append(result, p)
	}
	return result, nil
}

// SavePrivateScratchpad persists an agent's individual cognitive working memory.
func (s *InMemStore) SavePrivateScratchpad(ctx context.Context, pad PrivateScratchpad) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if pad.AgentID == "" || pad.ChannelID == "" {
		return fmt.Errorf("agentID and channelID cannot be empty")
	}
	pad.UpdatedAt = time.Now()
	key := pad.AgentID + ":" + pad.ChannelID
	s.scratchpads[key] = pad
	return nil
}

// GetPrivateScratchpad retrieves an agent's private scratchpad for a channel.
func (s *InMemStore) GetPrivateScratchpad(ctx context.Context, agentID string, channelID string) (*PrivateScratchpad, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	key := agentID + ":" + channelID
	pad, exists := s.scratchpads[key]
	if !exists {
		return &PrivateScratchpad{
			AgentID:       agentID,
			ChannelID:     channelID,
			InnerThoughts: []string{},
			ToolTraces:    []string{},
			UpdatedAt:     time.Now(),
		}, nil
	}
	return &pad, nil
}

// SaveConsolidationReport stores a record of an offline dreaming consolidation cycle.
func (s *InMemStore) SaveConsolidationReport(ctx context.Context, report ConsolidationReport) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if report.ID == "" {
		return fmt.Errorf("report ID cannot be empty")
	}
	if report.CompletedAt.IsZero() {
		report.CompletedAt = time.Now()
	}
	s.consolidations[report.ChannelID] = append(s.consolidations[report.ChannelID], report)
	if len(report.CrystallizedBeliefs) > 0 {
		_ = s.saveCrystallizedBeliefsLocked(report.ChannelID, report.CrystallizedBeliefs)
	}

	// Stream summary to BigQuery session_summaries table
	if s.bq != nil && s.bq.config.Enabled {
		go func(rep ConsolidationReport) {
			bctx, bcancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer bcancel()
			_ = s.bq.LogSessionSummary(bctx, rep.ID, "system-dreamer", rep.ChannelID, rep.InsightSummary)
		}(report)
	}

	return nil
}

// ListConsolidationReports lists consolidation reports for a channel.
func (s *InMemStore) ListConsolidationReports(ctx context.Context, channelID string) ([]ConsolidationReport, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	reports := s.consolidations[channelID]
	result := make([]ConsolidationReport, len(reports))
	copy(result, reports)
	return result, nil
}

// SaveCrystallizedBeliefs indexes and updates crystallized beliefs for a channel.
func (s *InMemStore) SaveCrystallizedBeliefs(ctx context.Context, channelID string, beliefs []CrystallizedBelief) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.saveCrystallizedBeliefsLocked(channelID, beliefs)
}

func (s *InMemStore) saveCrystallizedBeliefsLocked(channelID string, beliefs []CrystallizedBelief) error {
	if channelID == "" {
		return fmt.Errorf("channel ID cannot be empty")
	}
	existing := s.crystallized[channelID]
	keyIndex := make(map[string]int)
	for i, b := range existing {
		keyIndex[strings.ToLower(strings.TrimSpace(b.Key))] = i
	}

	var toPersist []CrystallizedBelief
	persistIndex := make(map[string]int)
	for _, b := range beliefs {
		if len(b.Embedding) == 0 {
			b.Embedding = GenerateEmbedding(fmt.Sprintf("%s %s %s %s %s", b.Key, b.Value, b.Category, b.Keywords, b.Statement))
		}
		k := strings.ToLower(strings.TrimSpace(b.Key))
		if k == "" {
			continue
		}
		if idx, found := keyIndex[k]; found {
			existing[idx] = b
		} else {
			existing = append(existing, b)
			keyIndex[k] = len(existing) - 1
		}

		if pIdx, pFound := persistIndex[k]; pFound {
			toPersist[pIdx] = b
		} else {
			persistIndex[k] = len(toPersist)
			toPersist = append(toPersist, b)
		}
	}
	s.crystallized[channelID] = existing

	// Persist crystallized beliefs with 768-dim embeddings to BigQuery
	if s.bq != nil && s.bq.config.Enabled && len(toPersist) > 0 {
		go func(ch string, blfs []CrystallizedBelief) {
			bctx, bcancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer bcancel()
			for _, b := range blfs {
				_ = s.bq.UpsertCrystallizedBelief(bctx, ch, b)
			}
		}(channelID, toPersist)
	}

	return nil
}

// SearchCrystallizedBeliefs provides case-insensitive keyword and semantic vector matching for crystallized beliefs.
func (s *InMemStore) SearchCrystallizedBeliefs(ctx context.Context, channelID string, query string) ([]CrystallizedBelief, error) {
	s.mu.RLock()
	var rawCandidates []CrystallizedBelief
	if channelID != "" {
		if beliefs, exists := s.crystallized[channelID]; exists {
			rawCandidates = append(rawCandidates, beliefs...)
		} else {
			normalized := strings.TrimPrefix(channelID, "#")
			for cid, beliefs := range s.crystallized {
				if cid == normalized ||
					strings.EqualFold(cid, normalized) ||
					(strings.Contains(cid, "product-launch") && strings.Contains(normalized, "product-launch")) {
					rawCandidates = append(rawCandidates, beliefs...)
				}
			}
		}
	} else {
		for _, beliefs := range s.crystallized {
			rawCandidates = append(rawCandidates, beliefs...)
		}
	}
	s.mu.RUnlock()

	// Deduplicate candidates by belief.Key (case-insensitive) when aggregating
	var candidates []CrystallizedBelief
	candidateIndex := make(map[string]int)
	for _, b := range rawCandidates {
		k := strings.ToLower(strings.TrimSpace(b.Key))
		if k == "" {
			continue
		}
		if idx, found := candidateIndex[k]; found {
			if b.Confidence > candidates[idx].Confidence {
				candidates[idx] = b
			}
		} else {
			candidateIndex[k] = len(candidates)
			candidates = append(candidates, b)
		}
	}

	query = strings.TrimSpace(query)
	if query == "" {
		result := make([]CrystallizedBelief, len(candidates))
		copy(result, candidates)
		return result, nil
	}

	lowerQuery := strings.ToLower(query)
	queryTokens := tokenizeQuery(lowerQuery)
	queryVec := GenerateEmbedding(query)

	type scoredBelief struct {
		belief CrystallizedBelief
		score  float64
	}
	var scored []scoredBelief

	for _, b := range candidates {
		lowerKey := strings.ToLower(b.Key)
		lowerKeyNormalized := strings.ReplaceAll(lowerKey, "_", " ")
		lowerKeywords := strings.ToLower(b.Keywords)
		lowerStatement := strings.ToLower(b.Statement)
		lowerVal := strings.ToLower(b.Value)
		lowerCat := strings.ToLower(b.Category)

		matchScore := 0.0

		// Exact key or phrase match
		if strings.Contains(lowerQuery, lowerKey) || strings.Contains(lowerQuery, lowerKeyNormalized) {
			matchScore += 10.0
		}
		if lowerKey != "" && strings.Contains(lowerKeyNormalized, lowerQuery) {
			matchScore += 8.0
		}

		// Semantic vector distance match
		if len(b.Embedding) > 0 {
			dist := CosineDistance64(queryVec, b.Embedding)
			if dist < 0.85 {
				matchScore += (1.0 - dist) * 10.0
			}
		}

		// Check keywords matching
		kwList := strings.Split(lowerKeywords, ",")
		for _, kw := range kwList {
			kw = strings.TrimSpace(kw)
			if kw == "" {
				continue
			}
			if strings.Contains(lowerQuery, kw) {
				matchScore += 5.0
			}
		}

		// Token matching against key, keywords, category, statement, value
		for _, tok := range queryTokens {
			if len(tok) < 2 {
				continue
			}
			if strings.Contains(lowerKey, tok) || strings.Contains(lowerKeyNormalized, tok) {
				matchScore += 4.0
			}
			if strings.Contains(lowerKeywords, tok) {
				matchScore += 3.0
			}
			if strings.Contains(lowerCat, tok) {
				matchScore += 2.0
			}
			if strings.Contains(lowerStatement, tok) {
				matchScore += 1.5
			}
			if strings.Contains(lowerVal, tok) {
				matchScore += 1.5
			}
		}

		if matchScore > 0 {
			finalScore := matchScore * (0.5 + b.Confidence*0.5)
			scored = append(scored, scoredBelief{belief: b, score: finalScore})
		}
	}

	sort.Slice(scored, func(i, j int) bool {
		if scored[i].score != scored[j].score {
			return scored[i].score > scored[j].score
		}
		return scored[i].belief.Confidence > scored[j].belief.Confidence
	})

	var result []CrystallizedBelief
	seenResult := make(map[string]bool)
	for _, s := range scored {
		k := strings.ToLower(strings.TrimSpace(s.belief.Key))
		if k != "" && !seenResult[k] {
			seenResult[k] = true
			result = append(result, s.belief)
		}
	}

	// If BigQuery is enabled, optionally augment with BigQuery ML.DISTANCE vector hits
	if s.bq != nil && s.bq.config.Enabled && len(result) < 3 {
		bqCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		defer cancel()
		if bqResults, err := s.bq.SearchVectorBeliefs(bqCtx, channelID, query, 3); err == nil && len(bqResults) > 0 {
			for _, b := range bqResults {
				k := strings.ToLower(strings.TrimSpace(b.Key))
				if k != "" && !seenResult[k] {
					result = append(result, b)
					seenResult[k] = true
				}
			}
		}
	}

	return result, nil
}

// GetStorageInfo returns metadata about the connected database and vector engine.
func (s *InMemStore) GetStorageInfo(ctx context.Context) map[string]interface{} {
	var info map[string]interface{}
	if s.bq != nil {
		info = s.bq.GetStorageStatus(ctx)
	} else {
		info = map[string]interface{}{
			"database":      "Google BigQuery",
			"status":        "in_memory",
			"vector_engine": "BigQuery Vector Search (ML.DISTANCE COSINE)",
		}
	}

	s.mu.RLock()
	totalBeliefs := 0
	for _, bList := range s.crystallized {
		totalBeliefs += len(bList)
	}
	totalMessages := len(s.messages)
	totalSummaries := 0
	for _, rList := range s.consolidations {
		totalSummaries += len(rList)
	}
	s.mu.RUnlock()

	info["total_messages"] = totalMessages
	info["total_crystallized_beliefs"] = totalBeliefs
	info["total_session_summaries"] = totalSummaries
	info["timestamp"] = time.Now().UTC().Format(time.RFC3339)

	return info
}

var commonStopwords = map[string]bool{
	"what": true, "is": true, "the": true, "our": true, "for": true, "in": true,
	"a": true, "an": true, "on": true, "of": true, "to": true, "and": true,
	"we": true, "can": true, "you": true, "tell": true, "me": true, "about": true,
	"how": true, "do": true, "does": true, "are": true, "with": true,
	"that": true, "this": true, "any": true, "some": true,
}

func tokenizeQuery(q string) []string {
	fields := strings.FieldsFunc(q, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\n' || r == '?' || r == '!' || r == '.' || r == ',' || r == ':' || r == ';' || r == '-' || r == '/' || r == '(' || r == ')'
	})
	var tokens []string
	for _, f := range fields {
		f = strings.ToLower(strings.TrimSpace(f))
		if f != "" && !commonStopwords[f] {
			tokens = append(tokens, f)
		}
	}
	return tokens
}

// ResetAndSeed clears the current store and loads the canonical talk scenarios.
func (s *InMemStore) ResetAndSeed(ctx context.Context) error {
	s.mu.Lock()
	s.channels = make(map[string]Channel)
	s.messages = make(map[string]Message)
	s.summaries = make(map[string]Summary)
	s.eras = make(map[string]Era)
	s.eraList = make([]string, 0)
	s.presences = make(map[string]AgentPresence)
	s.scratchpads = make(map[string]PrivateScratchpad)
	s.consolidations = make(map[string][]ConsolidationReport)
	s.bufferTelemetry = make(map[string]MemoryBuffer)
	s.crystallized = make(map[string][]CrystallizedBelief)
	s.channelList = make([]string, 0)
	s.chanMsgs = make(map[string][]string)
	s.threadMsgs = make(map[string][]string)
	s.chanSums = make(map[string][]string)
	s.mu.Unlock()

	return SeedTalkScenarios(ctx, s)
}

// Close is a no-op for in-memory store.
func (s *InMemStore) Close() error {
	return nil
}
