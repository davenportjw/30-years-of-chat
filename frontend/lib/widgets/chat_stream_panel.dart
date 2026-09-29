import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/sepia_theme.dart';

class ChatStreamPanel extends StatefulWidget {
  final Channel channel;
  final Era? era;
  final String? activeThreadId;
  final List<Message> messages;
  final Function(Message) onSelectMessageForInspector;
  final Function(String threadId) onOpenThread;
  final VoidCallback onCloseThread;
  final Function(String content, {String? threadId}) onSendMessage;
  final String? typingAgentName;
  final MemoryBuffer? memoryBuffer;

  const ChatStreamPanel({
    super.key,
    required this.channel,
    this.era,
    required this.activeThreadId,
    required this.messages,
    required this.onSelectMessageForInspector,
    required this.onOpenThread,
    required this.onCloseThread,
    required this.onSendMessage,
    this.typingAgentName,
    this.memoryBuffer,
  });

  @override
  State<ChatStreamPanel> createState() => _ChatStreamPanelState();
}

class _ChatStreamPanelState extends State<ChatStreamPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ChatStreamPanel oldWidget) {
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

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    widget.onSendMessage(text, threadId: widget.activeThreadId);
  }

  void _insertQuickPrompt(String prompt) {
    _textController.text = prompt;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  List<String> _getQuickPromptsForChannel() {
    if (widget.channel.id == 'chan-1988-irc') {
      return [
        'Check server status and buffer limits',
        'Who has op status in #irchelp?',
        'Trigger FIFO eviction overflow test',
      ];
    } else if (widget.channel.id.startsWith('chan-1997-aim')) {
      return [
        'What is your away status message?',
        'Can you review PR-402 for me?',
        'Are you available for architecture triage?',
      ];
    } else if (widget.channel.id.startsWith('chan-2006-campfire')) {
      return [
        'Check apollo billing balance (Test Fencing)',
        'Deploy Campfire v1.4 patch to staging',
        'List allowed agent roles in this room',
      ];
    } else if (widget.channel.id == 'chan-incident-postmortem') {
      return [
        'What does ADR-019 say about Kafka outbox?',
        'Investigate database latency spikes',
        'Summarize the incident timeline',
      ];
    } else if (widget.channel.id == 'chan-2017-threads') {
      return [
        '@scribe summarize the thread investigation',
        'Branch database investigation into thread scratchpad',
        'Check compaction compression ratio',
      ];
    } else {
      return [
        'Review cross-agent deployment rollback plan',
        'Inspect Lead Coordinator private scratchpad',
        'Synthesize cross-agent consensus on distributed transactions',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIrc = widget.channel.id == 'chan-1988-irc';
    final hasEviction = (widget.memoryBuffer?.evictedCount ?? 0) > 0;
    final quickPrompts = _getQuickPromptsForChannel();

    return Container(
      color: isIrc ? const Color(0xFF1E211E) : SepiaTheme.background,
      child: Column(
        children: [
          // Channel Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isIrc ? const Color(0xFF141714) : SepiaTheme.surface,
              border: Border(
                bottom: BorderSide(color: isIrc ? const Color(0xFF2E382E) : SepiaTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.channel.isDirectMessage ? Icons.person_outline : (isIrc ? Icons.terminal : Icons.tag),
                  size: 20,
                  color: isIrc ? const Color(0xFF55FF55) : SepiaTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.channel.name,
                  style: TextStyle(
                    fontFamily: isIrc ? 'Courier' : 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isIrc ? const Color(0xFF55FF55) : SepiaTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.era != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isIrc ? const Color(0xFF223322) : SepiaTheme.card,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isIrc ? const Color(0xFF335533) : SepiaTheme.border),
                    ),
                    child: Text(
                      '${widget.era!.year} • ${widget.era!.memoryConcept}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isIrc ? const Color(0xFF88FF88) : SepiaTheme.primary,
                      ),
                    ),
                  ),
                if (widget.channel.maxBufferTurns > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFEEBA)),
                    ),
                    child: Text(
                      'FIFO: ${widget.memoryBuffer?.currentTurns ?? 0}/${widget.channel.maxBufferTurns} Turns',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF856404)),
                    ),
                  ),
                ],
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.channel.topic,
                    style: TextStyle(fontSize: 11.5, color: isIrc ? const Color(0xFF88AA88) : SepiaTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),

          // FIFO Buffer Eviction Warning Banner
          if (hasEviction)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              color: const Color(0xFFFFF3CD),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFF856404)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Short-Term Memory FIFO Eviction: Buffer capacity (${widget.channel.maxBufferTurns} turns) reached. ${widget.memoryBuffer!.evictedCount} turns displaced, enforcing volatile RAM limits.',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF856404), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Thread Scratchpad Isolation Banner if active
          if (widget.activeThreadId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: SepiaTheme.primaryLight,
              child: Row(
                children: [
                  const Icon(Icons.fork_right, size: 16, color: SepiaTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'THREAD SCRATCHPAD: ${widget.activeThreadId} (Sub-Task Context Isolation)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 14, color: SepiaTheme.primary),
                    label: const Text('Exit to Channel Stream', style: TextStyle(fontSize: 11, color: SepiaTheme.primary)),
                    onPressed: widget.onCloseThread,
                  ),
                ],
              ),
            ),

          // Message Stream
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages in this stream yet.\nSend a message or select a prompt below to interact.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isIrc ? const Color(0xFF88AA88) : SepiaTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.messages[index];
                      return _MessageTile(
                        message: msg,
                        isIrc: isIrc,
                        onSelect: () => widget.onSelectMessageForInspector(msg),
                        onOpenThread: widget.activeThreadId == null
                            ? () => widget.onOpenThread(msg.threadId ?? 'thread-${msg.id}')
                            : null,
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
                    '${widget.typingAgentName} is synthesizing response via Gemini 3.8...',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isIrc ? const Color(0xFF88FF88) : SepiaTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Composer & Quick Prompts
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isIrc ? const Color(0xFF141714) : SepiaTheme.surface,
              border: Border(top: BorderSide(color: isIrc ? const Color(0xFF2E382E) : SepiaTheme.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Historical Demo Prompts
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Demo Prompts: ',
                        style: TextStyle(fontSize: 11, color: isIrc ? const Color(0xFF88AA88) : SepiaTheme.textMuted),
                      ),
                      ...quickPrompts.map((p) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(p, style: TextStyle(fontSize: 11, color: isIrc ? const Color(0xFF55FF55) : SepiaTheme.primary)),
                              backgroundColor: isIrc ? const Color(0xFF223322) : SepiaTheme.primaryLight,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () => _insertQuickPrompt(p),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) => _handleSend(),
                        style: TextStyle(
                          color: isIrc ? const Color(0xFF55FF55) : SepiaTheme.textPrimary,
                          fontFamily: isIrc ? 'Courier' : null,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.activeThreadId != null
                              ? 'Reply in thread scratchpad...'
                              : (isIrc ? 'Type IRC command or question (e.g. @eggdrop hello)...' : 'Message #${widget.channel.name}...'),
                          hintStyle: TextStyle(fontSize: 12.5, color: isIrc ? const Color(0xFF558855) : SepiaTheme.textMuted),
                          filled: true,
                          fillColor: isIrc ? const Color(0xFF0F120F) : SepiaTheme.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: isIrc ? const Color(0xFF335533) : SepiaTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: isIrc ? const Color(0xFF335533) : SepiaTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: isIrc ? const Color(0xFF55FF55) : SepiaTheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isIrc ? const Color(0xFF2E662E) : SepiaTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _handleSend,
                      child: const Row(
                        children: [
                          Icon(Icons.send, size: 14),
                          SizedBox(width: 6),
                          Text('Send', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
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
}

class _MessageTile extends StatelessWidget {
  final Message message;
  final bool isIrc;
  final VoidCallback onSelect;
  final VoidCallback? onOpenThread;

  const _MessageTile({
    required this.message,
    required this.isIrc,
    required this.onSelect,
    this.onOpenThread,
  });

  @override
  Widget build(BuildContext context) {
    final isAgent = message.senderType == 'agent';
    final isSystem = message.senderType == 'system';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isIrc
            ? const Color(0xFF141714)
            : (isSystem ? const Color(0xFFFAF6EE) : SepiaTheme.surface),
        border: Border.all(
          color: isIrc
              ? const Color(0xFF2E382E)
              : (isSystem ? const Color(0xFFEADBCE) : SepiaTheme.border),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isIrc
                    ? const Color(0xFF223322)
                    : (isAgent
                        ? SepiaTheme.primaryLight
                        : (isSystem ? Colors.amber.shade100 : Colors.blueGrey.shade100)),
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isIrc ? const Color(0xFF55FF55) : (isAgent ? SepiaTheme.primary : SepiaTheme.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: isIrc ? 'Courier' : null,
                  color: isIrc ? const Color(0xFF55FF55) : SepiaTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (isAgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isIrc ? const Color(0xFF223322) : SepiaTheme.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'GEMINI 3.8',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isIrc ? const Color(0xFF88FF88) : SepiaTheme.primary,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10.5, color: isIrc ? const Color(0xFF558855) : SepiaTheme.textMuted),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Message Content
          SelectableText(
            message.content,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontFamily: isIrc ? 'Courier' : null,
              color: isIrc ? const Color(0xFFD0FFD0) : SepiaTheme.textPrimary,
            ),
          ),

          // Intent Pills Row
          if (message.intentTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: message.intentTags.map((tag) {
                return _IntentPill(tag: tag, onTap: onSelect);
              }).toList(),
            ),
          ],

          // Footer action bar
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onOpenThread != null)
                TextButton.icon(
                  icon: const Icon(Icons.forum_outlined, size: 12, color: SepiaTheme.primary),
                  label: const Text('Thread Scratchpad', style: TextStyle(fontSize: 10.5, color: SepiaTheme.primary)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                  onPressed: onOpenThread,
                ),
              TextButton.icon(
                icon: const Icon(Icons.analytics_outlined, size: 12, color: SepiaTheme.accent),
                label: const Text('Inspect Memory Lens', style: TextStyle(fontSize: 10.5, color: SepiaTheme.accent)),
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

class _IntentPill extends StatelessWidget {
  final IntentTag tag;
  final VoidCallback onTap;

  const _IntentPill({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (tag.type) {
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
              Icon(Icons.memory, size: 11, color: fg),
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
