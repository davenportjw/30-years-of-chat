import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../theme/sepia_theme.dart';

/// SlackThreadsView implements the Modern Slack layout with an expandable
/// right-hand Thread Scratchpad (sub-task context isolation).
///
/// Memory Concept:
/// - Sub-Task Scratchpad Isolation & Scribe Compaction
/// - High-turn debates live inside isolated thread scratchpads
/// - "@scribe summarize thread" demonstrates hierarchical state compaction (-96% token reduction).
class SlackThreadsView extends StatefulWidget {
  final List<Channel> channels;
  final Channel selectedChannel;
  final Function(Channel) onSelectChannel;
  final List<Message> messages;
  final List<Message> threadMessages;
  final String? activeThreadId;
  final Function(String threadId) onOpenThread;
  final VoidCallback onCloseThread;
  final Function(String, {String? threadId}) onSendMessage;
  final String? typingAgentName;
  final Function(Message)? onSelectMessage;

  const SlackThreadsView({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.onSelectChannel,
    required this.messages,
    this.threadMessages = const [],
    required this.activeThreadId,
    required this.onOpenThread,
    required this.onCloseThread,
    required this.onSendMessage,
    this.typingAgentName,
    this.onSelectMessage,
  });

  @override
  State<SlackThreadsView> createState() => _SlackThreadsViewState();
}

class _SlackThreadsViewState extends State<SlackThreadsView> {
  final TextEditingController _mainComposerCtrl = TextEditingController();
  final TextEditingController _threadComposerCtrl = TextEditingController();
  final ScrollController _mainScrollCtrl = ScrollController();
  final ScrollController _threadScrollCtrl = ScrollController();

  bool _showCompactionDetails = true;

  @override
  void didUpdateWidget(covariant SlackThreadsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mainScrollCtrl.hasClients) {
          _mainScrollCtrl.animateTo(
            _mainScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        if (_threadScrollCtrl.hasClients) {
          _threadScrollCtrl.animateTo(
            _threadScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _mainComposerCtrl.dispose();
    _threadComposerCtrl.dispose();
    _mainScrollCtrl.dispose();
    _threadScrollCtrl.dispose();
    super.dispose();
  }

  void _handleSendMain() {
    final text = _mainComposerCtrl.text.trim();
    if (text.isEmpty) return;
    _mainComposerCtrl.clear();
    widget.onSendMessage(text);
  }

  void _handleSendThread() {
    final text = _threadComposerCtrl.text.trim();
    if (text.isEmpty) return;
    _threadComposerCtrl.clear();
    widget.onSendMessage(text, threadId: widget.activeThreadId);
  }

  void _triggerScribeSummarize() {
    widget.onSendMessage('@scribe summarize the thread investigation', threadId: widget.activeThreadId);
    setState(() {
      _showCompactionDetails = true;
    });
  }

  void _insertMainPrompt(String text) {
    _mainComposerCtrl.text = text;
    _mainComposerCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _mainComposerCtrl.text.length),
    );
  }

  void _insertThreadPrompt(String text) {
    _threadComposerCtrl.text = text;
    _threadComposerCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _threadComposerCtrl.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    const slackDarkNav = Color(0xFF1A1D21);
    const slackActiveNav = Color(0xFF2C3136);
    const slackBorder = Color(0xFFE2E2E2);
    const slackAccent = Color(0xFF1264A3);

    // Filter messages: main stream shows root messages (never empty even when thread is open)
    final rootMessages = widget.messages.where((m) => m.threadId == null || m.threadId!.isEmpty).toList();
    // Thread stream shows messages matching the active thread
    final threadMessages = widget.threadMessages.isNotEmpty
        ? widget.threadMessages
        : (widget.activeThreadId != null
            ? widget.messages.where((m) => m.threadId == widget.activeThreadId).toList()
            : <Message>[]);

    // Find if there is a root message that originated this thread
    final threadRoot = widget.messages.firstWhere(
      (m) => m.id == widget.activeThreadId || (m.threadId != null && m.threadId == widget.activeThreadId),
      orElse: () => widget.messages.isNotEmpty ? widget.messages.first : Message(
        id: 'placeholder',
        channelId: widget.selectedChannel.id,
        senderType: 'system',
        senderId: 'sys',
        senderName: 'Thread Root',
        content: 'Sub-task reasoning thread initialized.',
        tokenCount: 40,
        intentTags: [],
        createdAt: DateTime.now(),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 1. Left Sidebar: Channels & Thread Hub (240px)
          Container(
            width: 240,
            color: slackDarkNav,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Workspace Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF2E3338), width: 1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hub_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agents of Chat',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sub-task isolation pill
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22262B),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF383F45)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fork_right, size: 13, color: Color(0xFF55FF55)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Thread Isolation • -96% Tokens',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Channels Section
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          'CHANNELS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9E9E9E),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...widget.channels.map((ch) {
                        final isSelected = ch.id == widget.selectedChannel.id;
                        return InkWell(
                          onTap: () => widget.onSelectChannel(ch),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            color: isSelected ? slackActiveNav : Colors.transparent,
                            child: Row(
                              children: [
                                Text(
                                  '#',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ch.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : const Color(0xFFD1D2D3),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (ch.id == 'chan-architecture-rfc')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade800,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('RFC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),
                      // Active Threads List
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          'THREAD SCRATCHPADS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9E9E9E),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => widget.onOpenThread('thread-rfc-042'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          color: widget.activeThreadId == 'thread-rfc-042'
                              ? slackActiveNav
                              : Colors.transparent,
                          child: const Row(
                            children: [
                              Icon(Icons.forum_outlined, size: 14, color: Color(0xFF38978D)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'RFC 042: 2PC vs Outbox',
                                  style: TextStyle(fontSize: 12.5, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('3 rep', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Center: Main Channel Stream (Flex: 1)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Top Channel Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: slackBorder, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '# ${widget.selectedChannel.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D1C1D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: const Text(
                          'THREADS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ),
                      if (widget.selectedChannel.topic.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.selectedChannel.topic,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF616061)),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      if (widget.activeThreadId == null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.fork_right, size: 14, color: slackAccent),
                          label: const Text('Open Scratchpad', style: TextStyle(fontSize: 11.5, color: slackAccent)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: slackAccent),
                          ),
                          onPressed: () => widget.onOpenThread('thread-rfc-042'),
                        ),
                    ],
                  ),
                ),

                // Compaction Overview Pill Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  color: const Color(0xFFF9F7F4),
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
                            Icon(Icons.compress, size: 12, color: Color(0xFF2E7D32)),
                            SizedBox(width: 4),
                            Text(
                              '-96% COMPACTION',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Threads isolate sub-task token explosion from main channel context.',
                          style: TextStyle(fontSize: 11, color: SepiaTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: _triggerScribeSummarize,
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
                              Icon(Icons.auto_awesome, size: 12, color: SepiaTheme.primary),
                              SizedBox(width: 3),
                              Text(
                                '@scribe summarize',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Message Stream
                Expanded(
                  child: rootMessages.isEmpty
                      ? const Center(
                          child: Text(
                            'No root messages in this channel.\nBranch into a thread or message below.',
                            style: TextStyle(color: Color(0xFF616061)),
                          ),
                        )
                      : ListView.builder(
                          controller: _mainScrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          itemCount: rootMessages.length,
                          itemBuilder: (context, index) {
                            final msg = rootMessages[index];
                            final hasThread = msg.id == 'msg-rfc-root-02' ||
                                msg.intentTags.any((t) => t.type == 'context' && t.label.contains('Thread'));

                            return _MainStreamMessageItem(
                              message: msg,
                              hasThread: hasThread,
                              activeThreadId: widget.activeThreadId,
                              onOpenThread: () => widget.onOpenThread('thread-rfc-042'),
                              onSelect: widget.onSelectMessage != null ? () => widget.onSelectMessage!(msg) : null,
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
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1264A3)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.typingAgentName} is synthesizing response via Gemini 3.8...',
                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF616061)),
                        ),
                      ],
                    ),
                  ),

                // Main Channel Composer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: slackBorder, width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Prompt Chips: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF616061))),
                            _buildQuickChip('Branch database investigation into thread scratchpad', _insertMainPrompt),
                            _buildQuickChip('@scribe summarize the thread investigation', _insertMainPrompt),
                            _buildQuickChip('Check compaction compression ratio', _insertMainPrompt),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD1D2D3), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _mainComposerCtrl,
                              onSubmitted: (_) => _handleSendMain(),
                              decoration: InputDecoration(
                                hintText: 'Message #${widget.selectedChannel.name}...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF868686)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: InputBorder.none,
                              ),
                            ),
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
                                    icon: const Icon(Icons.fork_right, size: 16, color: Color(0xFF616061)),
                                    tooltip: 'Branch new thread',
                                    onPressed: () => widget.onOpenThread('thread-rfc-042'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF616061)),
                                    tooltip: '@scribe summarize',
                                    onPressed: _triggerScribeSummarize,
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007A5A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      elevation: 0,
                                    ),
                                    onPressed: _handleSendMain,
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

          // 3. Right-Hand Expandable Drawer: Thread Scratchpad (420px)
          if (widget.activeThreadId != null)
            Container(
              width: 430,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF9F6),
                border: Border(left: BorderSide(color: slackBorder, width: 1.5)),
              ),
              child: Column(
                children: [
                  // Thread Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: slackBorder, width: 1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fork_right, size: 18, color: SepiaTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thread Scratchpad',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D1C1D),
                                ),
                              ),
                              Text(
                                'Sub-Task Isolation: ${widget.activeThreadId}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF616061)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Color(0xFF616061)),
                          tooltip: 'Close Thread Scratchpad',
                          onPressed: widget.onCloseThread,
                        ),
                      ],
                    ),
                  ),

                  // Scribe Compaction Action Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SepiaTheme.card,
                      border: const Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome, size: 14),
                              label: const Text(
                                '@scribe summarize thread',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SepiaTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: _triggerScribeSummarize,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade400),
                              ),
                              child: const Text(
                                '-96% Compaction',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                              ),
                            ),
                          ],
                        ),

                        // Compaction Token Metrics Card
                        if (_showCompactionDetails) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: SepiaTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Expanded(
                                      child: Text('Raw Thread Turns:', style: TextStyle(fontSize: 11, color: Color(0xFF616061))),
                                    ),
                                    Text('9,800 tokens (Unrolled)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Row(
                                  children: [
                                    Expanded(
                                      child: Text('Scribe Compacted State:', style: TextStyle(fontSize: 11, color: Color(0xFF616061))),
                                    ),
                                    Text('380 tokens (Rollup)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: 380 / 9800,
                                    backgroundColor: Colors.red.shade100,
                                    color: Colors.green.shade600,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Consensus State Checkpoint:',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'CONSENSUS (RFC 042): Adopt synchronous 2PC with idempotency keys for financial ledger per ADR-019. Async outbox rejected.',
                                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF333333)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Pinned Root Message of Thread
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ROOT PROMPT (PINNED)',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SepiaTheme.textMuted),
                            ),
                            const Spacer(),
                            Text(
                              '${threadRoot.createdAt.hour.toString().padLeft(2, '0')}:${threadRoot.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${threadRoot.senderName}:',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          threadRoot.content,
                          style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF424242)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: slackBorder),

                  // Thread Messages List
                  Expanded(
                    child: threadMessages.isEmpty
                        ? const Center(
                            child: Text(
                              'Sub-task scratchpad active.\nNo thread turns yet; post a reply below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF616061)),
                            ),
                          )
                        : ListView.builder(
                            controller: _threadScrollCtrl,
                            padding: const EdgeInsets.all(14),
                            itemCount: threadMessages.length,
                            itemBuilder: (context, index) {
                              final msg = threadMessages[index];
                              return _ThreadMessageBubble(message: msg);
                            },
                          ),
                  ),

                  // Thread Composer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: slackBorder, width: 1)),
                    ),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickChip('@scribe summarize the thread investigation', _insertThreadPrompt),
                              _buildQuickChip('@researcher check database latency benchmarks', _insertThreadPrompt),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _threadComposerCtrl,
                                onSubmitted: (_) => _handleSendThread(),
                                style: const TextStyle(fontSize: 12.5),
                                decoration: InputDecoration(
                                  hintText: 'Reply in thread scratchpad...',
                                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF868686)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: Color(0xFFD1D2D3)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SepiaTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: _handleSendThread,
                              child: const Icon(Icons.send, size: 14),
                            ),
                          ],
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

  Widget _buildQuickChip(String text, Function(String) onSelect) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 10.5, color: SepiaTheme.primary)),
        backgroundColor: const Color(0xFFF4EDE4),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
        onPressed: () => onSelect(text),
      ),
    );
  }
}

class _MainStreamMessageItem extends StatelessWidget {
  final Message message;
  final bool hasThread;
  final String? activeThreadId;
  final VoidCallback onOpenThread;
  final VoidCallback? onSelect;

  const _MainStreamMessageItem({
    required this.message,
    required this.hasThread,
    required this.activeThreadId,
    required this.onOpenThread,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isAgent = message.senderType == 'agent';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isAgent ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
            child: Text(
              message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isAgent ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
              ),
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
                      message.senderName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF616061)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  message.content,
                  style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF1D1C1D)),
                ),
                if (message.intentTags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: message.intentTags.map((tag) {
                      final isCompaction = tag.type == 'compaction';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isCompaction ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isCompaction ? const Color(0xFF2E7D32) : const Color(0xFFB75500)),
                        ),
                        child: Text(
                          tag.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCompaction ? const Color(0xFF2E7D32) : const Color(0xFFB75500),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 6),
                // Thread Scratchpad launch button
                if (hasThread)
                  InkWell(
                    onTap: onOpenThread,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EDE4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFD4C8B8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fork_right, size: 14, color: SepiaTheme.primary),
                          SizedBox(width: 5),
                          Text(
                            'View Thread Scratchpad (3 replies • Sub-task isolated)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadMessageBubble extends StatelessWidget {
  final Message message;

  const _ThreadMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isAgent = message.senderType == 'agent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFEADBCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
              ),
              const SizedBox(width: 6),
              if (isAgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3136),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('SUB-AGENT', style: TextStyle(fontSize: 8.5, color: Colors.white)),
                ),
              const Spacer(),
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            message.content,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF333333)),
          ),
          if (message.intentTags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: message.intentTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SepiaTheme.primaryLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    tag.label,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
