import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_models.dart';

/// 1988 IRC Terminal View
/// Fullscreen retro green-on-black CRT terminal window (#33FF33 on #0A0D0A).
/// Demonstrates Short-Term Memory (STM) & FIFO Buffer Eviction (The Amnesia Trap).
class IrcTerminalView extends StatefulWidget {
  final Channel channel;
  final List<Message> messages;
  final MemoryBuffer? buffer;
  final Function(String) onSendMessage;
  final String? typingAgentName;

  const IrcTerminalView({
    super.key,
    required this.channel,
    required this.messages,
    this.buffer,
    required this.onSendMessage,
    this.typingAgentName,
  });

  @override
  State<IrcTerminalView> createState() => _IrcTerminalViewState();
}

class _IrcTerminalViewState extends State<IrcTerminalView> {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _cursorVisible = true;
  Timer? _cursorTimer;

  static const Color crtGreen = Color(0xFF33FF33);
  static const Color crtGreenDim = Color(0xFF1E9E1E);
  static const Color crtGreenGlow = Color(0x6633FF33);
  static const Color crtBlack = Color(0xFF0A0D0A);
  static const Color crtDarkSurface = Color(0xFF060806);
  static const Color crtAlertAmber = Color(0xFFFFB000);

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) {
        setState(() => _cursorVisible = !_cursorVisible);
      }
    });
  }

  @override
  void didUpdateWidget(covariant IrcTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _commandController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isBurstRunning = false;

  void _handleCommandSubmit() {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;
    _commandController.clear();

    if (text == '/buffer-test' || text == '/buffertest') {
      _runBufferBurst();
      _focusNode.requestFocus();
      return;
    }

    widget.onSendMessage(text);
    _focusNode.requestFocus();
  }

  void _runBufferBurst() async {
    if (_isBurstRunning) return;
    setState(() => _isBurstRunning = true);
    try {
      final turns = [
        '!set-secret PROD_KEY=984210-CRITICAL-DO-NOT-LEAK',
        '!ping alpha-relay.internal',
        '!topic System v2.4 rollouts underway',
        '!status check DB connections',
        '!whois root',
        '!bot query What was the secret key set in turn 1?',
      ];
      for (final turn in turns) {
        await widget.onSendMessage(turn);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      if (mounted) {
        setState(() => _isBurstRunning = false);
      }
    }
  }

  void _insertQuickPrompt(String prompt) {
    if (prompt == '/buffer-test' || prompt == '/buffertest') {
      _runBufferBurst();
      return;
    }
    _commandController.text = prompt;
    _commandController.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
    _focusNode.requestFocus();
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxTurns = widget.buffer?.maxTurns ?? (widget.channel.maxBufferTurns > 0 ? widget.channel.maxBufferTurns : 5);
    final displayMessages = (widget.channel.maxBufferTurns > 0 && widget.messages.length > widget.channel.maxBufferTurns)
        ? widget.messages.sublist(widget.messages.length - widget.channel.maxBufferTurns)
        : widget.messages;
    final currentTurns = widget.buffer?.currentTurns ?? displayMessages.length;
    final evictedCount = widget.buffer?.evictedCount ?? 0;
    final hasEviction = evictedCount > 0;

    return Container(
      color: crtBlack,
      child: Stack(
        children: [
          // Subtle scanline raster backdrop
          Positioned.fill(
            child: CustomPaint(
              painter: _ScanlinePainter(),
            ),
          ),

          // Main Terminal Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Retro Status Bar
              _buildTopStatusBar(maxTurns, currentTurns, hasEviction),

              // 2. FIFO Amnesia Warning Banner (if turns evicted)
              if (hasEviction) _buildAmnesiaTrapBanner(evictedCount),

              // 3. Terminal Message Output Stream
              Expanded(
                child: GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: Container(
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: displayMessages.length + 1, // +1 for welcome motd
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildMotd();
                        }
                        final msg = displayMessages[index - 1];
                        return _buildIrcMessageLine(msg);
                      },
                    ),
                  ),
                ),
              ),

              // 4. Burst in progress indicator
              if (_isBurstRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  color: const Color(0xFF241804),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: crtAlertAmber),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '*** [BURST TEST]: Transmitting 6-turn sequence to overflow volatile RAM FIFO... ***',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11.5,
                          color: crtAlertAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // 5. Typing Indicator
              if (widget.typingAgentName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    '*** ${widget.typingAgentName} is transmitting across FUNET daemon (300 baud)...',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: crtGreenDim,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // 5. Command Line Input Bar & Quick Prompt Buttons
              _buildCommandLine(),
            ],
          ),

          // CRT Screen Glare & Border Frame
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1E3A1E), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33103010),
                      spreadRadius: 1,
                      blurRadius: 12,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top Status Bar:
  /// [1988 IRC: #irchelp] [FIFO RAM: 5/5 turns] ⚠ OVERFLOW (AMNESIA TRAP)
  Widget _buildTopStatusBar(int maxTurns, int currentTurns, bool hasEviction) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: crtGreen,
        boxShadow: [
          BoxShadow(
            color: crtGreenGlow,
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              '[1988 IRC: #${widget.channel.name.isNotEmpty ? widget.channel.name : "irchelp"}]',
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: crtBlack,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '[FIFO RAM: $currentTurns/$maxTurns turns]',
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: crtBlack,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              hasEviction ? '⚠ OVERFLOW (AMNESIA ACTIVE)' : '● BUFFER STABLE',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: hasEviction ? const Color(0xFF8B0000) : crtBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Amnesia Trap Warning Banner
  Widget _buildAmnesiaTrapBanner(int evictedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF221100),
        border: Border(
          bottom: BorderSide(color: crtAlertAmber, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '*** [AMNESIA TRAP]: ',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: crtAlertAmber,
            ),
          ),
          Expanded(
            child: Text(
              'FIFO displacement: Turn evicted from RAM ($evictedCount lost). Pre-window facts evicted!',
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: crtAlertAmber,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.buffer?.lastEvictedMsg != null)
            Text(
              'Evicted: <${widget.buffer!.lastEvictedMsg!.senderName}>',
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                color: crtAlertAmber,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  /// Initial Message of the Day (MOTD) banner in IRC style
  Widget _buildMotd() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1B381B), width: 1),
        color: crtDarkSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '*** Welcome to 1988 IRC (irc.funet.fi) • Channel #${widget.channel.name.isNotEmpty ? widget.channel.name : "irchelp"}',
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: crtGreen, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text(
            '*** System: Ephemeral FIFO RAM (5-turn limit). Displaced turns are permanently lost.',
            style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: crtGreenDim),
          ),
        ],
      ),
    );
  }

  /// Classic IRC message format:
  /// `<sender>` message
  /// or *** system message
  Widget _buildIrcMessageLine(Message msg) {
    final isSystem = msg.senderType == 'system';
    final timeStr = _formatTimestamp(msg.createdAt);

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              height: 1.4,
              color: crtGreenDim,
            ),
            children: [
              TextSpan(text: '[$timeStr] *** '),
              TextSpan(
                text: msg.content,
                style: const TextStyle(color: crtGreen, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = msg.senderType == 'user';
    final senderColor = isUser ? crtGreen : const Color(0xFF66FF66);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'Courier',
            fontSize: 13,
            height: 1.4,
            color: crtGreen,
          ),
          children: [
            TextSpan(
              text: '[$timeStr] ',
              style: const TextStyle(color: crtGreenDim, fontSize: 11),
            ),
            TextSpan(
              text: '<${msg.senderName}> ',
              style: TextStyle(
                color: senderColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: msg.content,
              style: const TextStyle(color: Color(0xFFE0FFE0)),
            ),
          ],
        ),
      ),
    );
  }

  /// Terminal command line at bottom:
  /// > _ with quick prompt buttons
  Widget _buildCommandLine() {
    final quickPrompts = [
      '/help',
      '/op jason',
      '/buffer-test',
      '/names',
      '/motd',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: crtDarkSurface,
        border: Border(
          top: BorderSide(color: Color(0xFF224422), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick prompt shortcut buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'QUICK CMDS: ',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: crtGreenDim,
                  ),
                ),
                ...quickPrompts.map((cmd) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _insertQuickPrompt(cmd),
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF142414),
                          border: Border.all(color: crtGreenDim, width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          cmd,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: crtGreen,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _runBufferBurst,
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332000),
                      border: Border.all(color: crtAlertAmber, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 13, color: crtAlertAmber),
                        SizedBox(width: 4),
                        Text(
                          '💥 Trigger 6-Turn Amnesia Trap',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: crtAlertAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Command prompt row: > _
          Row(
            children: [
              const Text(
                '> ',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: crtGreen,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _commandController,
                  focusNode: _focusNode,
                  autofocus: true,
                  onSubmitted: (_) => _handleCommandSubmit(),
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    color: crtGreen,
                  ),
                  cursorColor: crtGreen,
                  cursorWidth: 8,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: 'Type IRC command or question (e.g. /buffer-test or @eggdrop hello)...',
                    hintStyle: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12.5,
                      color: crtGreenDim,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_cursorVisible)
                const Text(
                  '_',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: crtGreen,
                  ),
                )
              else
                const SizedBox(width: 9),
              const SizedBox(width: 8),
              InkWell(
                onTap: _handleCommandSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: crtGreenDim,
                    border: Border.all(color: crtGreen, width: 1),
                  ),
                  child: const Text(
                    'SEND [CR]',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: crtBlack,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for retro CRT horizontal scanline effect
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A00FF00)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
