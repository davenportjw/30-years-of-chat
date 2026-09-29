import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/sepia_theme.dart';

class MemoryLensDrawer extends StatefulWidget {
  final Message? selectedMessage;
  final Channel channel;
  final Era? era;
  final MemoryBuffer? buffer;
  final List<ConsolidationReport> consolidationReports;
  final PrivateScratchpad? scratchpad;
  final VoidCallback onClose;
  final Function(String title, String details) onInjectEvent;
  final Future<void> Function()? onTriggerDreaming;
  final bool isDreaming;

  const MemoryLensDrawer({
    super.key,
    required this.selectedMessage,
    required this.channel,
    this.era,
    this.buffer,
    this.consolidationReports = const [],
    this.scratchpad,
    required this.onClose,
    required this.onInjectEvent,
    this.onTriggerDreaming,
    this.isDreaming = false,
  });

  @override
  State<MemoryLensDrawer> createState() => _MemoryLensDrawerState();
}

class _MemoryLensDrawerState extends State<MemoryLensDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _eventTitleCtrl = TextEditingController();
  final TextEditingController _eventDetailsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventTitleCtrl.dispose();
    _eventDetailsCtrl.dispose();
    super.dispose();
  }

  void _triggerCustom() {
    final title = _eventTitleCtrl.text.trim();
    final details = _eventDetailsCtrl.text.trim();
    if (title.isEmpty || details.isEmpty) return;
    widget.onInjectEvent(title, details);
    _eventTitleCtrl.clear();
    _eventDetailsCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: SepiaTheme.surface,
        border: Border(left: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: SepiaTheme.card,
              border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 20, color: SepiaTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Memory Lens Inspector',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: SepiaTheme.textSecondary),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: SepiaTheme.primary,
            unselectedLabelColor: SepiaTheme.textMuted,
            indicatorColor: SepiaTheme.primary,
            labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Concept'),
              Tab(text: 'Anatomy'),
              Tab(text: 'Dreaming'),
              Tab(text: 'Scratchpad'),
              Tab(text: 'Events'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConceptTab(),
                _buildAnatomyTab(),
                _buildDreamingTab(),
                _buildScratchpadTab(),
                _buildEventsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Concept Tab
  Widget _buildConceptTab() {
    final era = widget.era;
    final msg = widget.selectedMessage;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: 'COGNITIVE PARADIGM'),
        const SizedBox(height: 8),
        if (era != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SepiaTheme.primaryLight,
              border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SepiaTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${era.year}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        era.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  era.memoryConcept,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  era.description,
                  style: const TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textSecondary),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        _SectionTitle(title: 'SELECTED MESSAGE INTENT MAPPING'),
        const SizedBox(height: 8),
        _buildMappingCard(msg),
      ],
    );
  }

  // 2. Anatomy Tab
  Widget _buildAnatomyTab() {
    final msg = widget.selectedMessage;
    final buf = widget.buffer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: 'SHORT-TERM MEMORY BUFFER (FIFO)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SepiaTheme.card,
            border: Border.all(color: SepiaTheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active Channel Buffer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    widget.channel.maxBufferTurns > 0
                        ? '${buf?.currentTurns ?? 0} / ${widget.channel.maxBufferTurns} turns'
                        : 'Infinite Append-Only Log',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: widget.channel.maxBufferTurns > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: widget.channel.maxBufferTurns > 0
                    ? ((buf?.currentTurns ?? 0) / widget.channel.maxBufferTurns).clamp(0.0, 1.0)
                    : 1.0,
                backgroundColor: SepiaTheme.border,
                color: widget.channel.maxBufferTurns > 0 ? Colors.amber.shade700 : SepiaTheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Displaced Turns: ${buf?.evictedCount ?? 0}',
                style: const TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _SectionTitle(title: 'TOKEN ECONOMY & WINDOW USAGE'),
        const SizedBox(height: 8),
        _buildTokenMeter(msg),

        const SizedBox(height: 16),
        _SectionTitle(title: 'LONG-TERM MEMORY (VECTOR SEARCH RAG)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SepiaTheme.card,
            border: Border.all(color: SepiaTheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vector Search RAG (Exact Cosine Distance)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                '• Dimension: 16-d semantic embeddings\n'
                '• Distance Metric: COSINE (Exact Distance = 1.0 - CosineSimilarity)\n'
                '• Search Isolation: Domain-partitioned per channel to eliminate prompt contamination\n'
                '• Grounding: ADRs and historical incident post-mortems injected as external memory',
                style: TextStyle(fontSize: 11, height: 1.45, color: SepiaTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Dreaming Tab
  Widget _buildDreamingTab() {
    final reports = widget.consolidationReports;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: 'DREAMING & MEMORY CONSOLIDATION'),
        const SizedBox(height: 6),
        const Text(
          'Offline reflection: Prunes episodic chatter into durable semantic memory.',
          style: TextStyle(fontSize: 11.5, color: SepiaTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: widget.isDreaming
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.nightlight_round, size: 16),
          label: Text(
            widget.isDreaming ? 'Consolidating Channel Memory...' : 'Trigger Live Dreaming Consolidation',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: SepiaTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: widget.isDreaming ? null : widget.onTriggerDreaming,
        ),

        const SizedBox(height: 16),
        _SectionTitle(title: 'LATEST CONSOLIDATION REPORTS'),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const Text(
            'No consolidation reports yet for this channel.',
            style: TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
          )
        else
          ...reports.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SepiaTheme.card,
                  border: Border.all(color: SepiaTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pruned ${r.prunedMessages} Turns',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                        Text(
                          '${r.completedAt.hour.toString().padLeft(2, '0')}:${r.completedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10.5, color: SepiaTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.insightSummary,
                      style: const TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textPrimary),
                    ),
                    if (r.distilledFacts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Distilled Durable Facts:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      ...r.distilledFacts.map((fact) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: SepiaTheme.primary)),
                                Expanded(
                                  child: Text(fact, style: const TextStyle(fontSize: 10.5, color: SepiaTheme.textSecondary)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              )),
      ],
    );
  }

  // 4. Scratchpad Tab
  Widget _buildScratchpadTab() {
    final pad = widget.scratchpad;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: 'DUAL-LAYER MEMORY: PRIVATE SCRATCHPAD'),
        const SizedBox(height: 8),
        const Text(
          'Collaborative multi-agent mesh uses dual-layer memory: a shared team blackboard (the public channel) alongside private agent scratchpads (inner monologue, draft plans, and raw tool traces) that are never exposed publicly.',
          style: TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (pad == null)
          const Text(
            'No active scratchpad state found for this agent in this channel.',
            style: TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SepiaTheme.card,
              border: Border.all(color: SepiaTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Agent: ${pad.agentId}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                    ),
                    const Text('Confidential Inner Thoughts', style: TextStyle(fontSize: 10, color: Colors.amber)),
                  ],
                ),
                if (pad.draftPlan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Active Draft Plan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(pad.draftPlan, style: const TextStyle(fontSize: 11.5, color: SepiaTheme.textPrimary)),
                ],
                if (pad.innerThoughts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Inner Monologue Stream:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...pad.innerThoughts.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('💭 $t', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: SepiaTheme.textSecondary)),
                      )),
                ],
                if (pad.toolTraces.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Raw Tool Invocations:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...pad.toolTraces.map((tr) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('⚙️ $tr', style: const TextStyle(fontSize: 10, fontFamily: 'Courier', color: SepiaTheme.textMuted)),
                      )),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 5. Events Tab
  Widget _buildEventsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: 'PRE-CONFIGURED OPERATIONAL EVENTS'),
        const SizedBox(height: 8),
        _PresetEventButton(
          title: '🚨 Sentry Alert: P99 Latency Breach',
          subtitle: 'Checkout API p99 reached 820ms (threshold 300ms)',
          onTap: () => widget.onInjectEvent(
            'Sentry Alert: P99 Latency Breach',
            'checkout-service latency spike detected across 4 pods. Database read locks elevated.',
          ),
        ),
        const SizedBox(height: 8),
        _PresetEventButton(
          title: '📦 Pull Request Ready for Review',
          subtitle: 'PR-402: Add transactional outbox table',
          onTap: () => widget.onInjectEvent(
            'Pull Request Ready: PR-402',
            'Staff Architect opened PR-402 proposing transactional outbox to decouple message publishing.',
          ),
        ),
        const SizedBox(height: 8),
        _PresetEventButton(
          title: '🔥 Distributed 2PC Deadlock Warning',
          subtitle: 'Distributed lock deadlock detected on order_ledger',
          onTap: () => widget.onInjectEvent(
            'Distributed Transaction Lock Deadlock',
            'Deadlock detected during concurrent mutations on order_ledger and outbox_events. Requires immediate resolution.',
          ),
        ),

        const SizedBox(height: 16),
        _SectionTitle(title: 'CUSTOM EVENT INJECTION'),
        const SizedBox(height: 8),
        TextField(
          controller: _eventTitleCtrl,
          decoration: const InputDecoration(
            hintText: 'Event Title (e.g. Datadog Alert)',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _eventDetailsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Details / Telemetry payload...',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: SepiaTheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _triggerCustom,
          child: const Text('Inject Event into Stream'),
        ),
      ],
    );
  }

  Widget _buildMappingCard(Message? msg) {
    String chatPattern = 'Scoped Channels';
    String agentConcept = 'Domain-Specific Working Context';
    String explanation =
        'Channels prevent context pollution. Agents only retain memories and tools relevant to #${widget.channel.name}.';

    if (msg != null && msg.intentTags.isNotEmpty) {
      final tag = msg.intentTags.first;
      switch (tag.type) {
        case 'compaction':
          chatPattern = 'Summaries & Compaction';
          agentConcept = 'Hierarchical State Rollups & Token Pruning';
          explanation =
              'Scribe agent compresses past event turns into a state checkpoint, preventing context window exhaustion without loss of critical facts.';
          break;
        case 'vector_hit':
          chatPattern = 'Search / Long-Term History';
          agentConcept = 'Vector Search RAG (External Memory)';
          explanation =
              'Researcher agent retrieves historical ADRs and past post-mortems using vector search (cosine distance) without dumping full docs into context.';
          break;
        case 'permission':
          chatPattern = 'Context Fencing & Firewalls';
          agentConcept = 'Search Isolation & Role Boundaries';
          explanation =
              'Permissions and context boundaries prevent unauthorized agent knowledge bleed between sensitive project channels.';
          break;
        default:
          chatPattern = 'Short-Term Buffer';
          agentConcept = 'Active Working Context';
          explanation = 'Direct message turns processed by Gemini 3.8 as immediate working memory.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.card,
        border: Border.all(color: SepiaTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_forward_ios, size: 12, color: SepiaTheme.primary),
              const SizedBox(width: 6),
              Text(
                chatPattern,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cognitive Architecture: $agentConcept',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: SepiaTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: const TextStyle(fontSize: 11, height: 1.4, color: SepiaTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenMeter(Message? msg) {
    int tokenCount = msg?.tokenCount ?? 180;
    int maxContext = 8192;
    double percentage = (tokenCount / maxContext).clamp(0.01, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.card,
        border: Border.all(color: SepiaTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Working Turn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('$tokenCount tokens', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: SepiaTheme.border,
            color: SepiaTheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            'Window capacity: ${(percentage * 100).toStringAsFixed(1)}% of 8k turn budget utilized.',
            style: const TextStyle(fontSize: 10.5, color: SepiaTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: SepiaTheme.textMuted,
      ),
    );
  }
}

class _PresetEventButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PresetEventButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SepiaTheme.card,
          border: Border.all(color: SepiaTheme.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: SepiaTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
