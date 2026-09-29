class ArchitecturePipelineStep {
  final int stepNumber;
  final String badgeLabel;
  final String flowTag;
  final String iconName;
  final String title;
  final String techStack;
  final List<String> metaBadges;
  final String description;
  final String sampleCode;
  final String codeLanguage;

  const ArchitecturePipelineStep({
    required this.stepNumber,
    required this.badgeLabel,
    required this.flowTag,
    required this.iconName,
    required this.title,
    required this.techStack,
    required this.metaBadges,
    required this.description,
    required this.sampleCode,
    required this.codeLanguage,
  });

  Map<String, dynamic> toJson() => {
    'step_number': stepNumber,
    'badge_label': badgeLabel,
    'flow_tag': flowTag,
    'icon_name': iconName,
    'title': title,
    'tech_stack': techStack,
    'meta_badges': metaBadges,
    'description': description,
    'sample_code': sampleCode,
    'code_language': codeLanguage,
  };

  factory ArchitecturePipelineStep.fromJson(Map<String, dynamic> json) {
    return ArchitecturePipelineStep(
      stepNumber: json['step_number'] ?? json['stepNumber'] ?? 1,
      badgeLabel: json['badge_label'] ?? json['badgeLabel'] ?? '',
      flowTag: json['flow_tag'] ?? json['flowTag'] ?? '',
      iconName: json['icon_name'] ?? json['iconName'] ?? 'memory',
      title: json['title'] ?? '',
      techStack: json['tech_stack'] ?? json['techStack'] ?? '',
      metaBadges: (json['meta_badges'] as List? ?? json['metaBadges'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      description: json['description'] ?? '',
      sampleCode: json['sample_code'] ?? json['sampleCode'] ?? '',
      codeLanguage: json['code_language'] ?? json['codeLanguage'] ?? 'go',
    );
  }
}

class EraArchitecture {
  final String eraId;
  final int year;
  final String title;
  final String cognitiveConcept;
  final String summary;
  final List<ArchitecturePipelineStep> steps;
  final String primaryCodeSnippet;
  final String primaryCodeLanguage;
  final String schemaSnippet;
  final String schemaLanguage;

  const EraArchitecture({
    required this.eraId,
    required this.year,
    required this.title,
    required this.cognitiveConcept,
    required this.summary,
    required this.steps,
    required this.primaryCodeSnippet,
    required this.primaryCodeLanguage,
    required this.schemaSnippet,
    required this.schemaLanguage,
  });

  Map<String, dynamic> toJson() => {
    'era_id': eraId,
    'year': year,
    'title': title,
    'cognitive_concept': cognitiveConcept,
    'summary': summary,
    'steps': steps.map((s) => s.toJson()).toList(),
    'primary_code_snippet': primaryCodeSnippet,
    'primary_code_language': primaryCodeLanguage,
    'schema_snippet': schemaSnippet,
    'schema_language': schemaLanguage,
  };

  factory EraArchitecture.fromJson(Map<String, dynamic> json) {
    return EraArchitecture(
      eraId: json['era_id'] ?? json['eraId'] ?? '',
      year: json['year'] ?? 1988,
      title: json['title'] ?? '',
      cognitiveConcept: json['cognitive_concept'] ?? json['cognitiveConcept'] ?? '',
      summary: json['summary'] ?? '',
      steps: (json['steps'] as List? ?? [])
          .map((s) => ArchitecturePipelineStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      primaryCodeSnippet: json['primary_code_snippet'] ?? json['primaryCodeSnippet'] ?? '',
      primaryCodeLanguage: json['primary_code_language'] ?? json['primaryCodeLanguage'] ?? 'go',
      schemaSnippet: json['schema_snippet'] ?? json['schemaSnippet'] ?? '',
      schemaLanguage: json['schema_language'] ?? json['schemaLanguage'] ?? 'sql',
    );
  }
}

class TelemetrySpan {
  final String id;
  final String eraId;
  final String channelId;
  final String? threadId;
  final String action;
  final int activeStep;
  final String title;
  final String description;
  final int latencyMs;
  final Map<String, dynamic> metrics;
  final String? payload;
  final DateTime timestamp;

  TelemetrySpan({
    required this.id,
    required this.eraId,
    required this.channelId,
    this.threadId,
    required this.action,
    required this.activeStep,
    required this.title,
    required this.description,
    required this.latencyMs,
    this.metrics = const {},
    this.payload,
    required this.timestamp,
  });

  factory TelemetrySpan.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    final rawTs = json['timestamp'];
    if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      parsedTime = DateTime.now();
    }

    final rawMetrics = json['metrics'];
    Map<String, dynamic> parsedMetrics = const {};
    if (rawMetrics is Map) {
      parsedMetrics = Map<String, dynamic>.from(rawMetrics);
    }

    final rawLatency = json['latency_ms'] ?? json['latencyMs'] ?? 0;
    int parsedLatency = 0;
    if (rawLatency is num) {
      parsedLatency = rawLatency.toInt();
    }

    return TelemetrySpan(
      id: (json['id'] ?? '').toString(),
      eraId: (json['era_id'] ?? json['eraId'] ?? '').toString(),
      channelId: (json['channel_id'] ?? json['channelId'] ?? '').toString(),
      threadId: json['thread_id'] != null ? json['thread_id'].toString() : json['threadId']?.toString(),
      action: (json['action'] ?? '').toString(),
      activeStep: json['active_step'] as int? ?? json['activeStep'] as int? ?? 1,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      latencyMs: parsedLatency,
      metrics: parsedMetrics,
      payload: json['payload']?.toString(),
      timestamp: parsedTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'era_id': eraId,
      'channel_id': channelId,
      if (threadId != null) 'thread_id': threadId,
      'action': action,
      'active_step': activeStep,
      'title': title,
      'description': description,
      'latency_ms': latencyMs,
      'metrics': metrics,
      if (payload != null) 'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class EraTradeoff {
  final String eraId;
  final int year;
  final String title;
  final String modernAnalogy;
  final List<String> benefits;
  final List<String> drawbacks;
  final String failureModeTitle;
  final String failureModeDescription;
  final String verdict2026;

  const EraTradeoff({
    required this.eraId,
    required this.year,
    required this.title,
    required this.modernAnalogy,
    required this.benefits,
    required this.drawbacks,
    required this.failureModeTitle,
    required this.failureModeDescription,
    required this.verdict2026,
  });

  Map<String, dynamic> toJson() => {
    'era_id': eraId,
    'year': year,
    'title': title,
    'modern_analogy': modernAnalogy,
    'benefits': benefits,
    'drawbacks': drawbacks,
    'failure_mode_title': failureModeTitle,
    'failure_mode_description': failureModeDescription,
    'verdict_2026': verdict2026,
  };

  factory EraTradeoff.fromJson(Map<String, dynamic> json) {
    return EraTradeoff(
      eraId: json['era_id'] ?? json['eraId'] ?? '',
      year: json['year'] ?? 1988,
      title: json['title'] ?? '',
      modernAnalogy: json['modern_analogy'] ?? json['modernAnalogy'] ?? '',
      benefits: (json['benefits'] as List? ?? []).map((e) => e.toString()).toList(),
      drawbacks: (json['drawbacks'] as List? ?? []).map((e) => e.toString()).toList(),
      failureModeTitle: json['failure_mode_title'] ?? json['failureModeTitle'] ?? '',
      failureModeDescription: json['failure_mode_description'] ?? json['failureModeDescription'] ?? '',
      verdict2026: json['verdict_2026'] ?? json['verdict2026'] ?? '',
    );
  }
}

class ShowcaseScriptStep {
  final String id;
  final String eraId;
  final int stepNumber;
  final String title;
  final String speakerScript;
  final String audienceObservation;
  final String actionLabel;
  final String actionId;
  final bool isDestructive;
  final String expectedSpanAction;

  const ShowcaseScriptStep({
    required this.id,
    required this.eraId,
    required this.stepNumber,
    required this.title,
    required this.speakerScript,
    required this.audienceObservation,
    required this.actionLabel,
    required this.actionId,
    required this.isDestructive,
    required this.expectedSpanAction,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'era_id': eraId,
    'step_number': stepNumber,
    'title': title,
    'speaker_script': speakerScript,
    'audience_observation': audienceObservation,
    'action_label': actionLabel,
    'action_id': actionId,
    'is_destructive': isDestructive,
    'expected_span_action': expectedSpanAction,
  };

  factory ShowcaseScriptStep.fromJson(Map<String, dynamic> json) {
    return ShowcaseScriptStep(
      id: json['id'] ?? '',
      eraId: json['era_id'] ?? json['eraId'] ?? '',
      stepNumber: json['step_number'] ?? json['stepNumber'] ?? 1,
      title: json['title'] ?? '',
      speakerScript: json['speaker_script'] ?? json['speakerScript'] ?? '',
      audienceObservation: json['audience_observation'] ?? json['audienceObservation'] ?? '',
      actionLabel: json['action_label'] ?? json['actionLabel'] ?? '',
      actionId: json['action_id'] ?? json['actionId'] ?? '',
      isDestructive: json['is_destructive'] ?? json['isDestructive'] ?? false,
      expectedSpanAction: json['expected_span_action'] ?? json['expectedSpanAction'] ?? '',
    );
  }
}

class EraArchitectureCatalog {
  static final Map<String, EraArchitecture> _catalog = {
    // ------------------------------------------------------------------------
    // 1. 1988: Ephemeral Buffer (IRC & Unix talk)
    // ------------------------------------------------------------------------
    'era-1988-irc': const EraArchitecture(
      eraId: 'era-1988-irc',
      year: 1988,
      title: '1988: Ephemeral Buffer (IRC & Unix talk)',
      cognitiveConcept: 'Short-Term Memory (STM) & FIFO Sliding Context Windows',
      summary: 'Volatile in-memory FIFO sliding window. Retains the latest message turns within a bounded RAM buffer, evicting oldest turns to fit immediate model context.',
      primaryCodeSnippet: '''// FifoSlidingWindow manages Short-Term Memory (STM) with fixed context token budgets.
type FifoSlidingWindow struct {
	mu           sync.RWMutex
	channelID    string
	maxTurns     int
	turns        []storage.Message
	evictedCount int
}

func NewFifoSlidingWindow(channelID string, maxTurns int) *FifoSlidingWindow {
	return &FifoSlidingWindow{
		channelID: channelID,
		maxTurns:  maxTurns,
		turns:     make([]storage.Message, 0, maxTurns),
	}
}

// Push appends a turn to volatile RAM, displacing turn 0 if capacity exceeded.
func (w *FifoSlidingWindow) Push(msg storage.Message) (evicted *storage.Message) {
	w.mu.Lock()
	defer w.mu.Unlock()

	if len(w.turns) >= w.maxTurns {
		ev := w.turns[0]
		evicted = &ev
		w.turns = w.turns[1:]
		w.evictedCount++
	}
	w.turns = append(w.turns, msg)
	return evicted
}

func (w *FifoSlidingWindow) GetActiveContext() []storage.Message {
	w.mu.RLock()
	defer w.mu.RUnlock()
	res := make([]storage.Message, len(w.turns))
	copy(res, w.turns)
	return res
}''',
      primaryCodeLanguage: 'go',
      schemaSnippet: '''# Redis Sorted Set (ZSET) Sliding Context Window: FIFO Eviction
# Key: context:chan-1988-irc:sliding_window
# Score: Millisecond Timestamp
# Member: JSON-encoded Message Turn

# 1. Ingest turn into active context window
ZADD context:chan-1988-irc:sliding_window 1774350000000 "{\\"turn_id\\":\\"t-101\\",\\"role\\":\\"user\\",\\"content\\":\\"Config key=alpha\\"}"

# 2. FIFO Window Eviction: Evict turns older than bounded capacity (keep top 10 turns)
# Drops rank 0 through -11 from volatile memory
ZREMRANGEBYRANK context:chan-1988-irc:sliding_window 0 -11

# 3. Fetch active Short-Term Memory window for LLM prompt synthesis
ZREVRANGE context:chan-1988-irc:sliding_window 0 9 WITHSCORES''',
      schemaLanguage: 'redis',
      steps: [
        ArchitecturePipelineStep(
          stepNumber: 1,
          badgeLabel: 'STEP 1 • CONTEXT INGESTION',
          flowTag: '→ Sliding Token Window',
          iconName: 'input',
          title: 'Short-Term Ingestion & Capacity Budget',
          techStack: 'Go / Tokenizer / Sliding Buffer',
          metaBadges: ['Short-Term Memory', 'Fixed Capacity', 'Sliding Window'],
          description: 'Ingests inbound turns into a volatile sliding token buffer bounded by a fixed turn budget.',
          sampleCode: '''// Ingest incoming message turn into volatile short-term memory
turn := storage.Message{
    ChannelID:  channelID,
    SenderName: sender,
    Content:    rawInput,
    Timestamp:  time.Now(),
}
evictedTurn := slidingWindow.Push(turn)
if evictedTurn != nil {
    telemetry.Emit("FIFO_EVICT", evictedTurn)
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 2,
          badgeLabel: 'STEP 2 • WORKING SLOT ALLOCATION',
          flowTag: '→ RAM Ring Buffer',
          iconName: 'memory',
          title: 'Volatile Working Slot Allocation',
          techStack: 'Go Concurrency / sync.RWMutex / Ephemeral RAM',
          metaBadges: ['RAM Ring Buffer', 'O(1) Append', 'Mutex Guard'],
          description: 'Allocates an in-memory slot protected by read-write mutexes to hold the active turn in RAM.',
          sampleCode: '''w.mu.Lock()
defer w.mu.Unlock()
if len(w.turns) < w.maxTurns {
    w.turns = append(w.turns, msg)
    return nil // Window capacity available; no eviction
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 3,
          badgeLabel: 'STEP 3 • FIFO CONTEXT EVICTION',
          flowTag: '→ Slide Window Boundary',
          iconName: 'swap_horiz',
          title: 'FIFO Context Eviction & Window Rolling',
          techStack: 'Go Slice Window / Memory Reclaim',
          metaBadges: ['FIFO Eviction', 'Capacity Enforcement', 'Bounded Context'],
          description: 'Evicts the oldest turn from the slice when capacity is reached to maintain the fixed context size.',
          sampleCode: '''// FIFO eviction: slide window boundary when capacity is reached
evictedTurn := w.turns[0]
w.turns = w.turns[1:]
w.evictedCount++
telemetry.Emit("FIFO_EVICT", evictedTurn)''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 4,
          badgeLabel: 'STEP 4 • PROMPT SYNTHESIS',
          flowTag: '→ Active Buffer Window',
          iconName: 'psychology',
          title: 'Active Window Prompt Synthesis',
          techStack: 'Gemini 3.8 Flash / Active Context Window',
          metaBadges: ['Prompt Assembly', 'Sliding Context', 'Model Inference'],
          description: 'Formats active in-memory turns into the Gemini 3.8 Flash prompt to generate conversational replies.',
          sampleCode: '''var promptBuilder strings.Builder
promptBuilder.WriteString("System: You are an ephemeral agent with bounded context memory.\\n")
for _, turn := range slidingWindow.GetActiveContext() {
    promptBuilder.WriteString(fmt.Sprintf("%s: %s\\n", turn.SenderName, turn.Content))
}
res, err := gemini.Generate(ctx, promptBuilder.String())''',
          codeLanguage: 'go',
        ),
      ],
    ),

    // ------------------------------------------------------------------------
    // 2. 1997: Bilateral Session & Presence (AIM & ICQ)
    // ------------------------------------------------------------------------
    'era-1997-aim': const EraArchitecture(
      eraId: 'era-1997-aim',
      year: 1997,
      title: '1997: 1:1 Direct Presence & Session (AIM & ICQ)',
      cognitiveConcept: '1:1 Session Working Memory & Attentional Liveness',
      summary: 'Dedicated bilateral working memory partitions with attentional presence tracking. Isolates 1:1 dialogue state and conditions the system prompt using dynamic Away Status messages.',
      primaryCodeSnippet: '''// SessionWorkingMemory manages dedicated bilateral 1:1 agent-user working memory.
type SessionWorkingMemory struct {
	mu        sync.RWMutex
	presences map[string]*storage.AgentPresence
	sessions  map[string]*storage.WorkingSession
}

func (s *SessionWorkingMemory) SetPresence(agentID, status, statusMsg, task string) *storage.AgentPresence {
	s.mu.Lock()
	defer s.mu.Unlock()

	p, exists := s.presences[agentID]
	if !exists {
		p = &storage.AgentPresence{AgentID: agentID}
		s.presences[agentID] = p
	}
	p.Status = status           // "available", "away", "busy"
	p.StatusMessage = statusMsg // Away message dynamic persona priming
	p.CurrentTask = task
	p.LastHeartbeat = time.Now()
	return p
}

func (s *SessionWorkingMemory) BuildPrompt(agentID string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	p := s.presences[agentID]
	if p == nil || p.Status != "away" {
		return "Focus: Dedicated bilateral 1:1 Working Memory session."
	}
	return fmt.Sprintf("Notice: Agent is AWAY [%s]. Sub-task: %s. Respond as delegated auto-responder.",
		p.StatusMessage, p.CurrentTask)
}''',
      primaryCodeLanguage: 'go',
      schemaSnippet: '''-- Dedicated Bilateral Working Memory Sessions & Dynamic Persona Priming
CREATE TABLE agent_presence (
    agent_id VARCHAR(64) PRIMARY KEY,
    agent_name VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL, -- 'available', 'away', 'busy'
    status_message TEXT,          -- Away status dynamic persona priming
    current_task VARCHAR(255),
    last_heartbeat TIMESTAMP NOT NULL
);

CREATE TABLE bilateral_working_sessions (
    session_id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    agent_id VARCHAR(64) NOT NULL REFERENCES agent_presence(agent_id),
    working_turns JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_bilateral_agent ON bilateral_working_sessions(agent_id, user_id);''',
      schemaLanguage: 'sql',
      steps: [
        ArchitecturePipelineStep(
          stepNumber: 1,
          badgeLabel: 'STEP 1 • BILATERAL SESSION PARTITION',
          flowTag: '→ 1:1 Session Isolation',
          iconName: 'chat_bubble',
          title: 'Bilateral Working Memory Partitioning',
          techStack: 'Go / Session Handshake / Working Memory',
          metaBadges: ['1:1 Bilateral', 'Session Partition', 'Dedicated Context'],
          description: 'Partitions conversational state into an isolated point-to-point working memory session between user and agent.',
          sampleCode: '''func HandleBilateralSession(w http.ResponseWriter, r *http.Request) {
    agentID := r.URL.Query().Get("agent_id")
    session := sessionStore.GetOrCreate(userID, agentID)
    session.SetAttentiveState(true)
    json.NewEncoder(w).Encode(session)
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 2,
          badgeLabel: 'STEP 2 • ATTENTIONAL LIVENESS',
          flowTag: '→ Liveness State Monitor',
          iconName: 'timer',
          title: 'Attentional Presence & Liveness Heartbeats',
          techStack: 'Go / Heartbeat Telemetry / Liveness Monitor',
          metaBadges: ['Heartbeat Telemetry', 'Attentional State', 'Activity Monitor'],
          description: 'Tracks cognitive availability via periodic heartbeats and signals state transitions between active and idle computing.',
          sampleCode: '''ticker := time.NewTicker(30 * time.Second)
go func() {
    for range ticker.C {
        if time.Since(agent.LastActive) > 5*time.Minute {
            presenceMgr.SetPresence(agent.ID, "away", "Deep background deliberation", "Compacting graph")
            telemetry.Emit("ATTENTIONAL_SHIFT", "Status set to away")
        }
    }
}()''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 3,
          badgeLabel: 'STEP 3 • AWAY PERSONA PRIMING',
          flowTag: '→ Dynamic Persona Priming',
          iconName: 'edit_note',
          title: 'Dynamic Persona Conditioning via Away Status',
          techStack: 'Go / Template Engine / System Persona',
          metaBadges: ['Persona Priming', 'Away Status', 'Prompt Conditioning'],
          description: 'Injects presence state and away status messages into the system prompt to guide agent persona behavior.',
          sampleCode: '''systemPrompt := fmt.Sprintf(
    "You are %s. Current attentional state: %s. Away memo: '%s'. " +
    "If status is away, concisely inform user and explain your current background focus.",
    agent.Name, agent.Status, agent.StatusMessage,
)''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 4,
          badgeLabel: 'STEP 4 • FOCUSED WORKING INFERENCE',
          flowTag: '→ Focused Working Window',
          iconName: 'psychology',
          title: 'Focused 1:1 Session Inference',
          techStack: 'Gemini 3.8 Flash / Bilateral Context',
          metaBadges: ['Working Memory', 'Direct Dialogue', 'Targeted Inference'],
          description: 'Executes Gemini 3.8 Flash inference bounded strictly to bilateral turns and current persona state.',
          sampleCode: '''turns := session.GetRecentTurns(20)
resp, err := gemini.ChatCompletion(ctx, &gemini.ChatRequest{
    SystemPrompt: systemPrompt,
    Messages:     turns,
    Temperature:  0.2,
})''',
          codeLanguage: 'go',
        ),
      ],
    ),

    // ------------------------------------------------------------------------
    // 3. 2006: Scoped Rooms & Context Fencing (Jabber & Scoped Rooms)
    // ------------------------------------------------------------------------
    'era-2006-jabber': const EraArchitecture(
      eraId: 'era-2006-jabber',
      year: 2006,
      title: '2006: Scoped Rooms & Context Fencing (Jabber & Scoped Rooms)',
      cognitiveConcept: 'Context Fencing & Role-Based Isolation',
      summary: 'Domain-partitioned room memory enforced by role-based access control (RBAC). Restricts conversational context and retrieval strictly to authorized room perimeters.',
      primaryCodeSnippet: '''// ContextFence enforces room-level memory boundaries and RBAC permissions.
type ContextFence struct {
	mu           sync.RWMutex
	channelRoles map[string][]string // channel_id -> permitted role slice
	store        storage.Store
}

func (f *ContextFence) ValidateAccess(channelID, userRole string) error {
	f.mu.RLock()
	defer f.mu.RUnlock()

	allowed, exists := f.channelRoles[channelID]
	if !exists {
		return nil // Public room
	}
	for _, r := range allowed {
		if r == userRole || r == "admin" {
			return nil
		}
	}
	return fmt.Errorf("FIREWALL_QUARANTINE: role %s unauthorized for room %s", userRole, channelID)
}

func (f *ContextFence) FetchScopedContext(ctx context.Context, channelID, query string) ([]storage.Message, error) {
	// Anti-bleed invariant: context retrieval is strictly partitioned by channel_id
	return f.store.ListMessages(ctx, channelID, 50)
}''',
      primaryCodeLanguage: 'go',
      schemaSnippet: '''-- Role-Based Scoped Context Rooms & Anti-Bleed Memory Fencing
CREATE TABLE project_rooms (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    is_confidential BOOLEAN DEFAULT FALSE,
    retention_hours INT DEFAULT 48
);

CREATE TABLE room_rbac_policies (
    room_id VARCHAR(64) NOT NULL REFERENCES project_rooms(id),
    role_name VARCHAR(64) NOT NULL,
    can_read BOOLEAN DEFAULT TRUE,
    can_write BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (room_id, role_name)
);

CREATE TABLE scoped_messages (
    id VARCHAR(64) PRIMARY KEY,
    room_id VARCHAR(64) NOT NULL REFERENCES project_rooms(id),
    sender_id VARCHAR(64) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_scoped_room_time ON scoped_messages(room_id, created_at DESC);''',
      schemaLanguage: 'sql',
      steps: [
        ArchitecturePipelineStep(
          stepNumber: 1,
          badgeLabel: 'STEP 1 • DOMAIN ROUTING',
          flowTag: '→ Room Boundary Filter',
          iconName: 'meeting_room',
          title: 'Project Domain Partitioning & Scoping',
          techStack: 'Go / Scoped Router / Domain Boundary',
          metaBadges: ['Domain Partition', 'Topic Scoping', 'Context Perimeter'],
          description: 'Routes messages and queries into domain-specific room perimeters to establish isolated project contexts.',
          sampleCode: '''func RouteDomainMessage(w http.ResponseWriter, r *http.Request) {
    roomID := mux.Vars(r)["room_id"]
    room, err := store.GetChannel(r.Context(), roomID)
    if err != nil {
        http.Error(w, "Room perimeter not found", 404)
        return
    }
    // Context is strictly confined to room.ID
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 2,
          badgeLabel: 'STEP 2 • ROLE-BASED ACCESS CONTROL',
          flowTag: '→ RBAC Permission Check',
          iconName: 'security',
          title: 'Context Firewall & RBAC Validation',
          techStack: 'Go / Security Middleware / RBAC Engine',
          metaBadges: ['RBAC Validation', 'Access Policy', 'Caller Verification'],
          description: 'Validates caller role permissions against channel policies before granting access to room context.',
          sampleCode: '''if !channel.IsRoleAllowed(caller.Role) {
    telemetry.Emit("FIREWALL_QUARANTINE", map[string]any{
        "channel": channel.ID,
        "caller":  caller.ID,
        "role":    caller.Role,
    })
    return ErrForbidden
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 3,
          badgeLabel: 'STEP 3 • SCOPED QUERY RETRIEVAL',
          flowTag: '→ Scoped Query Filter',
          iconName: 'shield',
          title: 'Scoped Storage Retrieval & Query Fencing',
          techStack: 'Go Storage / SQL Filter / Scoped Retrieval',
          metaBadges: ['Scoped Retrieval', 'Channel Isolation', 'SQL Partitioning'],
          description: 'Filters storage queries by channel identifier, ensuring retrieval returns only records within the authorized room.',
          sampleCode: '''// Hard memory fence: query scoped strictly to channelID
query := `SELECT id, content FROM scoped_messages 
          WHERE room_id = \$1 
          ORDER BY created_at DESC LIMIT 50`
rows, err := db.QueryContext(ctx, query, channelID)''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 4,
          badgeLabel: 'STEP 4 • FENCED INFERENCE',
          flowTag: '→ Fenced Room Prompt',
          iconName: 'psychology',
          title: 'Domain-Bounded Context Inference',
          techStack: 'Gemini 3.8 Flash / Fenced Context',
          metaBadges: ['Domain Prompt', 'Scoped System Rules', 'Channel Synthesis'],
          description: 'Constructs the LLM prompt using verified room history and topic constraints to generate domain-confined responses.',
          sampleCode: '''prompt := fmt.Sprintf(
    "Room Perimeter: #%s | Topic: %s\\n" +
    "Security Policy: Strictly bounded to this channel. Do not access external entities.\\n\\n" +
    "History:\\n%s\\nQuery: %s",
    ch.Name, ch.Topic, historyText, userQuery,
)''',
          codeLanguage: 'go',
        ),
      ],
    ),

    // ------------------------------------------------------------------------
    // 4. 2013: Searchable Vector Archive (HipChat & Cloud Archive)
    // ------------------------------------------------------------------------
    'era-2013-hipchat': const EraArchitecture(
      eraId: 'era-2013-hipchat',
      year: 2013,
      title: '2013: Searchable Vector Archive (HipChat & Cloud Archive)',
      cognitiveConcept: 'Long-Term Memory (LTM) & Vector Search RAG',
      summary: 'Persistent append-only event storage with dense vector indexing. Ingests events, computes semantic embeddings, and uses cosine distance queries to recall historical precedents for inference.',
      primaryCodeSnippet: '''// VectorRAG executes cosine distance similarity searches over Long-Term Memory.
type VectorRAGStore struct {
	store storage.MemoryStore
}

func (s *VectorRAGStore) QueryLTM(ctx context.Context, channelID string, queryEmbedding []float32, topK int) ([]storage.VectorSearchResult, error) {
	// Execute semantic cosine distance retrieval against indexed ADRs and precedents
	results := s.store.SearchVectors(ctx, channelID, queryEmbedding, topK, 0.75)
	return results, nil
}''',
      primaryCodeLanguage: 'go',
      schemaSnippet: '''-- Persistent Long-Term Memory (LTM) Vector Schema
CREATE TABLE messages (
    id STRING NOT NULL,
    channel_id STRING NOT NULL,
    sender_name STRING NOT NULL,
    content STRING NOT NULL,
    token_count INT64 NOT NULL,
    embedding ARRAY<FLOAT64>,
    created_at TIMESTAMP NOT NULL
);

-- BigQuery Vector Search Query using ML.DISTANCE COSINE
SELECT id, sender_name, content,
       ML.DISTANCE(embedding, @query_vec, 'COSINE') AS distance
FROM `davenport-boutique.adk_agent_telemetry.crystallized_beliefs`
WHERE channel_id = @chan_id
ORDER BY distance ASC
LIMIT 3;''',
      schemaLanguage: 'sql',
      steps: [
        ArchitecturePipelineStep(
          stepNumber: 1,
          badgeLabel: 'STEP 1 • TELEMETRY WEBHOOK INGEST',
          flowTag: '→ Append-Only Event Log',
          iconName: 'webhook',
          title: 'Persistent Event Ingestion & Audit Logging',
          techStack: 'Go / Cloud Run / JSON Webhook',
          metaBadges: ['Webhook Ingest', 'Persistent Log', 'Append-Only LTM'],
          description: 'Stores inbound webhooks and interactions into durable append-only cloud storage with commit timestamps.',
          sampleCode: '''func HandleWebhook(w http.ResponseWriter, r *http.Request) {
    var payload WebhookEvent
    if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
        http.Error(w, err.Error(), 400)
        return
    }
    msg := store.SaveMessage(r.Context(), payload.ToMessage())
    telemetry.Emit("STORE_WRITE", msg.ID)
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 2,
          badgeLabel: 'STEP 2 • EMBEDDING GENERATION',
          flowTag: '→ 16-d Semantic Embedding',
          iconName: 'fingerprint',
          title: 'High-Dimensional Vector Embedding',
          techStack: 'Go / Gemini Embeddings / Vector Float Array',
          metaBadges: ['Vector Projection', 'Semantic Embeddings', 'Normalized Float32'],
          description: 'Computes normalized vector embeddings for ingested content to map semantic relationships into geometric space.',
          sampleCode: '''vec, err := embeddingService.EmbedText(ctx, msg.Content)
if err != nil {
    return err
}
msg.Embedding = vec // Normalized []float32
store.UpdateMessageVector(ctx, msg.ID, vec)''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 3,
          badgeLabel: 'STEP 3 • VECTOR COSINE SEARCH',
          flowTag: '→ Cosine Distance Search',
          iconName: 'search',
          title: 'Vector Cosine Search & Precedent Recall',
          techStack: 'BigQuery & Vector Engine / Cosine Distance',
          metaBadges: ['Vector Search', 'Cosine Distance', 'Top-K Retrieval'],
          description: 'Executes cosine distance queries across vector indexes to retrieve top-K semantically relevant historical records.',
          sampleCode: '''SELECT id, sender_name, content,
       ML.DISTANCE(embedding, @query_vec, 'COSINE') AS distance
FROM `davenport-boutique.adk_agent_telemetry.crystallized_beliefs`
WHERE channel_id = @chan_id
ORDER BY distance ASC
LIMIT 3;''',
          codeLanguage: 'sql',
        ),
        ArchitecturePipelineStep(
          stepNumber: 4,
          badgeLabel: 'STEP 4 • RAG PROMPT AUGMENTATION',
          flowTag: '→ Grounded LTM Prompt',
          iconName: 'psychology',
          title: 'Long-Term Memory Grounding & Synthesis',
          techStack: 'Gemini 3.8 Flash / Augmented Prompt',
          metaBadges: ['RAG Grounding', 'LTM Injection', 'Precedent Synthesis'],
          description: 'Injects retrieved historical records into Gemini 3.8 Flash context to ground responses in documented precedents.',
          sampleCode: '''prompt := fmt.Sprintf(
    "System: Analyze current incident using historical ADRs:\\n" +
    "[HISTORICAL LTM ADRs]\\n%s\\n\\n" +
    "[ACTIVE TELEMETRY]\\n%s\\n" +
    "Provide root cause and resolution quoting relevant ADR ID.",
    formatRAGContext(retrievedADRs), currentAlertText,
)''',
          codeLanguage: 'go',
        ),
      ],
    ),

    // ------------------------------------------------------------------------
    // 5. 2017: Threads & Scribe Compaction (Discord Forums & Threaded Chat)
    // ------------------------------------------------------------------------
    'era-2017-threads': const EraArchitecture(
      eraId: 'era-2017-threads',
      year: 2017,
      title: '2017: Threads & Scribe Compaction (Discord Forums & Threaded Chat)',
      cognitiveConcept: 'Subagent Scratchpads & Hierarchical Compaction',
      summary: 'Thread branching and Scribe state compaction. Specialist agents deliberate in dedicated thread scratchpads, which a Scribe condenses into structured checkpoints for the main channel.',
      primaryCodeSnippet: '''// ScribeCompactor compresses thread scratchpad dialogue into structured state summaries.
type ScribeCompactor struct {
	gemini *gemini.Client
	store  storage.Store
}

func (sc *ScribeCompactor) CompactThread(ctx context.Context, channelID, threadID string) (*storage.Summary, error) {
	msgs, err := sc.store.ListThreadMessages(ctx, channelID, threadID)
	if err != nil {
		return nil, err
	}

	rawTokens := calculateTokens(msgs) // e.g. 4,800 tokens
	condensedText, err := sc.gemini.SummarizeThread(ctx, msgs)
	compactTokens := calculateTokens([]storage.Message{{Content: condensedText}}) // e.g. 190 tokens

	summary := &storage.Summary{
		ID:               fmt.Sprintf("sum-%d", time.Now().Unix()),
		ChannelID:        channelID,
		ThreadID:         threadID,
		CondensedState:   condensedText,
		OriginalTokens:   rawTokens,
		CompactedTokens:  compactTokens,
		CompressionRatio: 1.0 - (float64(compactTokens) / float64(rawTokens)), // ~0.96 (96%)
		CreatedAt:        time.Now(),
	}
	return summary, sc.store.SaveSummary(ctx, summary)
}''',
      primaryCodeLanguage: 'go',
      schemaSnippet: '''-- Hierarchical Subagent Scratchpads & Scribe Compaction Summaries
CREATE TABLE thread_scratchpads (
    id VARCHAR(64) PRIMARY KEY,
    channel_id VARCHAR(64) NOT NULL,
    parent_message_id VARCHAR(64) NOT NULL,
    initiator_agent_id VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'active', -- 'active', 'compacted'
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE thread_compaction_summaries (
    id VARCHAR(64) PRIMARY KEY,
    channel_id VARCHAR(64) NOT NULL,
    thread_id VARCHAR(64) NOT NULL REFERENCES thread_scratchpads(id),
    condensed_state TEXT NOT NULL,
    original_tokens INT NOT NULL,
    compacted_tokens INT NOT NULL,
    compression_ratio DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_thread_summaries_lookup ON thread_compaction_summaries(channel_id, thread_id);''',
      schemaLanguage: 'sql',
      steps: [
        ArchitecturePipelineStep(
          stepNumber: 1,
          badgeLabel: 'STEP 1 • THREAD SCRATCHPAD BRANCHING',
          flowTag: '→ Thread Scratchpad',
          iconName: 'alt_route',
          title: 'Thread Scratchpad Branching & Context Scoping',
          techStack: 'Go / Thread Router / Relational DB',
          metaBadges: ['Thread Branch', 'Scratchpad Boundary', 'Context Scoping'],
          description: 'Forks specialized tasks into dedicated thread scratchpads to isolate detailed deliberation from the main channel.',
          sampleCode: '''func BranchThread(w http.ResponseWriter, r *http.Request) {
    parentID := mux.Vars(r)["parent_id"]
    threadMsg := storage.Message{
        ThreadID: parentID,
        Content:  "Starting subagent diagnostic scratchpad...",
    }
    store.CreateMessage(r.Context(), threadMsg)
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 2,
          badgeLabel: 'STEP 2 • SPECIALIST DELIBERATION',
          flowTag: '→ Thread Deliberation',
          iconName: 'developer_board',
          title: 'Autonomous Specialist Investigation',
          techStack: 'Go / Specialist Swarm / Thread Context',
          metaBadges: ['Sub-Task Deliberation', 'Specialist Roles', 'Local Workspace'],
          description: 'Enables specialist agents to exchange diagnostic queries and analysis within the thread while tracking token usage.',
          sampleCode: '''threadMsgs, _ := store.ListThreadMessages(ctx, channelID, threadID)
tokenMeter.RecordUsage(threadID, calculateTokens(threadMsgs))
agentResponse := researcherAgent.Investigate(ctx, threadMsgs)
store.SaveMessage(ctx, agentResponse)''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 3,
          badgeLabel: 'STEP 3 • SCRIBE COMPACTION ENGINE',
          flowTag: '→ Hierarchical State Rollup',
          iconName: 'compress',
          title: 'Hierarchical State Rollup & Scribe Compaction',
          techStack: 'Gemini 3.8 Flash / Scribe Agent / State Rollup',
          metaBadges: ['Scribe Compaction', 'State Rollup', 'Dynamic Rollup'],
          description: 'Prompts Gemini 3.8 Flash via a dedicated Scribe agent to distill multi-turn thread dialogue into a structured summary.',
          sampleCode: '''summaryPrompt := fmt.Sprintf(
    "Distill thread into 4 bullets: (1) Root Cause, (2) Action Taken, " +
    "(3) System Invariants, (4) Next Step.\\n\\nRaw Thread:\\n%s", 
    formatThreadTurns(threadMsgs),
)
condensedState, _ := gemini.Generate(ctx, summaryPrompt)''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 4,
          badgeLabel: 'STEP 4 • MAIN CHANNEL POST-BACK',
          flowTag: '→ Condensed Root Checkpoint',
          iconName: 'fact_check',
          title: 'Consolidated Checkpoint Injection',
          techStack: 'Go / WebSocket Broadcast / UI Badge',
          metaBadges: ['Root Checkpoint', 'Broadcast Summary', 'State Handoff'],
          description: 'Posts the compacted checkpoint back to the root stream with intent metadata for downstream agent consumption.',
          sampleCode: '''rootCard := storage.Message{
    ChannelID:  channelID,
    SenderName: "Staff Scribe",
    Content:    fmt.Sprintf("📋 [THREAD CHECKPOINT] -96%% Tokens:\\n%s", summary.CondensedState),
    IntentTags: []storage.IntentTag{{Label: "compaction", Type: "compaction"}},
}
orchestrator.BroadcastMessage(rootCard)''',
          codeLanguage: 'go',
        ),
      ],
    ),

    // ------------------------------------------------------------------------
    // 6. 2026: Multi-Agent Mesh
    // ------------------------------------------------------------------------
    'era-2026-agent-mesh': const EraArchitecture(
      eraId: 'era-2026-agent-mesh',
      year: 2026,
      title: '2026: Collaborative Multi-Agent Mesh (Agents of Chat)',
      cognitiveConcept: 'Dual-Layer Cognitive Mesh & REM Dreaming',
      summary: 'Dual-layer memory mesh combining a shared public blackboard with private agent scratchpads. Asynchronous background REM Dreaming consolidates events and crystallizes long-term beliefs across the swarm.',
      primaryCodeSnippet: '''// MeshOrchestrator manages the dual-layer cognitive mesh and REM dreaming consolidation.
type MeshOrchestrator struct {
	blackboard  *storage.BlackboardStore
	scratchpads *storage.ScratchpadStore
	dreamer     *storage.DreamingEngine
	gemini      *gemini.Client
}

func (m *MeshOrchestrator) ProcessTurn(ctx context.Context, agentID, channelID string, input storage.Message) (*storage.Message, error) {
	// 1. Read private scratchpad for confidential inner monologue
	pad, _ := m.scratchpads.Get(agentID, channelID)

	// 2. Read public shared blackboard events with semantic intent tags
	blackboardTurns, _ := m.blackboard.List(ctx, channelID, 20)

	// 3. Synthesize dual-layer cognitive context for Gemini 3.8 Flash
	thought, publicReply := m.gemini.DualLayerReasoning(ctx, pad.InnerMonologue, blackboardTurns, input)

	// 4. Update private scratchpad with internal thought
	m.scratchpads.Update(agentID, channelID, thought)

	// 5. Post approved public turn to shared blackboard
	return m.blackboard.Post(ctx, channelID, publicReply)
}''',
      primaryCodeLanguage: 'go',
      schemaSnippet: '''-- BigQuery Dual-Layer Cognitive Mesh & REM Dreaming Consolidation
CREATE TABLE `davenport-boutique.adk_agent_telemetry.agent_logs` (
    id STRING NOT NULL,
    channel_id STRING NOT NULL,
    agent_id STRING NOT NULL,
    content STRING NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE `davenport-boutique.adk_agent_telemetry.session_summaries` (
    id STRING NOT NULL,
    channel_id STRING NOT NULL,
    condensed_summary STRING NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE `davenport-boutique.adk_agent_telemetry.crystallized_beliefs` (
    key STRING NOT NULL,
    channel_id STRING NOT NULL,
    statement STRING NOT NULL,
    confidence FLOAT64 NOT NULL,
    embedding ARRAY<FLOAT64>
);''',
      schemaLanguage: 'sql',
      steps: [
        ArchitecturePipelineStep(
          stepNumber: 1,
          badgeLabel: 'STEP 1 • SHARED BLACKBOARD INGESTION',
          flowTag: '→ Public Consensus Bus',
          iconName: 'hub',
          title: 'Shared Team Blackboard & Semantic Intent Tags',
          techStack: 'Go / WebSocket Swarm / Blackboard Bus',
          metaBadges: ['Shared Blackboard', 'Swarm Bus', 'Semantic Intent Tags'],
          description: 'Broadcasts team coordination messages to a shared blackboard annotated with semantic intent tags.',
          sampleCode: '''func BroadcastBlackboard(msg storage.Message) {
    tags := classifyIntentTags(msg.Content)
    msg.IntentTags = tags
    blackboard.Append(msg)
    swarmPubSub.Publish("blackboard_events", msg)
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 2,
          badgeLabel: 'STEP 2 • PRIVATE INNER MONOLOGUE',
          flowTag: '→ Private Cognitive Scratchpad',
          iconName: 'lock',
          title: 'Private Agent Scratchpads & Inner Monologue',
          techStack: 'Go / Key-Value Scratchpad / Private State',
          metaBadges: ['Inner Monologue', 'Private Scratchpad', 'Isolated Deliberation'],
          description: 'Maintains confidential working memory per agent to formulate hypotheses and test plans before sharing.',
          sampleCode: '''func (a *Agent) DeliberatePrivate(ctx context.Context, task string) {
    pad := a.scratchpadStore.Get(a.ID)
    pad.InnerMonologue += "\\nHypothesis: Database lock contention on table locks."
    pad.ActivePlan = []string{"Run lock trace", "Verify commit timestamps"}
    a.scratchpadStore.Save(pad)
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 3,
          badgeLabel: 'STEP 3 • ASYNC DREAMING CONSOLIDATION',
          flowTag: '→ Dreaming Consolidation Engine',
          iconName: 'nights_stay',
          title: 'Background REM Dreaming & Belief Crystallization',
          techStack: 'Go Background Worker / Gemini 3.8 Flash',
          metaBadges: ['REM Dreaming', 'Knowledge Consolidation', 'Crystallized Beliefs'],
          description: 'Runs background consolidation with Gemini 3.8 Flash to synthesize unconsolidated events into crystallized beliefs.',
          sampleCode: '''func (d *DreamingEngine) RunDreamCycle(ctx context.Context, channelID string) (*ConsolidationReport, error) {
    events := d.store.GetUnconsolidatedEvents(channelID)
    report := d.synthesizer.Consolidate(ctx, events)
    d.store.SaveReport(report)
    telemetry.Emit("DREAM_CONSOLIDATION", report)
    return report, nil
}''',
          codeLanguage: 'go',
        ),
        ArchitecturePipelineStep(
          stepNumber: 4,
          badgeLabel: 'STEP 4 • MESH ADAPTIVE INFERENCE',
          flowTag: '→ Unified Dual-Layer Synthesis',
          iconName: 'psychology',
          title: 'Dual-Layer Cognitive Mesh & Swarm Consensus',
          techStack: 'Gemini 3.8 Flash / Dual-Layer Context / BigQuery',
          metaBadges: ['Swarm Consensus', 'Dual-Layer RAG', 'Multi-Agent Inference'],
          description: 'Synthesizes crystallized beliefs, shared blackboard state, and private scratchpad conclusions into unified agent actions.',
          sampleCode: '''finalPrompt := fmt.Sprintf(
    "System: Multi-Agent Mesh Coordinator.\\n" +
    "[CONSOLIDATED KNOWLEDGE]\\n%s\\n\\n" +
    "[PUBLIC BLACKBOARD]\\n%s\\n\\n" +
    "[PRIVATE SCRATCHPAD]\\n%s\\n\\nRespond with consensus decision.",
    report.CondensedSummary, blackboardText, pad.InnerMonologue,
)
resp, _ := gemini.Generate(ctx, finalPrompt)''',
          codeLanguage: 'go',
        ),
      ],
    ),
  };

  /// Architectural tradeoff profiles comparing historical approaches to modern 2026 cognitive systems.
  static final Map<String, EraTradeoff> eraTradeoffs = {
    'era-1988-irc': const EraTradeoff(
      eraId: 'era-1988-irc',
      year: 1988,
      title: '1988 Ephemeral Buffer',
      modernAnalogy: 'Fixed-turn sliding context window (e.g. Chat completion API with array slice messages[-10:]).',
      benefits: [
        'Zero storage overhead and instant O(1) in-memory appends',
        'Minimal token latency with strictly bounded prompt sizes',
        'No stale state migration or schema maintenance required',
      ],
      drawbacks: [
        'Catastrophic forgetting: critical initial instructions drop off silently',
        'Zero audit trail or compliance recall across agent restarts',
        'Vulnerable to hallucination when referencing evicted decisions',
      ],
      failureModeTitle: 'FIFO Window Turn Eviction',
      failureModeDescription: 'When the conversation exceeds buffer capacity, earliest turns are displaced from active working memory to maintain context window limits.',
      verdict2026: 'Obsolete as standalone architecture; only used as an ultra-low-latency layer within tiered hierarchical memory caches.',
    ),
    'era-1997-aim': const EraTradeoff(
      eraId: 'era-1997-aim',
      year: 1997,
      title: '1997 Bilateral Session & Presence',
      modernAnalogy: '1:1 agent direct chat with dynamic system prompt persona priming (e.g., status-driven prompt engineering).',
      benefits: [
        'Strict dialogue isolation with zero crosstalk from other channels',
        'Dynamic persona adaptation using away message prompt priming',
        'Clear attentional state tracking via liveness heartbeats',
      ],
      drawbacks: [
        'Siloed working memory cannot participate in multi-agent team synthesis',
        'Stale away status messages can poison the agent’s ongoing persona',
        'Unbounded 1:1 dialogue length eventually causes working memory bloat',
      ],
      failureModeTitle: 'Persona Bleed & Attentional Drift',
      failureModeDescription: 'Stale away messages or unrefreshed presence indicators cause the agent to remain trapped in an auto-responder persona, misunderstanding user prompts.',
      verdict2026: 'Foundational for point-to-point human-agent DM channels, but must be augmented with cross-session semantic indexing.',
    ),
    'era-2006-jabber': const EraTradeoff(
      eraId: 'era-2006-jabber',
      year: 2006,
      title: '2006 Scoped Rooms & Context Fencing',
      modernAnalogy: 'Multi-tenant partitioned agent workspaces with strict RBAC memory guards and perimeter fencing.',
      benefits: [
        'Prevents associative bleed and prompt poisoning across project boundaries',
        'Enforces zero-trust RBAC at the channel retrieval layer',
        'Clear topic demarcations keep agent context highly relevant to current domain',
      ],
      drawbacks: [
        'Hard silos hinder cross-functional discovery (e.g. engineering cannot query billing ADRs directly)',
        'Requires meticulous permission management across rooms and subagents',
        'No automated cross-domain knowledge synthesis',
      ],
      failureModeTitle: 'Context Firewall Quarantine & Domain Blindspots',
      failureModeDescription: 'Overly restrictive fences block legitimate cross-agent collaboration, while unauthorized access triggers quarantine rejections that halt execution.',
      verdict2026: 'Mandatory enterprise security baseline for enterprise agent perimeters, but requires federated retrieval bridges for cross-team tasks.',
    ),
    'era-2013-hipchat': const EraTradeoff(
      eraId: 'era-2013-hipchat',
      year: 2013,
      title: '2013 Searchable Vector Archive',
      modernAnalogy: 'Vector Database RAG over persistent cloud datastores (e.g. BigQuery Vector Search with Cosine Distance).',
      benefits: [
        'Durable append-only audit trail persists across agent restarts and reboots',
        'Sub-10ms semantic retrieval of historical ADRs and resolved incident post-mortems',
        'Grounds agent generations in verified organizational precedents',
      ],
      drawbacks: [
        'Vector embedding drift over time can cause semantic recall blindspots',
        'Unfiltered retrieval can inject outdated precedents that contradict current system rules',
        'High cloud infrastructure and embedding generation overhead per message',
      ],
      failureModeTitle: 'Semantic Recall Blindspots & Precedent Contradiction',
      failureModeDescription: 'Semantic distance metrics can retrieve irrelevant or superseded historical records, causing the agent to recommend obsolete practices.',
      verdict2026: 'Standard industry pillar for Long-Term Memory (LTM), but requires continuous compaction and dreaming to resolve historical contradictions.',
    ),
    'era-2017-threads': const EraTradeoff(
      eraId: 'era-2017-threads',
      year: 2017,
      title: '2017 Threads & Scribe Compaction',
      modernAnalogy: 'Subagent scratchpads with recursive token rollup (e.g., isolated deliberation forks with -96% compression).',
      benefits: [
        'Shields main conversation context from noisy raw diagnostic traces and logs',
        'Recursive Scribe compaction achieves >90% token reduction (-96%)',
        'Allows specialist agents to deliberate autonomously without cluttering root channels',
      ],
      drawbacks: [
        'Lossy compaction may discard subtle edge-case details critical for root cause analysis',
        'Thread context can become orphaned if the Scribe agent fails to roll up state',
        'Latency overhead introduced by intermediate summarization steps',
      ],
      failureModeTitle: 'Lossy Compaction & Orphaned Scratchpads',
      failureModeDescription: 'Aggressive summarization abstracts away vital error codes or system invariants, preventing downstream agents from executing precise remediations.',
      verdict2026: 'Essential architectural pattern for subagent task delegation and long-running reasoning chains in modern agentic loops.',
    ),
    'era-2026-agent-mesh': const EraTradeoff(
      eraId: 'era-2026-agent-mesh',
      year: 2026,
      title: '2026 Collaborative Multi-Agent Mesh',
      modernAnalogy: 'Dual-layer cognitive mesh with shared blackboard, private inner monologue, and asynchronous Gemini 3.8 REM dreaming.',
      benefits: [
        'Combines collective swarm intelligence with private, confidential agent deliberation',
        'Background REM dreaming autonomously resolves cross-agent contradictions during idle periods',
        'Semantic intent tagging eliminates quadratic re-parsing of shared channel history',
        'Zero token pollution between private reasoning traces and public consensus',
      ],
      drawbacks: [
        'Complex distributed consensus and state synchronization across multiple autonomous agents',
        'Potential for split-brain consensus drift if dreaming consolidation runs during active partitions',
        'Requires robust telemetry and tracing to observe multi-agent deliberations',
      ],
      failureModeTitle: 'Swarm Split-Brain & Consensus Drift',
      failureModeDescription: 'Asynchronous dreaming consolidation or divergent private monologues can cause peer agents to hold conflicting views of system ground truth.',
      verdict2026: 'The gold standard cognitive architecture for 2026 autonomous agent swarms and multi-agent coordination.',
    ),
  };

  /// Interactive showcase presenter scripts for interactive stage walkthroughs and action triggers.
  static final List<ShowcaseScriptStep> showcaseScriptSteps = [
    const ShowcaseScriptStep(
      id: 'showcase-era1-overflow',
      eraId: 'era-1988-irc',
      stepNumber: 1,
      title: 'Simulate FIFO Buffer Eviction (6 Turns)',
      speakerScript: 'Notice how the 1988 IRC bot operates on a volatile 5-turn sliding memory buffer. As new interactions are pushed past the 5-turn threshold, earliest turns are displaced from the buffer to maintain context boundaries.',
      audienceObservation: 'Observe the live telemetry stream: as Turn 6 is ingested, a FIFO_EVICT span triggers immediately as the oldest turn rolls out of the sliding window.',
      actionLabel: 'Simulate FIFO Buffer Eviction (6 Turns)',
      actionId: 'action-era1-overflow',
      isDestructive: true,
      expectedSpanAction: 'FIFO_EVICT',
    ),
    const ShowcaseScriptStep(
      id: 'showcase-era2-test-boundary',
      eraId: 'era-1997-aim',
      stepNumber: 2,
      title: 'Verify 1:1 Session Isolation',
      speakerScript: 'In 1997, AIM revolutionized conversational UX with 1:1 direct messaging and attentional presence. When our agent transitions to "Away" status, notice how its system prompt is dynamically primed with the away status message, preserving working memory isolation without channel cross-talk.',
      audienceObservation: 'Observe the ATTENTIONAL_SHIFT span in the live telemetry panel. The agent persona updates in real-time, responding as an automated delegate while protecting its dedicated bilateral context.',
      actionLabel: 'Verify 1:1 Session Isolation',
      actionId: 'action-era2-test-boundary',
      isDestructive: false,
      expectedSpanAction: 'ATTENTIONAL_SHIFT',
    ),
    const ShowcaseScriptStep(
      id: 'showcase-era3-trigger-quarantine',
      eraId: 'era-2006-jabber',
      stepNumber: 3,
      title: 'Trigger RBAC Firewall Quarantine',
      speakerScript: 'Jabber in 2006 brought structured project rooms. Here, context fencing is enforced by a role-based firewall. When an unprivileged participant attempts to query or leak data from a confidential domain, our Context Firewall immediately quarantines the request.',
      audienceObservation: 'The telemetry log emits a FIREWALL_QUARANTINE span. The attempt to bridge cross-tenant memory is blocked at the perimeter before any retrieval occurs.',
      actionLabel: 'Trigger RBAC Firewall Quarantine',
      actionId: 'action-era3-trigger-quarantine',
      isDestructive: true,
      expectedSpanAction: 'FIREWALL_QUARANTINE',
    ),
    const ShowcaseScriptStep(
      id: 'showcase-era4-vector-query',
      eraId: 'era-2013-hipchat',
      stepNumber: 4,
      title: 'Run Vector RAG Query',
      speakerScript: 'With HipChat in 2013, we transition from ephemeral buffers to true Long-Term Memory. Every incident and ADR is vectorized into persistent storage. When a production alert fires, our agent queries the vector index using exact cosine distance to retrieve historical precedents in sub-10ms.',
      audienceObservation: 'See the VECTOR_SEARCH span fire. The vector engine returns the exact historical ADR with distance metrics, grounding the Gemini 3.8 response in immutable long-term memory.',
      actionLabel: 'Run Vector RAG Query',
      actionId: 'action-era4-vector-query',
      isDestructive: false,
      expectedSpanAction: 'VECTOR_SEARCH',
    ),
    const ShowcaseScriptStep(
      id: 'showcase-era5-compact-thread',
      eraId: 'era-2017-threads',
      stepNumber: 5,
      title: 'Compact Thread Context (-96%)',
      speakerScript: 'By 2017, threaded chat enabled subagent scratchpads. Instead of polluting the root stream with thousands of diagnostic tokens, our specialist agents deliberate in an isolated thread. Upon conclusion, our Scribe agent performs hierarchical state compaction.',
      audienceObservation: 'Watch the SCRIBE_COMPACT span record a 96% token reduction. A 4,500-token debugging dialogue is rolled up into a dense 180-token structured checkpoint posted to the main channel.',
      actionLabel: 'Compact Thread Context (-96%)',
      actionId: 'action-era5-compact-thread',
      isDestructive: false,
      expectedSpanAction: 'SCRIBE_COMPACT',
    ),
    const ShowcaseScriptStep(
      id: 'showcase-era6-trigger-dreaming',
      eraId: 'era-2026-agent-mesh',
      stepNumber: 6,
      title: 'Trigger REM Dreaming Consolidation',
      speakerScript: 'Welcome to 2026: the Collaborative Multi-Agent Mesh. Agents coordinate publicly on a shared blackboard while maintaining confidential inner monologues in private scratchpads. During idle periods, our background REM Dreaming daemon wakes up with Gemini 3.8 Flash, consolidating knowledge and resolving contradictions.',
      audienceObservation: 'Observe the DREAM_CONSOLIDATION span in the telemetry stream. The consolidation report highlights merged facts, resolved contradictions, and a unified consensus state across the entire agent swarm.',
      actionLabel: 'Trigger REM Dreaming Consolidation',
      actionId: 'action-era6-trigger-dreaming',
      isDestructive: false,
      expectedSpanAction: 'DREAM_CONSOLIDATION',
    ),
  ];

  /// Returns the architectural definition and sample pipeline for the requested era ID.
  /// Gracefully falls back to aliased names and fuzzy matches.
  static EraArchitecture getArchitecture(String eraId) {
    if (_catalog.containsKey(eraId)) {
      return _catalog[eraId]!;
    }

    // Support project aliases
    if (eraId == 'era-2017-threads' || eraId.contains('2017')) {
      return _catalog['era-2017-threads']!;
    }
    if (eraId == 'era-2026-mesh' || eraId.contains('2026')) {
      return _catalog['era-2026-agent-mesh']!;
    }
    if (eraId.contains('1988') || eraId.contains('irc')) {
      return _catalog['era-1988-irc']!;
    }
    if (eraId.contains('1997') || eraId.contains('aim')) {
      return _catalog['era-1997-aim']!;
    }
    if (eraId.contains('2006') || eraId.contains('jabber')) {
      return _catalog['era-2006-jabber']!;
    }
    if (eraId.contains('2013') || eraId.contains('hipchat')) {
      return _catalog['era-2013-hipchat']!;
    }

    return _catalog['era-1988-irc']!;
  }

  /// Returns the tradeoff evaluation for the requested era ID.
  /// Gracefully falls back to aliased names and fuzzy matches.
  static EraTradeoff getTradeoff(String eraId) {
    if (eraTradeoffs.containsKey(eraId)) {
      return eraTradeoffs[eraId]!;
    }

    if (eraId == 'era-2017-threads' || eraId.contains('2017')) {
      return eraTradeoffs['era-2017-threads']!;
    }
    if (eraId == 'era-2026-mesh' || eraId.contains('2026')) {
      return eraTradeoffs['era-2026-agent-mesh']!;
    }
    if (eraId.contains('1988') || eraId.contains('irc')) {
      return eraTradeoffs['era-1988-irc']!;
    }
    if (eraId.contains('1997') || eraId.contains('aim')) {
      return eraTradeoffs['era-1997-aim']!;
    }
    if (eraId.contains('2006') || eraId.contains('jabber')) {
      return eraTradeoffs['era-2006-jabber']!;
    }
    if (eraId.contains('2013') || eraId.contains('hipchat')) {
      return eraTradeoffs['era-2013-hipchat']!;
    }

    return eraTradeoffs['era-1988-irc']!;
  }

  /// All 6 historical era architecture models in chronological order.
  static List<EraArchitecture> get allArchitectures => [
    _catalog['era-1988-irc']!,
    _catalog['era-1997-aim']!,
    _catalog['era-2006-jabber']!,
    _catalog['era-2013-hipchat']!,
    _catalog['era-2017-threads']!,
    _catalog['era-2026-agent-mesh']!,
  ];
}
