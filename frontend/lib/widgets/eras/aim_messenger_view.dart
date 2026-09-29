import 'package:flutter/material.dart';
import '../../models/chat_models.dart';

/// 1997 AOL Instant Messenger (AIM) View
/// Authentic Windows 95/98 beveled window chrome, navy title bar, yellow running man icon.
/// Memory Concept: 1:1 Working Memory & Attentional State.
class AimMessengerView extends StatefulWidget {
  final List<Channel> channels;
  final Channel channel;
  final Function(Channel)? onSelectChannel;
  final List<Message> messages;
  final List<AgentPresence> presences;
  final Function(AgentPresence)? onUpdatePresence;
  final Function(String) onSendMessage;
  final String? typingAgentName;

  const AimMessengerView({
    super.key,
    this.channels = const [],
    required this.channel,
    this.onSelectChannel,
    required this.messages,
    required this.presences,
    this.onUpdatePresence,
    required this.onSendMessage,
    this.typingAgentName,
  });

  @override
  State<AimMessengerView> createState() => _AimMessengerViewState();
}

class _AimMessengerViewState extends State<AimMessengerView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Formatting toggles (authentic AIM formatting toolbar)
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  Color _fontColor = const Color(0xFF000000);

  // Selected buddy for 1:1 conversation
  AgentPresence? _selectedBuddy;

  // Authentic Win95 Palette
  static const Color winBg = Color(0xFFC0C0C0);
  static const Color winSurface = Color(0xFFFFFFFF);
  static const Color winNavy = Color(0xFF000080);
  static const Color winNavyLight = Color(0xFF1084D0);
  static const Color winBorderLight = Color(0xFFFFFFFF);
  static const Color winBorderDark = Color(0xFF808080);
  static const Color winBorderBlack = Color(0xFF000000);
  static const Color aimYellow = Color(0xFFFFCC00);

  @override
  void initState() {
    super.initState();
    _initSelectedBuddy();
  }

  @override
  void didUpdateWidget(covariant AimMessengerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel.id != oldWidget.channel.id || _selectedBuddy == null) {
      _initSelectedBuddy();
    } else {
      final updated = widget.presences.cast<AgentPresence?>().firstWhere(
        (p) => p?.agentId == _selectedBuddy!.agentId,
        orElse: () => null,
      );
      if (updated != null) {
        _selectedBuddy = updated;
      } else {
        _initSelectedBuddy();
      }
    }
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _initSelectedBuddy() {
    if (widget.presences.isNotEmpty) {
      if (widget.channel.id.contains('scribe') || widget.channel.name.contains('scribe')) {
        _selectedBuddy = widget.presences.firstWhere(
          (p) => p.agentId == 'scribe-agent',
          orElse: () => widget.presences.first,
        );
      } else if (widget.channel.id.contains('researcher') || widget.channel.name.contains('researcher')) {
        _selectedBuddy = widget.presences.firstWhere(
          (p) => p.agentId == 'researcher-agent',
          orElse: () => widget.presences.first,
        );
      } else {
        _selectedBuddy = widget.presences.firstWhere(
          (p) => p.agentId == 'lead-agent',
          orElse: () => widget.presences.first,
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    widget.onSendMessage(text);
    _focusNode.requestFocus();
  }

  void _toggleAwayForBuddy(AgentPresence buddy) {
    if (widget.onUpdatePresence == null) return;
    final newStatus = buddy.status == 'away' ? 'available' : 'away';
    final newStatusMsg = newStatus == 'away'
        ? 'Away: reviewing code, leave a message'
        : 'Available / Coordinating working memory';

    final updated = AgentPresence(
      agentId: buddy.agentId,
      agentName: buddy.agentName,
      avatarUrl: buddy.avatarUrl,
      status: newStatus,
      statusMessage: newStatusMsg,
      currentTask: buddy.currentTask,
      lastHeartbeat: DateTime.now(),
    );

    widget.onUpdatePresence!(updated);
    setState(() {
      if (_selectedBuddy?.agentId == buddy.agentId) {
        _selectedBuddy = updated;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: winNavy,
        content: Text(
          'AIM Presence Updated: ${buddy.agentName} is now $newStatus ("$newStatusMsg")',
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      ),
    );
  }

  void _showAwayEditDialog(AgentPresence buddy) {
    final controller = TextEditingController(text: buddy.statusMessage);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: winBg,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: winBorderBlack, width: 2),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: winNavy,
          child: Row(
            children: [
              _buildRunningMan(14),
              const SizedBox(width: 6),
              Text(
                'Edit Away Message - ${buddy.agentName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set custom Away Message to prime the agent\'s attentional persona:',
              style: TextStyle(fontSize: 12, color: winBorderBlack),
            ),
            const SizedBox(height: 10),
            _buildSunkenContainer(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(fontSize: 13, fontFamily: 'Arial'),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _buildBeveledButton(
            text: 'Save & Set Away',
            onPressed: () {
              Navigator.pop(ctx);
              final updated = AgentPresence(
                agentId: buddy.agentId,
                agentName: buddy.agentName,
                avatarUrl: buddy.avatarUrl,
                status: 'away',
                statusMessage: controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : 'Away: reviewing code, leave a message',
                currentTask: buddy.currentTask,
                lastHeartbeat: DateTime.now(),
              );
              if (widget.onUpdatePresence != null) {
                widget.onUpdatePresence!(updated);
              }
              setState(() {
                if (_selectedBuddy?.agentId == buddy.agentId) {
                  _selectedBuddy = updated;
                }
              });
            },
          ),
          _buildBeveledButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showWarnDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: winBg,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: winBorderBlack, width: 2),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: winNavy,
          child: const Text(
            'AIM Warning Level',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        titlePadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 36, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              'Warning sent to ${_selectedBuddy?.agentName ?? "Agent"}.\nIn 1997 AIM, excessive warning increases rate-limiting throttle.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          _buildBeveledButton(text: 'OK', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF557799), // Classic Windows 95 teal/desktop background
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Window: AIM Buddy List (~290px)
          SizedBox(
            width: 290,
            child: _buildBuddyListWindow(),
          ),

          const SizedBox(width: 12),

          // Right Window: 1:1 Direct Chat Window (Expanded)
          Expanded(
            child: _buildDirectChatWindow(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Left Window: AIM Buddy List
  // ==========================================
  Widget _buildBuddyListWindow() {
    final activeBuddyCount = widget.presences.where((p) => p.status == 'available').length;

    return _buildWindowFrame(
      title: 'Buddy List - Jason Davenport',
      showMaxButton: false,
      child: Column(
        children: [
          // Win95 Menubar
          _buildMenuBar(['File', 'People', 'Options', 'Help']),

          // Memory Concept Info Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFFFFFFD0), // Pale yellow post-it note
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: winNavy),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Working Memory: Agent presence reflects real-time attentional availability.',
                    style: TextStyle(fontSize: 10.5, color: winNavy, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: winBorderDark),

          // Buddy List Tree
          Expanded(
            child: _buildSunkenContainer(
              margin: const EdgeInsets.all(6),
              child: ListView(
                padding: const EdgeInsets.all(4),
                children: [
                  // Buddy group header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_drop_down, size: 16, color: winBorderBlack),
                        const Text(
                          'Buddies',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($activeBuddyCount/${widget.presences.length} Online)',
                          style: const TextStyle(fontSize: 11, color: winBorderDark),
                        ),
                      ],
                    ),
                  ),

                  // Active Buddies
                  if (widget.presences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Connecting to AIM TOC servers...', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                    )
                  else
                    ...widget.presences.map((buddy) => _buildBuddyItem(buddy)),

                  const Divider(color: winBorderDark, height: 16),

                  // Offline Group (stub for authentic look)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right, size: 16, color: winBorderDark),
                        Text(
                          'Offline (0)',
                          style: TextStyle(fontSize: 11, color: winBorderDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Buddy List Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildBeveledButton(
                    text: 'IM',
                    height: 26,
                    onPressed: () {
                      if (_selectedBuddy != null) {
                        _focusNode.requestFocus();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildBeveledButton(
                    text: 'Away Msg',
                    height: 26,
                    onPressed: () {
                      if (_selectedBuddy != null) {
                        _showAwayEditDialog(_selectedBuddy!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildBeveledButton(
                    text: 'Setup',
                    height: 26,
                    onPressed: () {
                      if (_selectedBuddy != null) {
                        _toggleAwayForBuddy(_selectedBuddy!);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuddyItem(AgentPresence buddy) {
    final isSelected = _selectedBuddy?.agentId == buddy.agentId;
    final isAway = buddy.status == 'away';
    final isAvailable = buddy.status == 'available';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedBuddy = buddy);
        if (widget.onSelectChannel != null && widget.channels.isNotEmpty) {
          Channel? targetChan;
          if (buddy.agentId == 'scribe-agent') {
            targetChan = widget.channels.firstWhere(
              (c) => (c.eraId == 'era-1997-aim' || c.id.startsWith('chan-1997')) && (c.id.contains('scribe') || c.name.contains('scribe')),
              orElse: () => widget.channel,
            );
          } else if (buddy.agentId == 'researcher-agent') {
            targetChan = widget.channels.firstWhere(
              (c) => (c.eraId == 'era-1997-aim' || c.id.startsWith('chan-1997')) && (c.id.contains('researcher') || c.name.contains('researcher')),
              orElse: () => widget.channel,
            );
          } else {
            targetChan = widget.channels.firstWhere(
              (c) => (c.eraId == 'era-1997-aim' || c.id.startsWith('chan-1997')) && (c.id == 'chan-1997-aim' || c.name.contains('lead')),
              orElse: () => widget.channel,
            );
          }
          if (targetChan.id != widget.channel.id) {
            widget.onSelectChannel!(targetChan);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? winNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            // Status Icon: Door icon if away, green dot if available, yellow running man
            if (isAway)
              const Icon(Icons.meeting_room, size: 14, color: Colors.orange)
            else if (isAvailable)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              )
            else
              const Icon(Icons.circle, size: 10, color: Colors.grey),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buddy.agentName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : winBorderBlack,
                    ),
                  ),
                  Text(
                    buddy.statusMessage.isNotEmpty
                        ? buddy.statusMessage
                        : (isAway ? 'Away: reviewing code, leave a message' : 'Online'),
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: isAway ? FontStyle.italic : FontStyle.normal,
                      color: isSelected
                          ? (isAway ? aimYellow : const Color(0xFFD0D0FF))
                          : (isAway ? Colors.amber.shade900 : winBorderDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Quick Away toggle action
            IconButton(
              icon: Icon(
                isAway ? Icons.check_circle_outline : Icons.snooze,
                size: 14,
                color: isSelected ? Colors.white70 : winBorderDark,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: isAway ? 'Clear Away status' : 'Set Away Message',
              onPressed: () => _toggleAwayForBuddy(buddy),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Right Window: 1:1 Direct Chat Window
  // ==========================================
  Widget _buildDirectChatWindow() {
    final buddyName = _selectedBuddy?.agentName ?? 'Lead Coordinator';
    final title = 'Instant Message with $buddyName';

    // Determine the active channel ID for the selected buddy session
    String targetChanId = widget.channel.id;
    if (_selectedBuddy != null) {
      if (_selectedBuddy!.agentId == 'scribe-agent') {
        targetChanId = 'chan-1997-aim-scribe';
      } else if (_selectedBuddy!.agentId == 'researcher-agent') {
        targetChanId = 'chan-1997-aim-researcher';
      } else {
        targetChanId = 'chan-1997-aim';
      }
    }

    // Filter messages to strictly ensure only messages belonging to this buddy's channel are displayed
    final channelMessages = widget.messages.where((m) {
      if (m.channelId.isEmpty) return true;
      return m.channelId == targetChanId || (widget.channel.id == targetChanId && m.channelId == widget.channel.id);
    }).toList();

    return _buildWindowFrame(
      title: title,
      showMaxButton: true,
      child: Column(
        children: [
          // Menubar
          _buildMenuBar(['File', 'Edit', 'Insert', 'People']),

          // Attentional State & Working Memory Banner
          if (_selectedBuddy != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7D6),
                border: Border(bottom: BorderSide(color: Color(0xFFE0D0A0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: winNavy),
                  const SizedBox(width: 6),
                  Text(
                    '1:1 Working Memory • $buddyName',
                    style: const TextStyle(fontSize: 11, color: winNavy, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_selectedBuddy!.status == 'away')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'AWAY',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

          // Authentic AIM Away Message Auto-Reply Notice Card
          if (_selectedBuddy != null && _selectedBuddy!.status == 'away')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFD8),
                border: Border.all(color: Colors.amber.shade800, width: 1.5),
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 3,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.snooze, size: 20, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '*** ${_selectedBuddy!.agentName} IS AWAY ***',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () => _toggleAwayForBuddy(_selectedBuddy!),
                              child: const Text(
                                '[Clear Away]',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: winNavy,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showAwayEditDialog(_selectedBuddy!),
                              child: const Text(
                                '[Edit Msg]',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: winNavy,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '"${_selectedBuddy!.statusMessage.isNotEmpty ? _selectedBuddy!.statusMessage : "Away: reviewing code, leave a message"}"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Conversation Log (Sunken Box)
          Expanded(
            flex: 6,
            child: _buildSunkenContainer(
              margin: const EdgeInsets.all(6),
              child: channelMessages.isEmpty
                  ? Center(
                      child: Text(
                        'Direct message session started with $buddyName.\nNo messages yet. Send a greeting to begin!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: winBorderDark, fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: channelMessages.length,
                      itemBuilder: (context, index) {
                        final msg = channelMessages[index];
                        return _buildAimChatMessage(msg);
                      },
                    ),
            ),
          ),

          // Formatting Toolbar (B, I, U, Color, Size, Link, Smiley)
          _buildFormattingToolbar(),

          // Educational Quick Inquiries for Working Memory & Persona Testing
          _buildQuickInquiryBar(),

          // Text Input Box (Sunken Box)
          Expanded(
            flex: 3,
            child: _buildSunkenContainer(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                onSubmitted: (_) => _handleSend(),
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 13,
                  fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                  decoration: _isUnderline ? TextDecoration.underline : TextDecoration.none,
                  color: _fontColor,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Enter your message here...',
                  hintStyle: TextStyle(fontSize: 12, color: winBorderDark),
                ),
              ),
            ),
          ),

          // Action Buttons Bar: Send, Warn, Block, Away Msg
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                _buildBeveledButton(
                  text: 'Send',
                  isDefault: true,
                  width: 80,
                  height: 28,
                  onPressed: _handleSend,
                ),
                const SizedBox(width: 8),
                _buildBeveledButton(
                  text: 'Warn',
                  width: 70,
                  height: 28,
                  onPressed: _showWarnDialog,
                ),
                const SizedBox(width: 8),
                _buildBeveledButton(
                  text: 'Block',
                  width: 70,
                  height: 28,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Agent blocked from sending direct alerts.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                if (_selectedBuddy != null)
                  _buildBeveledButton(
                    text: 'Away: ${_selectedBuddy!.status == "away" ? "Clear" : "Set"}',
                    width: 95,
                    height: 28,
                    onPressed: () => _toggleAwayForBuddy(_selectedBuddy!),
                  ),
                const Spacer(),
                // Typing status or clock
                if (widget.typingAgentName != null) ...[
                  const Icon(Icons.edit, size: 14, color: winNavy),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.typingAgentName} is typing...',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: winNavy),
                  ),
                ] else
                  const Text(
                    'Ready',
                    style: TextStyle(fontSize: 11, color: winBorderDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formatting toolbar with classic AIM buttons (B, I, U, Color, Link, Smiley)
  Widget _buildFormattingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: winBg,
      child: Row(
        children: [
          // Bold
          _buildToolbarButton(
            label: 'B',
            isToggled: _isBold,
            style: const TextStyle(fontWeight: FontWeight.bold),
            onTap: () => setState(() => _isBold = !_isBold),
          ),
          const SizedBox(width: 4),
          // Italic
          _buildToolbarButton(
            label: 'I',
            isToggled: _isItalic,
            style: const TextStyle(fontStyle: FontStyle.italic),
            onTap: () => setState(() => _isItalic = !_isItalic),
          ),
          const SizedBox(width: 4),
          // Underline
          _buildToolbarButton(
            label: 'U',
            isToggled: _isUnderline,
            style: const TextStyle(decoration: TextDecoration.underline),
            onTap: () => setState(() => _isUnderline = !_isUnderline),
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 10, thickness: 1, color: winBorderDark),
          const SizedBox(width: 4),
          // Font color palette icon
          InkWell(
            onTap: () {
              setState(() {
                if (_fontColor == Colors.black) {
                  _fontColor = Colors.blue.shade900;
                } else if (_fontColor == Colors.blue.shade900) {
                  _fontColor = Colors.red.shade900;
                } else {
                  _fontColor = Colors.black;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: winBorderDark),
                color: winBg,
              ),
              child: Row(
                children: [
                  const Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(width: 3),
                  Container(width: 10, height: 4, color: _fontColor),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Link icon
          InkWell(
            onTap: () {
              _messageController.text += ' http://www.aol.com ';
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.link, size: 14, color: winBorderBlack),
            ),
          ),
          const SizedBox(width: 6),
          // Smiley icon
          InkWell(
            onTap: () {
              _messageController.text += ' :-) ';
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.sentiment_satisfied_alt, size: 14, color: winBorderBlack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required String label,
    required bool isToggled,
    required TextStyle style,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isToggled ? const Color(0xFFD8D8D8) : winBg,
          border: isToggled
              ? Border(
                  top: const BorderSide(color: winBorderDark, width: 1.5),
                  left: const BorderSide(color: winBorderDark, width: 1.5),
                  bottom: const BorderSide(color: winBorderLight, width: 1.5),
                  right: const BorderSide(color: winBorderLight, width: 1.5),
                )
              : Border(
                  top: const BorderSide(color: winBorderLight, width: 1.5),
                  left: const BorderSide(color: winBorderLight, width: 1.5),
                  bottom: const BorderSide(color: winBorderDark, width: 1.5),
                  right: const BorderSide(color: winBorderDark, width: 1.5),
                ),
        ),
        child: Text(label, style: style.copyWith(fontSize: 12, color: winBorderBlack)),
      ),
    );
  }

  Widget _buildQuickInquiryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: const Color(0xFFDCD8D0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.bolt, size: 13, color: winNavy),
            const SizedBox(width: 4),
            const Text(
              'Prompts: ',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: winNavy),
            ),
            _buildPromptChip(
              'Probe Boundary',
              'What is Scribe working on in their private session?',
            ),
            const SizedBox(width: 6),
            _buildPromptChip(
              'Test Memory',
              'What was the last requirement we agreed upon in this 1:1 chat?',
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                if (_selectedBuddy != null) {
                  _showAwayEditDialog(_selectedBuddy!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0C0),
                  border: Border.all(color: Colors.amber.shade800, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 12, color: Colors.black87),
                    SizedBox(width: 3),
                    Text(
                      'Prime Away Memo',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String label, String prompt) {
    return InkWell(
      onTap: () {
        _messageController.text = prompt;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: prompt.length),
        );
        _focusNode.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: winBg,
          border: Border.all(color: winBorderDark, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: winNavy),
        ),
      ),
    );
  }

  /// Classic AIM chat message line:
  /// Jason Davenport: Message text...
  /// Lead Coordinator: Response text...
  Widget _buildAimChatMessage(Message msg) {
    final isUser = msg.senderType == 'user';
    final nameColor = isUser ? const Color(0xFF0000FF) : const Color(0xFFFF0000); // Classic AIM blue & red sender names

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 12.5,
                height: 1.35,
                color: winBorderBlack,
              ),
              children: [
                TextSpan(
                  text: '${msg.senderName}: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: nameColor,
                  ),
                ),
                TextSpan(text: msg.content),
              ],
            ),
          ),
          if (msg.intentTags.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 4,
              children: msg.intentTags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF8),
                    border: Border.all(color: winNavy.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    t.label,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: winNavy),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // Windows 95/98 Chrome & Bevel Builders
  // ==========================================

  /// Classic Windows 95 outer window with 3D raised border and navy title bar
  Widget _buildWindowFrame({
    required String title,
    required Widget child,
    bool showMaxButton = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: winBg,
        border: Border(
          top: const BorderSide(color: winBorderLight, width: 2),
          left: const BorderSide(color: winBorderLight, width: 2),
          bottom: const BorderSide(color: winBorderBlack, width: 2),
          right: const BorderSide(color: winBorderBlack, width: 2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 4,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navy Title Bar with Running Man and [ _ | □ | X ]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [winNavy, winNavyLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                _buildRunningMan(16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Window Control Buttons [ _ | □ | X ]
                _buildWindowControlButton('_', () {}),
                if (showMaxButton) ...[
                  const SizedBox(width: 2),
                  _buildWindowControlButton('□', () {}),
                ],
                const SizedBox(width: 2),
                _buildWindowControlButton('X', () {}),
              ],
            ),
          ),

          // Window Interior
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildWindowControlButton(String symbol, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 16,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: winBg,
          border: Border(
            top: const BorderSide(color: winBorderLight, width: 1.5),
            left: const BorderSide(color: winBorderLight, width: 1.5),
            bottom: const BorderSide(color: winBorderBlack, width: 1.5),
            right: const BorderSide(color: winBorderBlack, width: 1.5),
          ),
        ),
        child: Text(
          symbol,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: winBorderBlack,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuBar(List<String> items) {
    return Container(
      color: winBg,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                item,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 11.5,
                  color: winBorderBlack,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSunkenContainer({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: winSurface,
        border: Border(
          top: const BorderSide(color: winBorderDark, width: 1.5),
          left: const BorderSide(color: winBorderDark, width: 1.5),
          bottom: const BorderSide(color: winBorderLight, width: 1.5),
          right: const BorderSide(color: winBorderLight, width: 1.5),
        ),
      ),
      child: child,
    );
  }

  Widget _buildBeveledButton({
    required String text,
    VoidCallback? onPressed,
    double? width,
    double height = 24,
    bool isDefault = false,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: winBg,
          border: isDefault
              ? Border.all(color: winBorderBlack, width: 1)
              : null,
          boxShadow: isDefault
              ? null
              : const [
                  BoxShadow(color: winBorderLight, offset: Offset(-1, -1)),
                  BoxShadow(color: winBorderBlack, offset: Offset(1, 1)),
                ],
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              top: const BorderSide(color: winBorderLight, width: 1.5),
              left: const BorderSide(color: winBorderLight, width: 1.5),
              bottom: const BorderSide(color: winBorderDark, width: 1.5),
              right: const BorderSide(color: winBorderDark, width: 1.5),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 11.5,
              fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
              color: winBorderBlack,
            ),
          ),
        ),
      ),
    );
  }

  /// Stylized Yellow Running Man Icon (AOL Mascot)
  Widget _buildRunningMan(double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: aimYellow,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.directions_run,
        size: size * 0.85,
        color: winBorderBlack,
      ),
    );
  }
}
