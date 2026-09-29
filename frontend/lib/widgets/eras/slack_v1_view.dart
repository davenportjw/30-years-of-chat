import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../theme/sepia_theme.dart';

/// SlackV1View implements the Classic Slack 1.0 aesthetic:
/// - Deep aubergine sidebar (#4A154B)
/// - # channel list and agent roster
/// - Clean white transcript area
/// - Top universal search bar demonstrating Long-Term Memory (LTM) & Vector Search RAG
///   with real cosine distance metrics.
class SlackV1View extends StatefulWidget {
  final List<Channel> channels;
  final Channel selectedChannel;
  final Function(Channel) onSelectChannel;
  final List<Message> messages;
  final Function(String) onSendMessage;
  final String? typingAgentName;
  final Function(Message)? onSelectMessage;

  const SlackV1View({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.onSelectChannel,
    required this.messages,
    required this.onSendMessage,
    this.typingAgentName,
    this.onSelectMessage,
  });

  @override
  State<SlackV1View> createState() => _SlackV1ViewState();
}

class _VectorDocument {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String channel;
  final List<double> embedding;

  const _VectorDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.channel,
    required this.embedding,
  });
}

class _SearchResult {
  final _VectorDocument doc;
  final double similarity;
  final double cosineDistance;

  _SearchResult({
    required this.doc,
    required this.similarity,
    required this.cosineDistance,
  });
}

class _SlackV1ViewState extends State<SlackV1View> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSearchExpanded = false;
  List<_SearchResult> _searchResults = [];

  // Semantic document corpus indexed in Vector Search
  static const List<_VectorDocument> _vectorIndex = [
    _VectorDocument(
      id: 'ADR-019',
      title: 'ADR-019: Distributed 2PC with Idempotency Keys',
      category: 'Architecture Decision Record',
      channel: '#2017-threads-compaction',
      summary:
          'Mandates synchronous 2PC transactions with idempotency keys for all balance mutations. Asynchronous Kafka messaging rejected due to duplicate billing hazards during broker lag.',
      embedding: [0.18, 0.29, 0.82, 0.87, 0.21, 0.81, 0.28, 0.21, 0.27, 0.84, 0.89, 0.19, 0.82, 0.31, 0.22, 0.32],
    ),
    _VectorDocument(
      id: 'INC-2026-04',
      title: 'INC-2026-04: Batch Worker Lock Contention on auth_tokens',
      category: 'Incident Post-Mortem',
      channel: '#2013-slack-archive',
      summary:
          'Batch reconciliation worker saturated auth_tokens row locks during token expiry sweep, triggering 504 gateway timeouts. Resolution: Throttled worker concurrency from 64 to 8.',
      embedding: [0.85, 0.68, 0.25, 0.10, 0.95, 0.11, 0.03, 0.91, 0.72, 0.22, 0.09, 0.89, 0.12, 0.04, 0.88, 0.71],
    ),
    _VectorDocument(
      id: 'INC-2026-08',
      title: 'INC-2026-08: HTTP 504 Auth Gateway Latency Spike',
      category: 'Incident Post-Mortem',
      channel: '#2013-slack-archive',
      summary:
          'Critical webhook alert triggered on service-auth-proxy with 18.4% 504 error rate and p99 latency reaching 9,420ms. Mitigated by scaling unthrottled replica count to 0.',
      embedding: [0.82, 0.74, 0.21, 0.12, 0.91, 0.15, 0.05, 0.88, 0.79, 0.18, 0.11, 0.85, 0.14, 0.06, 0.83, 0.77],
    ),
    _VectorDocument(
      id: 'ADR-014',
      title: 'ADR-014: Vector Index Partitioning & Cosine Distance',
      category: 'Architecture Decision Record',
      channel: '#2006-campfire-rooms',
      summary:
          'Defines domain-partitioned vector indexing using cosine distance metrics. Guarantees search isolation between channels to prevent context poisoning across agents.',
      embedding: [0.12, 0.24, 0.88, 0.92, 0.14, 0.86, 0.22, 0.15, 0.22, 0.89, 0.94, 0.12, 0.85, 0.25, 0.18, 0.28],
    ),
    _VectorDocument(
      id: 'RFC-042',
      title: 'RFC 042: Event-Driven Transactional Outbox vs Synchronous 2PC',
      category: 'Design RFC',
      channel: '#2017-threads-compaction',
      summary:
          'Evaluates transactional outbox table pattern against distributed synchronous transactions for high-throughput billing ledgers.',
      embedding: [0.18, 0.29, 0.82, 0.87, 0.21, 0.81, 0.28, 0.21, 0.27, 0.84, 0.89, 0.19, 0.82, 0.31, 0.22, 0.32],
    ),
    _VectorDocument(
      id: 'POST-021',
      title: 'POST-MORTEM: Cron Token Reap Thread Starvation',
      category: 'Incident Post-Mortem',
      channel: '#2013-slack-archive',
      summary:
          'Deadlock in connection pool caused by unindexed foreign key in auth_tokens table under high concurrency.',
      embedding: [0.78, 0.81, 0.19, 0.14, 0.84, 0.22, 0.08, 0.82, 0.85, 0.16, 0.12, 0.81, 0.18, 0.09, 0.79, 0.83],
    ),
  ];

  @override
  void didUpdateWidget(covariant SlackV1View oldWidget) {
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
    _msgController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    widget.onSendMessage(text);
  }

  double _computeCosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<double> _pseudoEmbed(String query) {
    final q = query.toLowerCase();
    List<double> vec = [0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20];

    if (q.contains('adr') || q.contains('transaction') || q.contains('2pc') || q.contains('outbox') || q.contains('rfc')) {
      vec = [0.18, 0.28, 0.83, 0.88, 0.20, 0.82, 0.26, 0.20, 0.26, 0.85, 0.90, 0.18, 0.83, 0.30, 0.21, 0.31];
    } else if (q.contains('lock') || q.contains('contention') || q.contains('504') || q.contains('latency') || q.contains('incident') || q.contains('post-mortem') || q.contains('p99')) {
      vec = [0.84, 0.70, 0.24, 0.11, 0.93, 0.13, 0.04, 0.90, 0.74, 0.21, 0.10, 0.88, 0.13, 0.05, 0.86, 0.73];
    } else if (q.contains('partition') || q.contains('vector') || q.contains('isolation') || q.contains('rag')) {
      vec = [0.13, 0.25, 0.87, 0.91, 0.15, 0.85, 0.23, 0.16, 0.23, 0.88, 0.93, 0.13, 0.84, 0.26, 0.19, 0.29];
    }
    return vec;
  }

  void _performVectorSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchExpanded = false;
      });
      return;
    }

    final queryVector = _pseudoEmbed(query);
    final results = <_SearchResult>[];

    for (final doc in _vectorIndex) {
      final sim = _computeCosineSimilarity(queryVector, doc.embedding);
      final dist = (1.0 - sim).clamp(0.0, 1.0);
      results.add(_SearchResult(
        doc: doc,
        similarity: sim,
        cosineDistance: dist,
      ));
    }

    // Sort by highest similarity / lowest cosine distance
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    setState(() {
      _searchResults = results;
      _isSearchExpanded = true;
    });
  }

  void _injectPrompt(String text) {
    _msgController.text = text;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Slack 1.0 Classic Color Palette
    const aubergineSidebar = Color(0xFF4A154B);
    const aubergineDark = Color(0xFF3F0E40);
    const aubergineActive = Color(0xFF350D36);
    const slackTeal = Color(0xFF38978D);
    const slackBorder = Color(0xFFE8E8E8);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 1. Classic Slack 1.0 Aubergine Sidebar (260px)
          Container(
            width: 260,
            color: aubergineSidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: aubergineDark,
                    border: Border(bottom: BorderSide(color: Color(0xFF522653), width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Agents of Chat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: slackTeal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Jason Davenport (Commander)',
                                    style: TextStyle(fontSize: 11, color: Colors.white70),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
                        tooltip: 'New Message',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Channels Section
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      // Channels Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CHANNELS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBCABB9),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Icon(Icons.add_circle_outline, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                      ...widget.channels.map((ch) {
                        final isSelected = ch.id == widget.selectedChannel.id;
                        return InkWell(
                          onTap: () => widget.onSelectChannel(ch),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? aubergineActive : Colors.transparent,
                              border: isSelected
                                  ? const Border(left: BorderSide(color: slackTeal, width: 4))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFFBCABB9),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ch.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFFDCD2DC),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (ch.id == 'chan-incident-postmortem')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'P0',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Direct Messages / Agents Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'AGENT ROSTER & BOTS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFBCABB9),
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.add_circle_outline, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                      _buildBotRow(name: 'Dev Researcher', role: 'Vector RAG', statusColor: slackTeal, isOnline: true, mentionTag: '@researcher'),
                      _buildBotRow(name: 'Lead Coordinator', role: 'Gemini 3.8', statusColor: slackTeal, isOnline: true, mentionTag: '@lead-agent'),
                      _buildBotRow(name: 'Staff Scribe', role: 'Compactor', statusColor: slackTeal, isOnline: true, mentionTag: '@scribe'),
                      _buildBotRow(name: 'Sentry Alerts', role: 'Sensory Webhook', statusColor: Colors.amber, isOnline: true),
                      _buildBotRow(name: 'Eggdrop Bot', role: 'IRC 1988', statusColor: Colors.grey, isOnline: false, mentionTag: '@eggdrop'),
                    ],
                  ),
                ),

                // LTM Vector Index Info Card at sidebar bottom
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: aubergineDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF5A2A5B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storage, size: 14, color: Color(0xFF88FF88)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'LTM: Vector Search RAG',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vector Index: Cosine Distance\nDecoupled from context limits\nSub-10ms precedent recall',
                        style: TextStyle(fontSize: 10, height: 1.35, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Main White Transcript & Universal Search Area (Flex: 1)
          Expanded(
            child: Column(
              children: [
                // Top Universal Search Bar (Classic Slack 1.0 Top Bar)
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: slackBorder, width: 1)),
                  ),
                  child: Row(
                    children: [
                      // Search Input Field
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4EDE4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE0D7CC)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _performVectorSearch,
                            onSubmitted: _performVectorSearch,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1D1C1D)),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search messages, ADRs, post-mortems (Vector Search RAG)...',
                              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF616061)),
                              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF616061)),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF616061)),
                                      onPressed: () {
                                        _searchController.clear();
                                        _performVectorSearch('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Vector Index Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: SepiaTheme.tagVectorBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SepiaTheme.tagVectorText.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hub, size: 13, color: SepiaTheme.tagVectorText),
                            SizedBox(width: 5),
                            Text(
                              'VECTOR RAG ACTIVE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: SepiaTheme.tagVectorText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vector Search Results Dropdown/Drawer if active
                if (_isSearchExpanded && _searchResults.isNotEmpty)
                  _buildVectorSearchResultsPanel(),

                // Channel Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: slackBorder, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '# ${widget.selectedChannel.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D1C1D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_border, size: 16, color: Color(0xFF616061)),
                      const SizedBox(width: 16),
                      Container(height: 16, width: 1, color: slackBorder),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.selectedChannel.topic,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF616061)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Details Button
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18, color: Color(0xFF616061)),
                        tooltip: 'Channel Info & Vector Metadata',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Long-Term Memory Concept Pill Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  color: const Color(0xFFF9F6F0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storage, size: 12, color: Color(0xFF2E7D32)),
                            SizedBox(width: 4),
                            Text(
                              'VECTOR RAG ACTIVE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Historical ADRs & incident logs indexed via cosine similarity.',
                          style: TextStyle(fontSize: 11, color: SepiaTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _performVectorSearch('lock contention'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SepiaTheme.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 12, color: SepiaTheme.primary),
                              SizedBox(width: 3),
                              Text(
                                'Test "lock contention"',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Channel Transcript Area (Clean White)
                Expanded(
                  child: widget.messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages in this channel yet.\nType a message or search ADRs above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF616061)),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          itemCount: widget.messages.length,
                          itemBuilder: (context, index) {
                            final msg = widget.messages[index];
                            return _SlackMessageItem(
                              message: msg,
                              onSelect: widget.onSelectMessage != null
                                  ? () => widget.onSelectMessage!(msg)
                                  : null,
                            );
                          },
                        ),
                ),

                // Typing indicator
                if (widget.typingAgentName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4A154B)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.typingAgentName} is querying Vector RAG & synthesizing via Gemini 3.8...',
                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF616061)),
                        ),
                      ],
                    ),
                  ),

                // Classic Slack Message Composer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: slackBorder, width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick prompt suggestions
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'ADR Queries: ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF616061)),
                            ),
                            _buildQuickChip('What does ADR-019 say about Kafka outbox?'),
                            _buildQuickChip('Investigate database latency spikes'),
                            _buildQuickChip('Query past post-mortems for lock contention'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Input Box with Slack border
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD1D2D3), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _msgController,
                              onSubmitted: (_) => _handleSend(),
                              minLines: 1,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 13.5, color: Color(0xFF1D1C1D)),
                              decoration: InputDecoration(
                                hintText: 'Message #${widget.selectedChannel.name}...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF868686)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: InputBorder.none,
                              ),
                            ),
                            // Composer Footer Actions
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8F8F8),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(5),
                                  bottomRight: Radius.circular(5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.format_bold, size: 16, color: Color(0xFF616061)),
                                    onPressed: () {},
                                    tooltip: 'Bold',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.code, size: 16, color: Color(0xFF616061)),
                                    onPressed: () {},
                                    tooltip: 'Code snippet',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.alternate_email, size: 16, color: Color(0xFF616061)),
                                    onPressed: () => _injectPrompt('@researcher-agent '),
                                    tooltip: 'Mention agent',
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: aubergineSidebar,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      elevation: 0,
                                    ),
                                    onPressed: _handleSend,
                                    child: const Row(
                                      children: [
                                        Icon(Icons.send, size: 13),
                                        SizedBox(width: 4),
                                        Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVectorSearchResultsPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        border: const Border(bottom: BorderSide(color: Color(0xFFD4C8B8), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: SepiaTheme.card,
            child: Row(
              children: [
                const Icon(Icons.insights, size: 15, color: SepiaTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'VECTOR SEARCH RAG RESULTS (${_searchResults.length} hits)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: SepiaTheme.primary),
                ),
                const Spacer(),
                const Text(
                  'Distance Metric: COSINE',
                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: SepiaTheme.textMuted),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => setState(() => _isSearchExpanded = false),
                  child: const Icon(Icons.close, size: 16, color: SepiaTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEADBCE)),
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cosine Distance Meter Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: result.similarity > 0.85
                              ? const Color(0xFFE3F2FD)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: result.similarity > 0.85
                                ? const Color(0xFF1565C0)
                                : const Color(0xFFE65100),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${(result.similarity * 100).toStringAsFixed(1)}% sim',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: result.similarity > 0.85
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFFE65100),
                              ),
                            ),
                            Text(
                              'dist: ${result.cosineDistance.toStringAsFixed(3)}',
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF616061)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  result.doc.title,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    result.doc.category,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF616061)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              result.doc.summary,
                              style: const TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF424242)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_downward, size: 12),
                        label: const Text('Inject into Prompt', style: TextStyle(fontSize: 10.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          side: const BorderSide(color: SepiaTheme.primary),
                          foregroundColor: SepiaTheme.primary,
                        ),
                        onPressed: () {
                          _injectPrompt('Regarding ${result.doc.id}: ${result.doc.summary}');
                          setState(() => _isSearchExpanded = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✨ Injected ${result.doc.id} Vector Context into Message Composer'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: const Color(0xFF4A154B),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF4A154B))),
        backgroundColor: const Color(0xFFF4EDE4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: () => _injectPrompt(text),
      ),
    );
  }

  Widget _buildBotRow({
    required String name,
    required String role,
    required Color statusColor,
    required bool isOnline,
    String? mentionTag,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: mentionTag != null
          ? () {
              final current = _msgController.text;
              if (!current.contains(mentionTag)) {
                _msgController.text = current.isEmpty ? '$mentionTag ' : '$current $mentionTag ';
                _msgController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _msgController.text.length),
                );
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? statusColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFDCD2DC)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              role,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFFBCABB9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlackMessageItem extends StatelessWidget {
  final Message message;
  final VoidCallback? onSelect;

  const _SlackMessageItem({
    required this.message,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isAgent = message.senderType == 'agent';
    final isSystem = message.senderType == 'system';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: isAgent
                ? const Color(0xFFE8F5E9)
                : (isSystem ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD)),
            child: Text(
              message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isAgent
                    ? const Color(0xFF2E7D32)
                    : (isSystem ? const Color(0xFFE65100) : const Color(0xFF1565C0)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Message Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D1C1D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isAgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A154B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'APP',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF616061)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Content
                SelectableText(
                  message.content,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF1D1C1D),
                  ),
                ),

                // Intent Tags (Especially Vector Hits)
                if (message.intentTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.intentTags.map((tag) {
                      final isVector = tag.type == 'vector_hit';
                      return Tooltip(
                        message: '${tag.description}\n(Exact Vector Cosine Match)',
                        child: InkWell(
                          onTap: onSelect,
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isVector ? const Color(0xFFE3F2FD) : const Color(0xFFF5EFE6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isVector ? const Color(0xFF1565C0) : const Color(0xFFD4C8B8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVector ? Icons.hub : Icons.memory,
                                  size: 11,
                                  color: isVector ? const Color(0xFF1565C0) : SepiaTheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tag.label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isVector ? const Color(0xFF1565C0) : SepiaTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
