import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../theme/sepia_theme.dart';

/// ThreadsView implements the Modern Threaded Chat layout with an expandable
/// right-hand Thread Scratchpad (sub-task context isolation).
///
/// Memory Concept:
/// - Sub-Task Scratchpad Isolation & Scribe Compaction
/// - High-turn debates live inside isolated thread scratchpads
/// - "@scribe summarize thread" demonstrates hierarchical state compaction (-96% token reduction).
class ThreadsView extends StatefulWidget {
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

  const ThreadsView({
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
  State<ThreadsView> createState() => _ThreadsViewState();
}

class _ThreadsViewState extends State<ThreadsView> {
  final TextEditingController _mainComposerCtrl = TextEditingController();
  final TextEditingController _threadComposerCtrl = TextEditingController();
  final ScrollController _mainScrollCtrl = ScrollController();
  final ScrollController _threadScrollCtrl = ScrollController();

  bool _showCompactionDetails = true;
  bool _isSummarizing = false;
  double _threadWidth = 430.0;
  bool _isMaximized = false;
  bool _isDragging = false;
  bool _isHoveringHandle = false;
  bool _isRootCollapsed = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      // Dragging left (negative delta) expands right-side drawer; dragging right shrinks it.
      final newWidth = _threadWidth - details.delta.dx;
      _threadWidth = newWidth.clamp(320.0, maxWidth);
      _isMaximized = false;
    });
  }

  void _togglePresetWidth() {
    setState(() {
      if ((_threadWidth - 430.0).abs() < 25) {
        _threadWidth = 650.0;
        _isMaximized = false;
      } else {
        _threadWidth = 430.0;
        _isMaximized = false;
      }
    });
  }

  void _toggleMaximize(double maxWidth) {
    setState(() {
      _isMaximized = !_isMaximized;
      if (_isMaximized) {
        _threadWidth = maxWidth;
      } else {
        _threadWidth = 430.0;
      }
    });
  }

  void _setPresetWidth(double width) {
    setState(() {
      _threadWidth = width;
      _isMaximized = false;
    });
  }

  @override
  void didUpdateWidget(covariant ThreadsView oldWidget) {
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

  int _calculateTokens(Message m) {
    if (m.tokenCount > 0) return m.tokenCount;
    if (m.metadata != null) {
      final cand = m.metadata!['candidate_tokens'];
      if (cand is int && cand > 0) return cand;
      final prompt = m.metadata!['prompt_tokens'];
      if (prompt is int && prompt > 0) return prompt;
    }
    final wordList = m.content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final count = (wordList.length * 1.3).ceil();
    return count > 0 ? count : 1;
  }

  void _triggerScribeSummarize() {
    setState(() {
      _isSummarizing = true;
      _showCompactionDetails = true;
    });
    widget.onSendMessage('@scribe summarize the thread investigation', threadId: widget.activeThreadId);
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
    const threadDarkNav = Color(0xFF1A1D21);
    const threadActiveNav = Color(0xFF2C3136);
    const threadBorder = Color(0xFFE2E2E2);
    const threadAccent = Color(0xFF1264A3);

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
        content: 'Thread reasoning initialized.',
        tokenCount: 40,
        intentTags: [],
        createdAt: DateTime.now(),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          // Left sidebar is 240px; reserve at least 280px for center stream when in split mode
          final maxScratchpadWidth = (totalWidth - 240 - 280).clamp(360.0, 1400.0);
          final effectiveWidth = _threadWidth.clamp(320.0, maxScratchpadWidth);

          return Row(
            children: [
              // 1. Left Sidebar: Channels & Thread Hub (240px)
              Container(
                width: 240,
                color: threadDarkNav,
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
                            color: isSelected ? threadActiveNav : Colors.transparent,
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
                              ? threadActiveNav
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

          // 2. Center: Main Channel Stream (Flex: 3, hidden when scratchpad is maximized)
          if (!_isMaximized)
            Expanded(
              flex: 3,
              child: Column(
              children: [
                // Top Channel Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: threadBorder, width: 1)),
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
                          icon: const Icon(Icons.fork_right, size: 14, color: threadAccent),
                          label: const Text('Open Scratchpad', style: TextStyle(fontSize: 11.5, color: threadAccent)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: threadAccent),
                          ),
                          onPressed: () => widget.onOpenThread('thread-rfc-042'),
                        ),
                    ],
                  ),
                ),

                // Compaction Overview Pill Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  color: const Color(0xFFF9F7F4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      const Text(
                        'Threads isolate sub-task token explosion.',
                        style: TextStyle(fontSize: 11, color: SepiaTheme.textSecondary),
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

                            final threadReplies = widget.messages.where((m) =>
                              m.threadId == msg.id || (msg.id == 'msg-rfc-root-02' && m.threadId == 'thread-rfc-042')
                            ).length;
                            final totalReplies = threadReplies > 0 ? threadReplies : (widget.threadMessages.isNotEmpty ? widget.threadMessages.length : 2);

                            return _MainStreamMessageItem(
                              message: msg,
                              hasThread: hasThread,
                              activeThreadId: widget.activeThreadId,
                              replyCount: totalReplies,
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
                    border: Border(top: BorderSide(color: threadBorder, width: 1)),
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

          // 3. Right-Hand Expandable Drawer: Thread Scratchpad (Resizable from left to right)
          if (widget.activeThreadId != null) ...[
            if (!_isMaximized) ...[
              _buildResizeHandle(maxScratchpadWidth, threadBorder),
              SizedBox(
                width: effectiveWidth,
                child: _buildThreadScratchpadContent(
                  effectiveWidth: effectiveWidth,
                  maxScratchpadWidth: maxScratchpadWidth,
                  threadRoot: threadRoot,
                  threadMessages: threadMessages,
                  threadBorder: threadBorder,
                ),
              ),
            ] else ...[
              Expanded(
                child: _buildThreadScratchpadContent(
                  effectiveWidth: effectiveWidth,
                  maxScratchpadWidth: maxScratchpadWidth,
                  threadRoot: threadRoot,
                  threadMessages: threadMessages,
                  threadBorder: threadBorder,
                ),
              ),
            ],
          ],
          ],
        );
      },
    ),
  );
}

  Widget _buildResizeHandle(double maxScratchpadWidth, Color threadBorder) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHoveringHandle = true),
      onExit: (_) => setState(() => _isHoveringHandle = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, maxScratchpadWidth),
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        onDoubleTap: _togglePresetWidth,
        child: Tooltip(
          message: 'Drag left/right to resize • Double-click to toggle width',
          child: Container(
            width: 10,
            color: _isDragging || _isHoveringHandle
                ? SepiaTheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 1.5,
                  color: _isDragging || _isHoveringHandle ? SepiaTheme.primary : threadBorder,
                ),
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isDragging || _isHoveringHandle ? SepiaTheme.primary : const Color(0xFFC0C0C0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadScratchpadContent({
    required double effectiveWidth,
    required double maxScratchpadWidth,
    required Message threadRoot,
    required List<Message> threadMessages,
    required Color threadBorder,
  }) {
    final bool isScribeTyping = widget.typingAgentName?.toLowerCase().contains('scribe') ?? false;

    // Find the latest Scribe summary message (if any)
    Message? latestScribe;
    for (int i = threadMessages.length - 1; i >= 0; i--) {
      final m = threadMessages[i];
      if (m.senderId == 'scribe-agent' || m.intentTags.any((t) => t.type == 'compaction')) {
        latestScribe = m;
        break;
      }
    }

    // Deliberation turns: all messages in thread except the latest Scribe summary
    final deliberationMsgs = threadMessages.where((m) =>
      m != latestScribe &&
      m.senderId != 'scribe-agent' &&
      !m.intentTags.any((t) => t.type == 'compaction')
    ).toList();

    // Sum deliberation turns in thread plus root message
    final int rawTurnsTokens = deliberationMsgs.fold(0, (sum, m) => sum + _calculateTokens(m));
    final int rootTokens = _calculateTokens(threadRoot);
    final int totalRawTokens = rawTurnsTokens + (deliberationMsgs.isNotEmpty ? rootTokens : 0);
    final int displayRawTokens = totalRawTokens > 0 ? totalRawTokens : (rootTokens > 0 ? rootTokens : 50);

    final bool isSummarized = latestScribe != null;
    final int compactedTokens = isSummarized ? _calculateTokens(latestScribe) : 0;

    // Dynamic compaction ratio
    final double rawBenchmark = displayRawTokens > compactedTokens
        ? displayRawTokens.toDouble()
        : (compactedTokens > 0 ? (compactedTokens + 100).toDouble() : 100.0);
    final double compactionRatio = isSummarized && rawBenchmark > compactedTokens
        ? ((rawBenchmark - compactedTokens) / rawBenchmark).clamp(0.01, 0.99)
        : 0.0;
    final int percentCompacted = (compactionRatio * 100).round();

    final bool currentlySummarizing = _isSummarizing || isScribeTyping;

    final String consensusText = isSummarized
        ? latestScribe.content
        : (currentlySummarizing
            ? 'Scribe agent is generating consensus compaction from $displayRawTokens raw thread tokens...'
            : 'Thread active with $displayRawTokens raw tokens. Click "@scribe summarize thread" to compact into a consensus checkpoint.');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        border: Border(left: BorderSide(color: threadBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          // Thread Header with Title, Width Badge, Preset Controls, Maximize, and Close
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: threadBorder, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fork_right, size: 18, color: SepiaTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          const Text(
                            'Thread Scratchpad',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D1C1D),
                            ),
                          ),
                          // Dynamic Width Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EDE6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDED6C9)),
                            ),
                            child: Text(
                              _isMaximized ? 'MAX' : '${effectiveWidth.round()}px',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Thread: ${widget.activeThreadId}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF616061)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Preset Width Button: Std (430px)
                Tooltip(
                  message: 'Standard Width (430px)',
                  child: InkWell(
                    onTap: () => _setPresetWidth(430.0),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (effectiveWidth - 430).abs() < 15 && !_isMaximized ? const Color(0xFFE8F5E9) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (effectiveWidth - 430).abs() < 15 && !_isMaximized ? const Color(0xFFA5D6A7) : const Color(0xFFD1D2D3),
                        ),
                      ),
                      child: Text(
                        'Std',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (effectiveWidth - 430).abs() < 15 && !_isMaximized ? const Color(0xFF2E7D32) : const Color(0xFF616061),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Preset Width Button: Wide (650px)
                Tooltip(
                  message: 'Wide Width (650px)',
                  child: InkWell(
                    onTap: () => _setPresetWidth(650.0),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (effectiveWidth - 650).abs() < 15 && !_isMaximized ? const Color(0xFFE8F5E9) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (effectiveWidth - 650).abs() < 15 && !_isMaximized ? const Color(0xFF2E7D32) : const Color(0xFF616061),
                        ),
                      ),
                      child: Text(
                        'Wide',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (effectiveWidth - 650).abs() < 15 && !_isMaximized ? const Color(0xFF2E7D32) : const Color(0xFF616061),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Maximize / Restore Button
                Tooltip(
                  message: _isMaximized ? 'Restore Split View' : 'Maximize Thread Scratchpad',
                  child: InkWell(
                    onTap: () => _toggleMaximize(maxScratchpadWidth),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _isMaximized ? Icons.close_fullscreen : Icons.open_in_full,
                        size: 16,
                        color: _isMaximized ? SepiaTheme.primary : const Color(0xFF616061),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Close Thread Scratchpad',
                  child: InkWell(
                    onTap: widget.onCloseThread,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Color(0xFF616061)),
                    ),
                  ),
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
                      icon: currentlySummarizing
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 14),
                      label: Text(
                        currentlySummarizing ? 'Compacting Thread...' : '@scribe summarize thread',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SepiaTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: currentlySummarizing ? null : _triggerScribeSummarize,
                    ),
                    InkWell(
                      onTap: () => setState(() => _showCompactionDetails = !_showCompactionDetails),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSummarized ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isSummarized ? Colors.green.shade400 : Colors.amber.shade400),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSummarized
                                  ? '-$percentCompacted% Compaction'
                                  : (currentlySummarizing
                                      ? 'Compacting...'
                                      : 'Live: $displayRawTokens tokens'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isSummarized ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showCompactionDetails ? Icons.expand_less : Icons.expand_more,
                              size: 13,
                              color: isSummarized ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                            ),
                          ],
                        ),
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
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Raw Thread Turns:', style: TextStyle(fontSize: 11, color: Color(0xFF616061))),
                            ),
                            Text(
                              '$displayRawTokens tokens (Unrolled)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Scribe Compacted State:', style: TextStyle(fontSize: 11, color: Color(0xFF616061))),
                            ),
                            Text(
                              isSummarized
                                  ? '$compactedTokens tokens (Rollup)'
                                  : (currentlySummarizing ? 'Synthesizing...' : 'Pending Rollup'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSummarized ? Colors.green : const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: isSummarized
                                ? (compactedTokens / (rawBenchmark > 0 ? rawBenchmark : 1.0)).clamp(0.01, 1.0)
                                : (currentlySummarizing ? null : 1.0),
                            backgroundColor: isSummarized ? Colors.red.shade100 : Colors.grey.shade200,
                            color: isSummarized ? Colors.green.shade600 : Colors.amber.shade600,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Consensus State Checkpoint:',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          consensusText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: isSummarized ? FontStyle.normal : FontStyle.italic,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Pinned Root Message of Thread (with Collapsible Toggle)
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
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _isRootCollapsed = !_isRootCollapsed),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isRootCollapsed ? Icons.unfold_more : Icons.unfold_less,
                            size: 13,
                            color: SepiaTheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _isRootCollapsed ? 'Expand root' : 'Collapse root',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: SepiaTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${threadRoot.createdAt.hour.toString().padLeft(2, '0')}:${threadRoot.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
                if (!_isRootCollapsed) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${threadRoot.senderName}:',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    threadRoot.content,
                    style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF424242)),
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    '${threadRoot.senderName}: ${threadRoot.content}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF757575)),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E2E2)),

          // Thread Messages List
          Expanded(
            child: threadMessages.isEmpty
                ? const Center(
                    child: Text(
                      'Thread active.\nNo thread turns yet; post a reply below.',
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
              border: Border(top: BorderSide(color: Color(0xFFE2E2E2), width: 1)),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickChip('@scribe summarize the thread investigation', _insertThreadPrompt),
                      _buildQuickChip('@researcher check database latency benchmarks', _insertThreadPrompt),
                      _buildQuickChip('Check compaction compression ratio', _insertThreadPrompt),
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
  final int replyCount;

  const _MainStreamMessageItem({
    required this.message,
    required this.hasThread,
    required this.activeThreadId,
    required this.onOpenThread,
    this.onSelect,
    this.replyCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isAgent = message.senderType == 'agent';
    final isActiveThread = activeThreadId != null &&
        (message.id == activeThreadId || (hasThread && activeThreadId == 'thread-rfc-042'));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: isActiveThread ? const EdgeInsets.all(10) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isActiveThread ? const Color(0xFFF7FAFD) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActiveThread
            ? const Border(
                left: BorderSide(color: Color(0xFF1264A3), width: 3.5),
              )
            : null,
      ),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
                    ),
                    if (isActiveThread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fork_right, size: 10, color: Color(0xFF2E7D32)),
                            SizedBox(width: 3),
                            Text(
                              'OPEN IN SCRATCHPAD',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
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
                        color: isActiveThread ? const Color(0xFFE8F5E9) : const Color(0xFFF4EDE4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isActiveThread ? const Color(0xFFA5D6A7) : const Color(0xFFD4C8B8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fork_right, size: 14, color: isActiveThread ? const Color(0xFF2E7D32) : SepiaTheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            isActiveThread
                                ? 'Thread Scratchpad Open (Active Focus)'
                                : (replyCount > 0
                                    ? 'View Thread Scratchpad ($replyCount ${replyCount == 1 ? 'reply' : 'replies'})'
                                    : 'View Thread Scratchpad'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActiveThread ? const Color(0xFF2E7D32) : SepiaTheme.primary,
                            ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFEADBCE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isAgent ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAgent ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.senderName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D1C1D)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (isAgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3136),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('SUB-AGENT', style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            message.content,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF333333)),
          ),
          if (message.intentTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: message.intentTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: SepiaTheme.primaryLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    tag.label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
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
