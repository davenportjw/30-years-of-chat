import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../theme/sepia_theme.dart';

/// AgentMeshView implements the Academic Sepia 3-panel workspace for the 2026 Collaborative Multi-Agent Mesh.
///
/// Layout:
/// - Left: Multi-Agent Swarm Roster with live presence and status indicators.
/// - Center: Stream with Intent Pills, quick action chips, and composer.
/// - Right: 5-tab Memory Lens Drawer (Concept, Anatomy, Dreaming, Private Scratchpad, Events).
///
/// Memory Concept:
/// - Dual-Layer Memory: Shared Blackboard vs Private Inner Monologue
/// - Private scratchpads isolate raw tool traces and internal planning
/// - Dreaming Consolidation: Offline pruning of episodic chatter into durable semantic memory.
class AgentMeshView extends StatefulWidget {
  final List<Channel> channels;
  final Channel selectedChannel;
  final Function(Channel) onSelectChannel;
  final List<Message> messages;
  final List<AgentPresence> presences;
  final MemoryBuffer? buffer;
  final List<ConsolidationReport> consolidationReports;
  final PrivateScratchpad? scratchpad;
  final Function(String) onSendMessage;
  final Function(String, String) onInjectEvent;
  final Future<void> Function()? onTriggerDreaming;
  final bool isDreaming;
  final String? typingAgentName;
  final Function(AgentPresence)? onUpdatePresence;
  final Function(Message)? onSelectMessage;
  final bool initialDrawerOpen;

  const AgentMeshView({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.onSelectChannel,
    required this.messages,
    required this.presences,
    this.buffer,
    required this.consolidationReports,
    this.scratchpad,
    required this.onSendMessage,
    required this.onInjectEvent,
    this.onTriggerDreaming,
    required this.isDreaming,
    this.typingAgentName,
    this.onUpdatePresence,
    this.onSelectMessage,
    this.initialDrawerOpen = false,
  });

  /// Deduplicates beliefs by normalized key (`b.key.toLowerCase().trim()`).
  /// Maintains insertion/recency order using a `Map<String, CrystallizedBelief>`.
  /// If a key already exists, updates it if the newer belief has higher confidence
  /// or comes from a more recent report.
  static List<CrystallizedBelief> deduplicateBeliefs(
    List<CrystallizedBelief> beliefs, {
    Map<String, DateTime>? reportDates,
  }) {
    final Map<String, CrystallizedBelief> uniqueBeliefs = {};
    final Map<String, DateTime> dates = {};

    for (final b in beliefs) {
      final normKey = b.key.toLowerCase().trim();
      if (normKey.isEmpty) continue;

      final bDate = reportDates?[normKey];

      if (!uniqueBeliefs.containsKey(normKey)) {
        uniqueBeliefs[normKey] = b;
        if (bDate != null) dates[normKey] = bDate;
      } else {
        final existing = uniqueBeliefs[normKey]!;
        final existingDate = dates[normKey];

        bool shouldUpdate = false;
        if (bDate != null && existingDate != null) {
          if (bDate.isAfter(existingDate)) {
            shouldUpdate = true;
          } else if (bDate.isAtSameMomentAs(existingDate)) {
            if (b.confidence > existing.confidence) {
              shouldUpdate = true;
            }
          }
        } else {
          if (b.confidence > existing.confidence) {
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          uniqueBeliefs[normKey] = b;
          if (bDate != null) dates[normKey] = bDate;
        }
      }
    }

    return uniqueBeliefs.values.toList();
  }

  /// Extracts and deduplicates crystallized beliefs from consolidation reports.
  static List<CrystallizedBelief> extractCrystallizedBeliefs(List<ConsolidationReport> reports) {
    final Map<String, CrystallizedBelief> uniqueBeliefs = {};
    final Map<String, DateTime> reportDates = {};

    for (final r in reports) {
      List<CrystallizedBelief> reportBeliefs = [];
      if (r.crystallizedBeliefs.isNotEmpty) {
        reportBeliefs = r.crystallizedBeliefs.map((b) {
          if (b.generatedAt == null) {
            return b.copyWith(generatedAt: r.completedAt);
          }
          return b;
        }).toList();
      } else if (r.distilledFacts.isNotEmpty) {
        for (int i = 0; i < r.distilledFacts.length; i++) {
          final fact = r.distilledFacts[i];
          String cat = 'Architecture';
          final lower = fact.toLowerCase();
          if (lower.contains('auth') || lower.contains('security') || lower.contains('scratchpad')) {
            cat = 'Security';
          } else if (lower.contains('database') || lower.contains('bigquery') || lower.contains('vector') || lower.contains('cosine')) {
            cat = 'Database';
          } else if (lower.contains('cloud run') || lower.contains('terraform') || lower.contains('deploy')) {
            cat = 'Infrastructure';
          }
          final words = fact.split(RegExp(r'\s+'));
          final kw = words
              .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))
              .where((w) => w.length > 3)
              .take(4)
              .toList();

          reportBeliefs.add(CrystallizedBelief(
            key: 'belief_${r.id}_${i + 1}',
            value: fact,
            category: cat,
            confidence: 0.95 + (i * 0.01).clamp(0.0, 0.04),
            keywords: kw,
            statement: fact,
            generatedAt: r.completedAt,
          ));
        }
      }

      for (final b in reportBeliefs) {
        final normKey = b.key.toLowerCase().trim();
        if (normKey.isEmpty) continue;

        if (!uniqueBeliefs.containsKey(normKey)) {
          uniqueBeliefs[normKey] = b;
          reportDates[normKey] = r.completedAt;
        } else {
          final existing = uniqueBeliefs[normKey]!;
          final existingDate = reportDates[normKey];

          final isMoreRecent = existingDate == null || r.completedAt.isAfter(existingDate);
          final isSameDate = existingDate != null && r.completedAt.isAtSameMomentAs(existingDate);
          final hasHigherConfidence = b.confidence > existing.confidence;

          if (isMoreRecent || (isSameDate && hasHigherConfidence)) {
            uniqueBeliefs[normKey] = b;
            reportDates[normKey] = r.completedAt;
          }
        }
      }
    }

    if (uniqueBeliefs.isEmpty) {
      final now = DateTime.now();
      final defaults = [
        CrystallizedBelief(
          key: 'sec_auth_adc',
          value: 'ADC auth is mandatory for Vertex AI Gemini 3.8 calls in davenport-boutique',
          category: 'Security',
          confidence: 0.99,
          keywords: ['ADC', 'Vertex AI', 'Gemini 3.8', 'Auth', 'Zero-Trust'],
          statement: 'ADC auth is mandatory for Vertex AI Gemini 3.8 calls in davenport-boutique.',
          generatedAt: now.subtract(const Duration(minutes: 25)),
        ),
        CrystallizedBelief(
          key: 'db_vector_search',
          value: 'BigQuery vector indexing uses COSINE distance via ML.DISTANCE',
          category: 'Database',
          confidence: 0.98,
          keywords: ['BigQuery', 'Vector Index', 'Cosine', 'ML.DISTANCE', 'Fast-Path'],
          statement: 'BigQuery vector indexing uses COSINE distance via ML.DISTANCE for sub-15ms fast-path recall.',
          generatedAt: now.subtract(const Duration(minutes: 20)),
        ),
        CrystallizedBelief(
          key: 'arch_scribe_compaction',
          value: 'Scribe compaction achieves -96% token reduction on threads',
          category: 'Architecture',
          confidence: 0.96,
          keywords: ['Scribe', 'Compaction', 'Token Reduction', 'Rollup'],
          statement: 'Scribe compaction achieves -96% token reduction on threads without semantic degradation.',
          generatedAt: now.subtract(const Duration(minutes: 15)),
        ),
        CrystallizedBelief(
          key: 'infra_cloud_run',
          value: 'Standardize deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8',
          category: 'Infrastructure',
          confidence: 0.97,
          keywords: ['Cloud Run', 'Terraform', 'BigQuery', 'Gemini 3.8'],
          statement: 'Swarm consensus: Standardize deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8.',
          generatedAt: now.subtract(const Duration(minutes: 10)),
        ),
      ];
      for (final d in defaults) {
        uniqueBeliefs[d.key.toLowerCase().trim()] = d;
      }
    }

    return uniqueBeliefs.values.toList();
  }

  @override
  State<AgentMeshView> createState() => _AgentMeshViewState();
}

class _AgentMeshViewState extends State<AgentMeshView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _eventTitleCtrl = TextEditingController();
  final TextEditingController _eventDetailsCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _msgFocusNode = FocusNode();
  bool _isSending = false;

  late bool _isDrawerOpen;
  Message? _highlightedMessage;

  // 2026 Interactive Playback Tour State
  bool _isTourActive = false;
  int _tourStep = 1;
  bool _isAutoPlay = false;
  Timer? _autoPlayTimer;
  bool _isPromptInspectorExpanded = false;

  @override
  void initState() {
    super.initState();
    _isDrawerOpen = widget.initialDrawerOpen;
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void didUpdateWidget(covariant AgentMeshView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _tabController.dispose();
    _msgController.dispose();
    _msgFocusNode.dispose();
    _eventTitleCtrl.dispose();
    _eventDetailsCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startOrToggleTour() {
    if (_isTourActive) {
      _closeTour();
    } else {
      setState(() {
        _isTourActive = true;
        _tourStep = 1;
      });
      _executeTourStep(1);
      if (_isAutoPlay) {
        _startAutoPlayTimer();
      }
    }
  }

  void _closeTour() {
    _autoPlayTimer?.cancel();
    setState(() {
      _isTourActive = false;
      _isAutoPlay = false;
    });
  }

  void _goToTourStep(int step) {
    if (step < 1 || step > 5) return;
    setState(() {
      _tourStep = step;
    });
    _executeTourStep(step);
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
    });
    _autoPlayTimer?.cancel();
    if (_isAutoPlay) {
      _startAutoPlayTimer();
    }
  }

  void _startAutoPlayTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!_isTourActive) {
        timer.cancel();
        return;
      }
      if (_tourStep < 5) {
        _goToTourStep(_tourStep + 1);
      } else {
        timer.cancel();
        setState(() {
          _isAutoPlay = false;
        });
      }
    });
  }

  void _executeTourStep(int step) {
    switch (step) {
      case 1:
        // Step 1: Waking Swarm Dialogue (Auto-posts Pill 1)
        const pill1Text = "Swarm consensus: Standardize deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8.";
        widget.onSendMessage(pill1Text);
        break;
      case 2:
        // Step 2: Private Monologue & Tool Execution (Auto-posts Pill 2, switches to Tab 3 Scratchpad)
        const pill2Text = "Security constraint: Zero-trust credentials, auth tokens, and raw tool traces must remain strictly isolated inside private scratchpads.";
        widget.onSendMessage(pill2Text);
        _focusDrawerTab(3);
        break;
      case 3:
        // Step 3: REM Sleep Dreaming Consolidation (Auto-posts dreaming dialogue, triggers live dreaming, switches to Tab 2)
        const pill3Text = "Triggering REM dreaming consolidation cycle across active channel buffer.";
        widget.onSendMessage(pill3Text);
        _focusDrawerTab(2);
        if (widget.onTriggerDreaming != null) {
          widget.onTriggerDreaming!();
        }
        break;
      case 4:
        // Step 4: Crystalline Memory Lens Inspection (Auto-posts inspection dialogue, switches to Tab 2 Dreaming)
        const pill4InspectText = "Reviewing crystallized architectural invariants and durable semantic beliefs in Crystalline Store.";
        widget.onSendMessage(pill4InspectText);
        _focusDrawerTab(2);
        break;
      case 5:
        // Step 5: Fast-Path Crystalline Recall (Auto-posts Pill 4 recall probe, verifies instant response)
        const pill4Text = "What deployment stack and security policies did the multi-agent swarm establish?";
        widget.onSendMessage(pill4Text);
        break;
    }
  }

  Future<void> _handleSend() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgController.clear();
    try {
      await widget.onSendMessage(text);
    } catch (e) {
      if (mounted) {
        _msgController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }


  void _handleInjectCustomEvent() {
    final title = _eventTitleCtrl.text.trim();
    final details = _eventDetailsCtrl.text.trim();
    if (title.isEmpty || details.isEmpty) return;
    widget.onInjectEvent(title, details);
    _eventTitleCtrl.clear();
    _eventDetailsCtrl.clear();
  }

  void _selectMessage(Message msg) {
    setState(() {
      _highlightedMessage = msg;
      _isDrawerOpen = true;
    });
    // Dynamically focus matching Memory Lens Tab based on memory intent tags
    if (msg.intentTags.any((t) => t.type == 'crystalline_hit')) {
      _tabController.animateTo(2); // Tab 2: Dreaming / Crystalline
    } else if (msg.intentTags.any((t) => t.type == 'compaction')) {
      _tabController.animateTo(1); // Tab 1: Anatomy / Compaction
    } else if (msg.intentTags.any((t) => t.type == 'permission' || t.type == 'context')) {
      _tabController.animateTo(0); // Tab 0: Concept
    }
    if (widget.onSelectMessage != null) {
      widget.onSelectMessage!(msg);
    }
  }

  void _focusDrawerTab(int tabIndex, {Message? msg}) {
    setState(() {
      _isDrawerOpen = true;
      if (msg != null) _highlightedMessage = msg;
    });
    _tabController.animateTo(tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SepiaTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final drawerWidth = (constraints.maxWidth * 0.38).clamp(320.0, 440.0);
          return Row(
            children: [
              // 1. Left Panel: Multi-Agent Swarm Roster (280px)
              _buildSwarmRosterPanel(),

              // 2. Center Panel: Shared Blackboard Stream (Flex: 1)
              Expanded(
                child: _buildSharedBlackboardPanel(),
              ),

              // 3. Right Panel: 5-Tab Memory Lens Drawer
              if (_isDrawerOpen)
                _buildMemoryLensDrawerPanel(drawerWidth),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 1. Left Panel: Multi-Agent Swarm Roster
  // ==========================================
  Widget _buildSwarmRosterPanel() {
    final onlineCount = widget.presences.where((p) => p.status == 'available' || p.status == 'typing').length;

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: SepiaTheme.card,
        border: Border(right: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Swarm Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: SepiaTheme.surface,
              border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub, size: 20, color: SepiaTheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Multi-Agent Swarm',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: SepiaTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Text(
                    '$onlineCount Online',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),

          // Channel Navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Channels',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: SepiaTheme.textMuted,
              ),
            ),
          ),
          ...widget.channels.where((c) => c.eraId == 'era-2026-agent-mesh' || c.id == widget.selectedChannel.id).map((c) {
            final isSelected = c.id == widget.selectedChannel.id;
            return InkWell(
              onTap: () => widget.onSelectChannel(c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? SepiaTheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected ? Border.all(color: SepiaTheme.borderStrong) : null,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag, size: 14, color: SepiaTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: SepiaTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          const Divider(height: 1, color: SepiaTheme.border),

          // Swarm Agents List
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agents (${widget.presences.length})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: SepiaTheme.textMuted,
                  ),
                ),
                const Icon(Icons.psychology, size: 14, color: SepiaTheme.primary),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: widget.presences.length,
              itemBuilder: (context, index) {
                final presence = widget.presences[index];
                return _buildAgentPresenceCard(presence);
              },
            ),
          ),

          // Dreaming Quick Trigger in Sidebar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: SepiaTheme.surface,
              border: Border(top: BorderSide(color: SepiaTheme.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: widget.isDreaming
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.nightlight_round, size: 14),
                  label: Text(
                    widget.isDreaming ? 'Consolidating...' : 'Trigger Live Dreaming',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SepiaTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: widget.isDreaming ? null : widget.onTriggerDreaming,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPresenceCard(AgentPresence p) {
    Color statusColor;
    String statusText;

    switch (p.status) {
      case 'typing':
        statusColor = Colors.blue;
        statusText = 'Typing...';
        break;
      case 'away':
        statusColor = Colors.amber.shade700;
        statusText = 'Away';
        break;
      case 'dnd':
        statusColor = Colors.red;
        statusText = 'Do Not Disturb';
        break;
      case 'dreaming':
        statusColor = Colors.purple;
        statusText = 'Dreaming Consolidation';
        break;
      default:
        statusColor = Colors.green;
        statusText = 'Available';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SepiaTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tooltip(
                message: statusText,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  p.agentName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (p.statusMessage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              p.statusMessage,
              style: const TextStyle(fontSize: 11, color: SepiaTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (p.currentTask.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.arrow_right, size: 14, color: SepiaTheme.accent),
                Expanded(
                  child: Text(
                    p.currentTask,
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: SepiaTheme.accent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 2. Center Panel: Shared Blackboard Stream
  // ==========================================
  Widget _buildSharedBlackboardPanel() {
    return Column(
      children: [
        // Center Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: SepiaTheme.surface,
            border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tag, size: 18, color: SepiaTheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.selectedChannel.name,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.card,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_outlined, size: 11, color: SepiaTheme.primary),
                    SizedBox(width: 4),
                    Text(
                      'BLACKBOARD',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Prominent "▶ Run 2026 Tour" button
              InkWell(
                onTap: _startOrToggleTour,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isTourActive ? SepiaTheme.primary : SepiaTheme.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isTourActive ? SepiaTheme.primary : SepiaTheme.borderStrong,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTourActive ? Icons.pause_circle_filled : Icons.play_arrow,
                        size: 13,
                        color: _isTourActive ? Colors.white : SepiaTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isTourActive ? 'Tour Active ($_tourStep/5)' : '▶ Run 2026 Tour',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isTourActive ? Colors.white : SepiaTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.selectedChannel.topic.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.selectedChannel.topic,
                    style: const TextStyle(fontSize: 11.5, color: SepiaTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isDrawerOpen ? Icons.menu_open : Icons.psychology_outlined,
                  size: 20,
                  color: SepiaTheme.primary,
                ),
                tooltip: _isDrawerOpen ? 'Close Memory Lens Drawer' : 'Open Memory Lens Drawer',
                onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
              ),
            ],
          ),
        ),

        // Guided 2026 Multi-Agent Mesh Tour Controller Banner
        if (_isTourActive) _buildTourControllerBanner(),

        // Progressive Quick Prompts Pill Bar
        _buildProgressiveQuickPromptsBar(),

        // Message Stream with Intent Pills
        Expanded(
          child: widget.messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages in the shared blackboard stream.\nUse the action chips or composer below to coordinate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SepiaTheme.textMuted),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final msg = widget.messages[index];
                    return _SepiaMessageCard(
                      message: msg,
                      onSelect: () => _selectMessage(msg),
                      onInspectConcept: () => _focusDrawerTab(0, msg: msg),
                      onInspectCompaction: () => _focusDrawerTab(1, msg: msg),
                    );
                  },
                ),
        ),

        // Typing Indicator
        if (widget.typingAgentName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: SepiaTheme.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.typingAgentName} is coordinating with multi-agent swarm via Gemini 3.8...',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: SepiaTheme.textSecondary),
                ),
              ],
            ),
          ),

        // Message Composer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: SepiaTheme.surface,
            border: Border(top: BorderSide(color: SepiaTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  focusNode: _msgFocusNode,
                  onSubmitted: (_) => _handleSend(),
                  style: const TextStyle(fontSize: 13.5, color: SepiaTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Message #${widget.selectedChannel.name} (Shared Blackboard)...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: SepiaTheme.textMuted),
                    filled: true,
                    fillColor: SepiaTheme.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: SepiaTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: SepiaTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: SepiaTheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: _isSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 14),
                label: Text(_isSending ? 'Posting...' : 'Post', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SepiaTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _isSending ? null : _handleSend,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // Progressive Quick Prompts Pill Bar (4 Sequential Scenario Pills)
  // ==============================================================
  Widget _buildProgressiveQuickPromptsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: SepiaTheme.card,
        border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Scenario Pills: ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SepiaTheme.textSecondary),
            ),
            const SizedBox(width: 4),
            _buildScenarioPill(
              label: '1. Onboarding Stack',
              tooltip: 'Pill 1 (Onboarding Stack): Immediately posts swarm consensus on Google Cloud Run, Terraform, and BigQuery with Gemini 3.8.',
              icon: Icons.hub_outlined,
              onTap: () => widget.onSendMessage(
                'Swarm consensus: Standardize deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8.',
              ),
            ),
            _buildScenarioPill(
              label: '2. Security Boundary',
              tooltip: 'Pill 2 (Security Boundary): Immediately posts security constraint for zero-trust credentials and private scratchpad isolation.',
              icon: Icons.shield_outlined,
              onTap: () => widget.onSendMessage(
                'Security constraint: Zero-trust credentials, auth tokens, and raw tool traces must remain strictly isolated inside private scratchpads.',
              ),
            ),
            _buildScenarioPill(
              label: '3. Trigger Dreaming',
              tooltip: 'Pill 3 (Trigger Dreaming): Immediately executes live offline REM dreaming consolidation cycle and switches to Crystalline Memory tab.',
              icon: Icons.nightlight_round,
              isHighlighted: widget.isDreaming,
              onTap: () {
                _focusDrawerTab(2);
                if (widget.onTriggerDreaming != null) {
                  widget.onTriggerDreaming!();
                }
              },
            ),
            _buildScenarioPill(
              label: '4. Recall Probe',
              tooltip: 'Pill 4 (Recall Probe): Immediately posts recall probe for deployment stack and security policies.',
              icon: Icons.bolt,
              onTap: () => widget.onSendMessage(
                'What deployment stack and security policies did the multi-agent swarm establish?',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioPill({
    required String label,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: '$tooltip\n(Click to execute immediately in chat)',
        waitDuration: const Duration(milliseconds: 250),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isHighlighted ? SepiaTheme.primaryLight : SepiaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHighlighted ? SepiaTheme.primary : SepiaTheme.borderStrong,
                width: isHighlighted ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isHighlighted ? SepiaTheme.primary : SepiaTheme.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                    color: isHighlighted ? SepiaTheme.primary : SepiaTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.play_arrow_rounded,
                  size: 13,
                  color: isHighlighted ? SepiaTheme.primary : SepiaTheme.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // Interactive 2026 Demo Playback Tour Controller Banner
  // ==============================================================
  Widget _buildTourControllerBanner() {
    final stepTitles = [
      'Waking Swarm Dialogue',
      'Private Monologue & Tool Execution',
      'REM Sleep Dreaming Consolidation',
      'Crystalline Memory Lens Inspection',
      'Fast-Path Crystalline Recall',
    ];

    final stepDescriptions = [
      'Swarm consensus reached across Lead, Scribe, and Researcher via Gemini 3.8.',
      'Scratchpad Isolation: Monologue and tool execution remain private with zero token leakage.',
      'Offline Dreaming: Pruning episodic noise and distilling durable architectural facts.',
      'Memory Lens: Real-time inspection of consolidated beliefs, confidence, and provenance.',
      'Fast-Path Recall: Sub-15ms vector retrieval without context bloat.',
    ];

    final stepBadges = [
      'Pill 1 Auto-Posted',
      'Tab 3 Focused: Zero Leakage',
      'Live Consolidation Pulse Active',
      'Tab 2 Focused: Crystalline Beliefs',
      'Pill 4 Recall Probe Auto-Posted',
    ];

    final title = stepTitles[_tourStep - 1];
    final desc = stepDescriptions[_tourStep - 1];
    final badge = stepBadges[_tourStep - 1];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SepiaTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SepiaTheme.primary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(Icons.explore, size: 18, color: SepiaTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2026 MULTI-AGENT MESH GUIDED TOUR (Step $_tourStep of 5)',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: SepiaTheme.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _isAutoPlay ? const Color(0xFFE8F5E9) : SepiaTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isAutoPlay ? const Color(0xFF81C784) : SepiaTheme.borderStrong,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isAutoPlay ? Icons.play_circle_filled : Icons.pause_circle_filled,
                      size: 11,
                      color: _isAutoPlay ? const Color(0xFF2E7D32) : SepiaTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isAutoPlay ? 'Auto-Play Active' : 'Manual Mode',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _isAutoPlay ? const Color(0xFF2E7D32) : SepiaTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: SepiaTheme.textMuted),
                tooltip: 'Close Tour',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _closeTour,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5 discrete stage chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(5, (index) {
                final stepNum = index + 1;
                final isCurrent = stepNum == _tourStep;
                final isPassed = stepNum < _tourStep;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _goToTourStep(stepNum),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? SepiaTheme.primary
                            : (isPassed ? SepiaTheme.primaryLight : SepiaTheme.card),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCurrent ? SepiaTheme.primary : SepiaTheme.borderStrong,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPassed)
                            const Icon(Icons.check, size: 11, color: SepiaTheme.primary)
                          else
                            Text(
                              '$stepNum. ',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Colors.white : SepiaTheme.textSecondary,
                              ),
                            ),
                          Text(
                            stepTitles[index].split(' ').take(2).join(' '),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? Colors.white : SepiaTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),

          // Current Stage Details Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Stage $_tourStep: $title',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SepiaTheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SepiaTheme.accent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SepiaTheme.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Navigation controls: [< Prev Step], [Next Step >], [Auto-Play Toggle], [Close Tour]
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.chevron_left, size: 14),
                label: const Text('< Prev Step', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SepiaTheme.primary,
                  side: const BorderSide(color: SepiaTheme.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: _tourStep > 1 ? () => _goToTourStep(_tourStep - 1) : null,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(_tourStep == 5 ? Icons.check_circle : Icons.chevron_right, size: 14),
                label: Text(
                  _tourStep == 5 ? 'Finish Tour' : 'Next Step >',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SepiaTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () {
                  if (_tourStep < 5) {
                    _goToTourStep(_tourStep + 1);
                  } else {
                    _closeTour();
                  }
                },
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: Icon(_isAutoPlay ? Icons.pause : Icons.play_arrow, size: 13),
                label: Text(_isAutoPlay ? 'Pause Auto-Play' : 'Auto-Play', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isAutoPlay ? const Color(0xFF2E7D32) : SepiaTheme.textSecondary,
                  side: BorderSide(
                    color: _isAutoPlay ? const Color(0xFF81C784) : SepiaTheme.border,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: _toggleAutoPlay,
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: SepiaTheme.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: _closeTour,
                child: const Text('Close Tour', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. Right Panel: 5-Tab Memory Lens Drawer
  // ==========================================
  Widget _buildMemoryLensDrawerPanel([double width = 440]) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: SepiaTheme.surface,
        border: Border(left: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: Column(
        children: [
          // Drawer Header
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
                  'Memory Lens Drawer',
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
                  onPressed: () => setState(() => _isDrawerOpen = false),
                ),
              ],
            ),
          ),

          // 5-Tab Bar: Concept, Anatomy, Dreaming, Private Scratchpad, Events
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

          // Tab Views
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

  // Tab 1: Concept
  Widget _buildConceptTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('DUAL-LAYER MEMORY ARCHITECTURE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SepiaTheme.primaryLight,
            border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2026: Collaborative Multi-Agent Mesh',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
              ),
              SizedBox(height: 4),
              Text(
                'Memory Concept: Dual-Layer Memory (Shared Blackboard vs Private Inner Monologue) & Dreaming Consolidation.',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: SepiaTheme.textPrimary),
              ),
              SizedBox(height: 6),
              Text(
                'In the modern era, agents collaborate without cross-talk pollution. The public channel acts as a shared blackboard for final outputs and consensus. Each agent maintains a private scratchpad containing raw tool traces, draft plans, and internal monologue.',
                style: TextStyle(fontSize: 11, height: 1.4, color: SepiaTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('ACTIVE MESSAGE INTENT INSPECTION'),
        const SizedBox(height: 8),
        _buildMessageIntentCard(_highlightedMessage ?? (widget.messages.isNotEmpty ? widget.messages.last : null)),
      ],
    );
  }

  // Tab 2: Anatomy
  Widget _buildAnatomyTab() {
    final buf = widget.buffer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('SHORT-TERM MEMORY BUFFER (FIFO)'),
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
                    widget.selectedChannel.maxBufferTurns > 0
                        ? '${buf?.currentTurns ?? 0} / ${widget.selectedChannel.maxBufferTurns} turns (Ephemeral RAM)'
                        : 'Infinite Append-Only Log',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: widget.selectedChannel.maxBufferTurns > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: widget.selectedChannel.maxBufferTurns > 0
                    ? ((buf?.currentTurns ?? 0) / widget.selectedChannel.maxBufferTurns).clamp(0.0, 1.0)
                    : 1.0,
                backgroundColor: SepiaTheme.border,
                color: widget.selectedChannel.maxBufferTurns > 0 ? Colors.amber.shade700 : SepiaTheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Displaced Turns (Evicted): ${buf?.evictedCount ?? 0}',
                style: const TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildSectionHeader('TOKEN BUDGET UTILIZATION'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Working Context Window:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('1,240 / 8,192 tokens', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary)),
                ],
              ),
              SizedBox(height: 6),
              LinearProgressIndicator(
                value: 1240 / 8192,
                backgroundColor: SepiaTheme.border,
                color: SepiaTheme.primary,
              ),
              SizedBox(height: 6),
              Text(
                '15.1% of turn budget utilized. Scribe compaction standing by to roll up threads.',
                style: TextStyle(fontSize: 10.5, color: SepiaTheme.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildSectionHeader('EPISODIC VECTOR SEARCH (APPROXIMATE RAG)'),
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
                children: [
                  const Icon(Icons.manage_search, size: 16, color: SepiaTheme.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'What Vector Search Is Actually Doing',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Vector search converts queries into semantic embeddings to retrieve relevant past episodic transcripts, ADR-019 architecture decision records, incident post-mortems, and historical channel conversations across historical channels.\n\n'
                '• Semantic Discovery: Uses high-dimensional embedding similarity to ground current reasoning in historical team decisions and incident retrospectives.\n'
                '• Cross-Channel Grounding: Locates relevant episodic transcripts across historical channels and archived team chatter.\n'
                '• Role & Scratchpad Fencing: Filters search spaces so credentials, internal auth tokens, and raw scratchpad tool traces are never exposed.\n'
                '• Search Engine: Google BigQuery ML.DISTANCE cosine distance over 16-d semantic embeddings.',
                style: TextStyle(fontSize: 11, height: 1.45, color: SepiaTheme.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildSectionHeader('LONG-TERM SEMANTIC MEMORY (CRYSTALLINE KNOWLEDGE STORE)'),
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
                children: [
                  const Icon(Icons.psychology, size: 16, color: SepiaTheme.accent),
                  const SizedBox(width: 6),
                  const Text(
                    'Durable Distilled Beliefs & Invariants',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Unlike approximate vector RAG (which retrieves unstructured text chunks that bloat the working context window), the Crystalline Knowledge Store holds durable, consolidated semantic invariants persisted in BigQuery.\n\n'
                '• Fast-Path Zero-Token Recall: Injected directly into prompts as structured architectural constraints and verified facts without bloating turn budgets or context windows.\n'
                '• Distilled Invariants: High-confidence rules, stack standardizations, and security boundaries synthesized during offline REM dreaming.\n'
                '• Fast Deterministic Matching: Direct key/concept indexing enables sub-15ms deterministic recall, whereas approximate vector similarity search requires distance calculations and reranking.\n'
                '• Durable Persistence: Backed by BigQuery long-term tables with audit trails, confidence scoring (>=95%), and explicit generation timestamps.',
                style: TextStyle(fontSize: 11, height: 1.45, color: SepiaTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Tab 2 (Index 2): Dreaming & Crystalline Memory
  // ==========================================
  Widget _buildDreamingTab() {
    final reports = widget.consolidationReports;
    final uniqueReports = <String, ConsolidationReport>{};
    for (final r in reports) {
      uniqueReports.putIfAbsent(r.id, () => r);
    }
    final reportList = uniqueReports.values.toList();
    final beliefs = _getCrystallizedBeliefs();

    String? dreamPrompt;
    for (final r in reportList) {
      if (r.dreamPromptUsed != null && r.dreamPromptUsed!.isNotEmpty) {
        dreamPrompt = r.dreamPromptUsed;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('DREAMING & MEMORY CONSOLIDATION'),
        const SizedBox(height: 8),
        const Text(
          'Dreaming is the offline reflection process where multi-agent swarms review episodic conversation logs, prune chatter and greetings, and crystallize durable architectural facts into permanent semantic memory.',
          style: TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        // Live Dreaming Pulse Banner (active when dreaming or during Tour Step 3)
        if (widget.isDreaming || (_isTourActive && _tourStep == 3)) ...[
          _buildDreamingPulseBanner(),
          const SizedBox(height: 12),
        ],

        // Live Dreaming Trigger Button
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

        // ⚡ Fast-Path Crystalline Recall Verification Card
        _buildFastPathRecallCard(),
        const SizedBox(height: 12),

        // 📜 REM Dream Synthesis Prompt Inspector
        _buildPromptInspectorCard(dreamPrompt),
        const SizedBox(height: 12),

        // 💾 BigQuery & Vector Store Card
        _buildDatabaseVectorStoreCard(),
        const SizedBox(height: 16),

        // Crystalline Belief Rows Section
        _buildSectionHeader('CRYSTALLIZED BELIEFS (LONG-TERM SEMANTIC MEMORY)'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '${beliefs.length} durable architectural facts crystallized with >=95% confidence:',
                style: const TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 10, color: Color(0xFF7B1FA2)),
                  SizedBox(width: 3),
                  Text(
                    'REM Dreaming (Gemini 3.8)',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCrystallineBeliefsTable(beliefs),

        const SizedBox(height: 16),
        _buildSectionHeader('CONSOLIDATION RUN HISTORY (${reportList.length})'),
        const SizedBox(height: 8),

        if (reportList.isEmpty)
          const Text(
            'No consolidation reports yet for this channel.\nClick "Trigger Live Dreaming Consolidation" above to run reflection.',
            style: TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
          )
        else
          ...reportList.map((r) => Container(
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
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: SepiaTheme.primary, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(fact, style: const TextStyle(fontSize: 11, color: SepiaTheme.textSecondary)),
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

  Widget _buildDreamingPulseBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFAB47BC), width: 1.5),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B1FA2)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REM SLEEP DREAMING CYCLE ACTIVE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
                ),
                SizedBox(height: 2),
                Text(
                  'Gemini 3.8 Flash offline consolidation in progress: pruning episodic chatter and crystallizing durable beliefs into BigQuery.',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF7B1FA2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastPathRecallCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, size: 16, color: SepiaTheme.accent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '⚡ Fast-Path Crystalline Recall',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                ),
              ),
              Text(
                'ZERO-TOKEN VECTOR LOOKUP',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SepiaTheme.accent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'High-confidence crystallized beliefs (>=95%) bypass linear LLM context window ingestion. Retrieval queries execute directly against high-dimensional vector storage using Cosine distance, achieving sub-15ms recall with exactly 0 prompt tokens consumed.',
            style: TextStyle(fontSize: 11, height: 1.4, color: SepiaTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTelemetryPill('Recall Latency', '12 ms', Colors.green.shade800),
              const SizedBox(width: 6),
              _buildTelemetryPill('Injected Tokens', '0 tokens', Colors.blue.shade800),
              const SizedBox(width: 6),
              _buildTelemetryPill('Vector Metric', 'Cosine Distance', SepiaTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: SepiaTheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: SepiaTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8.5, color: SepiaTheme.textMuted)),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInspectorCard(String? prompt) {
    final displayPrompt = (prompt != null && prompt.isNotEmpty)
        ? prompt
        : '''SYSTEM PROMPT:
You are an offline cognitive Dreaming and Memory Consolidation engine.
Your task is to analyze episodic chat transcripts, prune ephemeral noise/greetings,
and distill durable architectural facts and key decisions into long-term semantic memory.
Provide your output in exactly this format:
SUMMARY: <single concise paragraph summarizing architectural state>
DISTILLED_FACT: <fact 1>
DISTILLED_FACT: <fact 2>
DISTILLED_FACT: <fact 3>

USER PROMPT:
Consolidate the following conversation from channel #${widget.selectedChannel.name} (${widget.selectedChannel.topic}):
- Lead Coordinator: Swarm consensus reached: standardizing deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8.
- Security Auditor: Zero-trust credentials, auth tokens, and raw tool traces must remain strictly isolated inside private scratchpads.
- Scribe Agent: Compacted earlier thread state with -96% token reduction.
- Researcher Agent: Vector indexing validated with Cosine distance for sub-15ms fast-path recall.''';

    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isPromptInspectorExpanded = !_isPromptInspectorExpanded;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: SepiaTheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📜 REM Dream Synthesis Prompt Inspector',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Exact prompt template injected into Gemini 3.8 Flash for offline consolidation',
                          style: TextStyle(fontSize: 10.5, color: SepiaTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isPromptInspectorExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: SepiaTheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isPromptInspectorExpanded) ...[
            const Divider(height: 1, color: SepiaTheme.border),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF2C2723),
              child: SelectableText(
                displayPrompt,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 10.5,
                  height: 1.4,
                  color: Color(0xFFF5EFE6),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: SepiaTheme.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, size: 12, color: SepiaTheme.accent),
                  SizedBox(width: 5),
                  Text(
                    'Model: Gemini 3.8 Flash • Vertex AI location="us-central1" • ADC Auth',
                    style: TextStyle(fontSize: 10, color: SepiaTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatabaseVectorStoreCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_rounded, size: 16, color: SepiaTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PERSISTENT DATABASE & VECTOR STORE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: SepiaTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 10, color: Color(0xFF2E7D32)),
                    SizedBox(width: 3),
                    Text(
                      'Live BQ Connected',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Episodic conversations stream to BigQuery agent_logs, dream summaries write to session_summaries, and crystallized beliefs are indexed with 768-dim vectors using BigQuery ML.DISTANCE.',
            style: TextStyle(fontSize: 10.5, color: SepiaTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTelemetryPill('DATABASE', 'Google BigQuery', const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              _buildTelemetryPill('DATASET', 'adk_agent_telemetry', const Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              _buildTelemetryPill('VECTORS', 'BQ ML.DISTANCE', const Color(0xFF6A1B9A)),
            ],
          ),
        ],
      ),
    );
  }

  List<CrystallizedBelief> _getCrystallizedBeliefs() {
    return AgentMeshView.extractCrystallizedBeliefs(widget.consolidationReports);
  }

  Widget _buildCrystallineBeliefsTable(List<CrystallizedBelief> beliefs) {
    if (beliefs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SepiaTheme.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.border),
        ),
        child: const Text(
          'No crystallized beliefs recorded yet.',
          style: TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderStrong),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: SepiaTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
              border: Border(bottom: BorderSide(color: SepiaTheme.border)),
            ),
            child: const Row(
              children: [
                Icon(Icons.table_rows_outlined, size: 13, color: SepiaTheme.primary),
                SizedBox(width: 6),
                Text(
                  'Crystalline Beliefs & Invariants',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
                ),
                Spacer(),
                Icon(Icons.auto_awesome, size: 11, color: Color(0xFF7B1FA2)),
                SizedBox(width: 4),
                Text(
                  'REM Dreaming • Gemini 3.8',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2)),
                ),
              ],
            ),
          ),
          for (int i = 0; i < beliefs.length; i++) ...[
            _buildCrystallineBeliefRow(beliefs[i], isLast: i == beliefs.length - 1),
            if (i < beliefs.length - 1)
              const Divider(height: 1, thickness: 1, color: SepiaTheme.border),
          ],
        ],
      ),
    );
  }

  Widget _buildCrystallineBeliefRow(CrystallizedBelief b, {bool isLast = false}) {
    Color categoryBg;
    Color categoryFg;

    switch (b.category.toLowerCase()) {
      case 'security':
        categoryBg = const Color(0xFFF3E5F5);
        categoryFg = const Color(0xFF7B1FA2);
        break;
      case 'database':
        categoryBg = const Color(0xFFE3F2FD);
        categoryFg = const Color(0xFF1565C0);
        break;
      case 'infrastructure':
        categoryBg = const Color(0xFFFFF3E0);
        categoryFg = const Color(0xFFE65100);
        break;
      default:
        categoryBg = SepiaTheme.primaryLight;
        categoryFg = SepiaTheme.primary;
    }

    final pct = (b.confidence * 100).toInt();
    final timeStr = b.generatedAt != null
        ? '${b.generatedAt!.hour.toString().padLeft(2, '0')}:${b.generatedAt!.minute.toString().padLeft(2, '0')}:${b.generatedAt!.second.toString().padLeft(2, '0')}'
        : 'Consolidated';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SepiaTheme.card,
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(5)) : BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: categoryBg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: categoryFg.withValues(alpha: 0.3)),
                ),
                child: Text(
                  b.category.toUpperCase(),
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: categoryFg),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  b.key,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 9, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 2),
                    Text(
                      '$pct%',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            b.statement.isNotEmpty ? b.statement : b.value,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: SepiaTheme.textPrimary,
            ),
          ),
          if (b.keywords.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: b.keywords
                  .map((kw) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: SepiaTheme.surface,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: SepiaTheme.border),
                        ),
                        child: Text(
                          '#$kw',
                          style: const TextStyle(fontSize: 8.5, color: SepiaTheme.textSecondary),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 9, color: Color(0xFF7B1FA2)),
                    SizedBox(width: 3),
                    Text(
                      'Machine-Generated via REM Dreaming (Gemini 3.8)',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF7B1FA2)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 9, color: SepiaTheme.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 9, color: SepiaTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab 4: Private Scratchpad
  Widget _buildScratchpadTab() {
    final pad = widget.scratchpad;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('DUAL-LAYER MEMORY: PRIVATE SCRATCHPAD'),
        const SizedBox(height: 8),
        const Text(
          'Collaborative multi-agent mesh relies on dual-layer memory. While the channel stream is a public blackboard, each agent maintains an isolated private scratchpad for internal monologue, planning, and raw tool traces that never pollute the team stream.',
          style: TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        if (pad == null)
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
                  'Lead Coordinator Scratchpad (Active)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                ),
                SizedBox(height: 6),
                Text('Active Draft Plan: Coordinate distributed transaction verification & GA launch sign-off.', style: TextStyle(fontSize: 11)),
                SizedBox(height: 4),
                Text('💭 Checked vector index DDL; cosine metrics verified', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                SizedBox(height: 2),
                Text('💭 Verified zero secrets committed in repository assets', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                SizedBox(height: 4),
                Text('⚙️ gcloud run services describe agents-of-chat -> STATUS: Ready', style: TextStyle(fontSize: 10, fontFamily: 'Courier')),
              ],
            ),
          )
        else
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CONFIDENTIAL MONOLOGUE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
                if (pad.draftPlan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Active Draft Plan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(pad.draftPlan, style: const TextStyle(fontSize: 11.5, color: SepiaTheme.textPrimary)),
                ],
                if (pad.innerThoughts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Inner Monologue Stream:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...pad.innerThoughts.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '💭 $t',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: SepiaTheme.textSecondary),
                        ),
                      )),
                ],
                if (pad.toolTraces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Raw Tool Invocations:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...pad.toolTraces.map((tr) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '⚙️ $tr',
                          style: const TextStyle(fontSize: 10, fontFamily: 'Courier', color: SepiaTheme.textMuted),
                        ),
                      )),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // Tab 5: Events
  Widget _buildEventsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('PRE-CONFIGURED OPERATIONAL EVENTS'),
        const SizedBox(height: 8),
        _buildPresetEventCard(
          title: '🚨 Sentry Alert: P99 Latency Breach',
          subtitle: 'Checkout API p99 reached 820ms (Database read lock elevated)',
          onTap: () => widget.onInjectEvent(
            'Sentry Alert: P99 Latency Breach',
            'checkout-service latency spike detected across 4 pods. Database read locks elevated.',
          ),
        ),
        const SizedBox(height: 8),
        _buildPresetEventCard(
          title: '📦 Pull Request Ready for Review',
          subtitle: 'PR-402: Add transactional outbox table pattern',
          onTap: () => widget.onInjectEvent(
            'Pull Request Ready: PR-402',
            'Staff Architect opened PR-402 proposing transactional outbox to decouple message publishing.',
          ),
        ),
        const SizedBox(height: 8),
        _buildPresetEventCard(
          title: '🔥 Distributed 2PC Deadlock Warning',
          subtitle: 'Lock contention detected on order_ledger & outbox_events',
          onTap: () => widget.onInjectEvent(
            'Distributed Transaction Lock Deadlock',
            'Deadlock detected during concurrent mutations on order_ledger and outbox_events. Immediate mitigation required.',
          ),
        ),

        const SizedBox(height: 16),
        _buildSectionHeader('CUSTOM EVENT INJECTION'),
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
            hintText: 'Telemetry payload or alert details...',
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
          onPressed: _handleInjectCustomEvent,
          child: const Text('Inject Event into Stream'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildMessageIntentCard(Message? msg) {
    String pattern = 'Shared Blackboard';
    String concept = 'Dual-Layer Working Memory';
    String explanation =
        'Public channel acts as shared team memory for final decisions, while private agent scratchpads hold raw tool execution.';

    if (msg != null && msg.intentTags.isNotEmpty) {
      final tag = msg.intentTags.first;
      if (tag.type == 'compaction') {
        pattern = 'Compaction & Rollup';
        concept = 'Hierarchical State Rollup';
        explanation = 'Compacts past event turns into concise state checkpoints (-96% token reduction).';
      } else if (tag.type == 'vector_hit') {
        pattern = 'Long-Term Memory RAG';
        concept = 'Vector Search RAG';
        explanation = 'Queries external vector index via cosine similarity without context pollution.';
      } else if (tag.type == 'permission') {
        pattern = 'Role & Context Fencing';
        concept = 'Zero-Secrets Security Boundary';
        explanation = 'Context boundaries prevent unauthorized agent knowledge bleed between sensitive environments.';
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
              const Icon(Icons.psychology, size: 14, color: SepiaTheme.primary),
              const SizedBox(width: 6),
              Text(
                pattern,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cognitive Mechanism: $concept',
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

  Widget _buildPresetEventCard({required String title, required String subtitle, required VoidCallback onTap}) {
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

class _SepiaMessageCard extends StatelessWidget {
  final Message message;
  final VoidCallback onSelect;
  final VoidCallback onInspectConcept;
  final VoidCallback onInspectCompaction;

  const _SepiaMessageCard({
    required this.message,
    required this.onSelect,
    required this.onInspectConcept,
    required this.onInspectCompaction,
  });

  @override
  Widget build(BuildContext context) {
    final isAgent = message.senderType == 'agent';
    final isSystem = message.senderType == 'system';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSystem ? const Color(0xFFFAF6EE) : SepiaTheme.surface,
        border: Border.all(
          color: isSystem ? const Color(0xFFEADBCE) : SepiaTheme.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isAgent
                    ? SepiaTheme.primaryLight
                    : (isSystem ? Colors.amber.shade100 : Colors.blueGrey.shade100),
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAgent ? SepiaTheme.primary : SepiaTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.senderName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SepiaTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              if (isAgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: SepiaTheme.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'GEMINI 3.8 FLASH',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                  ),
                ),
              const Spacer(),
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10.5, color: SepiaTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            message.content,
            style: const TextStyle(fontSize: 13, height: 1.45, color: SepiaTheme.textPrimary),
          ),
          if (message.intentTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: message.intentTags.map((tag) {
                return _SepiaIntentPill(tag: tag, onTap: onSelect);
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.analytics_outlined, size: 12, color: SepiaTheme.accent),
                label: const Text('Inspect in Memory Lens', style: TextStyle(fontSize: 10.5, color: SepiaTheme.accent)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                onPressed: onSelect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SepiaIntentPill extends StatelessWidget {
  final IntentTag tag;
  final VoidCallback onTap;

  const _SepiaIntentPill({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tag.type) {
      case 'crystalline_hit':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case 'compaction':
        bg = SepiaTheme.tagCompactionBg;
        fg = SepiaTheme.tagCompactionText;
        break;
      case 'vector_hit':
        bg = SepiaTheme.tagVectorBg;
        fg = SepiaTheme.tagVectorText;
        break;
      case 'permission':
        bg = SepiaTheme.tagPermissionBg;
        fg = SepiaTheme.tagPermissionText;
        break;
      default:
        bg = SepiaTheme.tagContextBg;
        fg = SepiaTheme.tagContextText;
    }

    return Tooltip(
      message: '${tag.description}\n(Click to inspect in Memory Lens)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tag.type == 'crystalline_hit' ? Icons.bolt : Icons.memory, size: 11, color: fg),
              const SizedBox(width: 4),
              Text(
                tag.label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
