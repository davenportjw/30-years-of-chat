import 'package:flutter/material.dart';
import '../theme/sepia_theme.dart';
import '../../models/chat_models.dart';

/// 2006 Campfire View (37signals Web 2.0 aesthetic)
/// Clean white/cream layout, warm tabs, yellow highlight fade, project-scoped rooms.
/// Memory Concept: Search Isolation & Context Fencing.
class CampfireView extends StatefulWidget {
  final List<Channel> channels;
  final Channel selectedChannel;
  final Function(Channel) onSelectChannel;
  final List<Message> messages;
  final Function(String) onSendMessage;
  final String? typingAgentName;

  const CampfireView({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.onSelectChannel,
    required this.messages,
    required this.onSendMessage,
    this.typingAgentName,
  });

  @override
  State<CampfireView> createState() => _CampfireViewState();
}

class _CampfireViewState extends State<CampfireView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Message? _selectedMessage;
  bool _soundsEnabled = true;

  // 37signals Web 2.0 Color Palette
  static const Color campfireCream = Color(0xFFF9F7F2);
  static const Color campfireWhite = Color(0xFFFFFFFF);
  static const Color campfireSidebarBg = Color(0xFFF0ECE1);
  static const Color campfireBorder = Color(0xFFDED8C9);
  static const Color campfireBorderDark = Color(0xFFC7BEAB);
  static const Color campfireText = Color(0xFF333333);
  static const Color campfireTextMuted = Color(0xFF777777);
  static const Color campfireGreen = Color(0xFF4B6E44);
  static const Color campfireTabBg = Color(0xFF566952);
  static const Color campfireYellowFade = Color(0xFFFFFDE3);
  static const Color campfireWarningBg = Color(0xFFFFF3CD);
  static const Color campfireWarningBorder = Color(0xFFFFEEBA);
  static const Color campfireWarningText = Color(0xFF856404);

  @override
  void didUpdateWidget(covariant CampfireView oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    widget.onSendMessage(text);
    _focusNode.requestFocus();
  }

  bool _isFencedMessage(Message msg) {
    return msg.intentTags.any((t) =>
        t.type == 'permission' ||
        t.type == 'scoping' ||
        t.label.toLowerCase().contains('fenc') ||
        t.label.toLowerCase().contains('permiss') ||
        t.label.toLowerCase().contains('isolat') ||
        t.label.toLowerCase().contains('quarantin'));
  }

  Message? get _quarantinedMessage {
    if (_selectedMessage != null && _isFencedMessage(_selectedMessage!)) {
      return _selectedMessage;
    }
    for (final m in widget.messages.reversed) {
      if (_isFencedMessage(m) ||
          m.senderName.contains('Firewall') ||
          m.senderId == 'context-firewall' ||
          m.content.toLowerCase().contains('firewall') ||
          m.content.toLowerCase().contains('quarantine')) {
        return m;
      }
    }
    return null;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min$ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: campfireCream,
      child: Column(
        children: [
          // 37signals Global Warm Header & Tabs
          _buildWeb2Header(),

          // Main Workspace: Left Sidebar + Center Transcript
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Sidebar: Project Rooms (#general-lobby, #engineering, #billing-confidential)
                _buildRoomsSidebar(),

                // Center Transcript Area (White Paper aesthetic)
                Expanded(
                  child: _buildTranscriptPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Web 2.0 Header & Tabs (37signals style)
  // ==========================================
  Widget _buildWeb2Header() {
    return Container(
      decoration: const BoxDecoration(
        color: campfireTabBg,
        border: Border(
          bottom: BorderSide(color: Color(0xFF3B4838), width: 2),
        ),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Logo
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: Color(0xFFFF9933), size: 24),
                SizedBox(width: 8),
                Text(
                  'Campfire',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'by 37signals (2006)',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB8CEB5), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Warm Tabs
          _buildTabItem('Lobby', false),
          _buildTabItem('Rooms', true),
          _buildTabItem('Transcripts', false),
          _buildTabItem('Files', false),

          const Spacer(),

          // Sound Toggle & User Info
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _soundsEnabled = !_soundsEnabled),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF445441),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _soundsEnabled ? Icons.volume_up : Icons.volume_off,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _soundsEnabled ? 'Sounds: On' : 'Sounds: Off',
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Jason Davenport',
                  style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? campfireCream : const Color(0xFF455542),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
        border: isSelected
            ? const Border(
                top: BorderSide(color: Color(0xFF3B4838), width: 1),
                left: BorderSide(color: Color(0xFF3B4838), width: 1),
                right: BorderSide(color: Color(0xFF3B4838), width: 1),
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? campfireText : const Color(0xFFD0DDD0),
        ),
      ),
    );
  }

  // ==========================================
  // Left Sidebar: Project Rooms
  // ==========================================
  Widget _buildRoomsSidebar() {
    // Standard 37signals rooms matching seeded channels
    final defaultRooms = [
      {'id': 'chan-2006-campfire-lobby', 'name': '#general-lobby', 'topic': 'Watercooler & Announcements', 'locked': false},
      {'id': 'chan-2006-campfire-eng', 'name': '#engineering', 'topic': 'Frontend & Web Services', 'locked': false},
      {'id': 'chan-2006-campfire', 'name': '#billing-confidential', 'topic': 'Project Apollo Billing & Ledger', 'locked': true},
    ];

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: campfireSidebarBg,
        border: Border(
          right: BorderSide(color: campfireBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: campfireBorder)),
            ),
            child: const Row(
              children: [
                Icon(Icons.folder_shared_outlined, size: 16, color: campfireGreen),
                SizedBox(width: 8),
                Text(
                  'PROJECT ROOMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: campfireGreen,
                  ),
                ),
              ],
            ),
          ),

          // Room List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Preset Web 2.0 rooms
                ...defaultRooms.map((r) {
                  final isSelected = widget.selectedChannel.id == r['id'] ||
                      (r['id'] == 'chan-2006-campfire' && widget.selectedChannel.name.contains('billing'));
                  final isLocked = r['locked'] as bool;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // Find matching channel from seeded channels
                        final match = widget.channels.firstWhere(
                          (c) => c.id == r['id'] || (r['id'] == 'chan-2006-campfire' && c.name.contains('billing')),
                          orElse: () => widget.selectedChannel,
                        );
                        if (match.id != widget.selectedChannel.id) {
                          widget.onSelectChannel(match);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? campfireWhite : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected ? campfireBorderDark : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? const [BoxShadow(color: Color(0x10000000), blurRadius: 3, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLocked ? Icons.lock : Icons.tag,
                              size: 14,
                              color: isSelected ? campfireGreen : campfireTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name'] as String,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? campfireGreen : campfireText,
                                    ),
                                  ),
                                  Text(
                                    r['topic'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected ? campfireText : campfireTextMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: campfireBorder, height: 1),
                ),

                // Other Channels in Repository
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'OTHER ARCHIVES',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: campfireTextMuted),
                  ),
                ),
                ...widget.channels.where((c) => !c.name.contains('campfire')).map((c) {
                  final isSelected = widget.selectedChannel.id == c.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                    child: InkWell(
                      onTap: () => widget.onSelectChannel(c),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? campfireWhite : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              c.allowedRoles.isNotEmpty ? Icons.lock_outline : Icons.chat_bubble_outline,
                              size: 13,
                              color: campfireTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '#${c.name}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isSelected ? campfireGreen : campfireText,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Context Fencing Legend Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFE8E2D5),
              border: Border(top: BorderSide(color: campfireBorder)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: campfireGreen),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Context Fencing Active • Room-Isolated Memory',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: campfireGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Center Transcript Area (Clean Web 2.0)
  // ==========================================
  Widget _buildTranscriptPanel() {
    final isLocked = widget.selectedChannel.allowedRoles.isNotEmpty || widget.selectedChannel.name.contains('campfire');
    final roomDisplayName = widget.selectedChannel.name.contains('campfire')
        ? '#billing-confidential'
        : '#${widget.selectedChannel.name}';

    return Container(
      color: campfireWhite,
      child: Column(
        children: [
          // Room Header Bar with Room Topic and Lock Icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: campfireWhite,
              border: Border(bottom: BorderSide(color: campfireBorder, width: 1)),
            ),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.lock : Icons.tag,
                  size: 20,
                  color: isLocked ? const Color(0xFFB54708) : campfireGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  roomDisplayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                    color: campfireText,
                  ),
                ),
                const SizedBox(width: 10),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3F2),
                      border: Border.all(color: const Color(0xFFFECDCA)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 10, color: Color(0xFFB54708)),
                        SizedBox(width: 4),
                        Text(
                          'RESTRICTED',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB54708)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.selectedChannel.topic,
                    style: const TextStyle(fontSize: 12, color: campfireTextMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Allowed roles badge
                if (widget.selectedChannel.allowedRoles.isNotEmpty)
                  Tooltip(
                    message: 'Allowed Roles: ${widget.selectedChannel.allowedRoles.join(", ")}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: campfireCream,
                        border: Border.all(color: campfireBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Roles: ${widget.selectedChannel.allowedRoles.length}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: campfireGreen),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Context Fenced Banner:
          // "Context Fenced: Domain-partitioned memory prevents cross-room prompt bleed"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF4EFE6), // Warm cream accent
              border: Border(bottom: BorderSide(color: Color(0xFFE2D7C5))),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, size: 16, color: campfireGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Context Fenced: Domain-partitioned memory prevents cross-room prompt bleed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF385234),
                    ),
                  ),
                ),
                Text(
                  'Search Isolation Active',
                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: campfireGreen),
                ),
              ],
            ),
          ),

          // Inline Quarantine Warning Card (displayed automatically if a quarantined message exists or is selected)
          if (_quarantinedMessage != null)
            _buildQuarantineWarningCard(_quarantinedMessage!),

          // Chat Transcript Stream
          Expanded(
            child: widget.messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forum_outlined, size: 36, color: campfireBorderDark),
                        SizedBox(height: 8),
                        Text(
                          'No chatter in this room yet.',
                          style: TextStyle(fontSize: 13, color: campfireTextMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.messages[index];
                      final isSelected = _selectedMessage?.id == msg.id;
                      final isRecent = index >= widget.messages.length - 2;

                      return _buildCampfireMessageRow(msg, isSelected: isSelected, isRecent: isRecent);
                    },
                  ),
          ),

          // Typing Indicator
          if (widget.typingAgentName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              alignment: Alignment.centerLeft,
              color: campfireCream,
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: campfireGreen),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.typingAgentName} is typing in $roomDisplayName...',
                    style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: campfireGreen),
                  ),
                ],
              ),
            ),

          // Web 2.0 Composer & "Say" button
          _buildComposer(),
        ],
      ),
    );
  }

  /// Inline Quarantine Warning Card
  Widget _buildQuarantineWarningCard(Message msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: campfireWarningBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: campfireWarningBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x10856404), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: campfireWarningText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'CONTEXT QUARANTINE WARNING',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: campfireWarningText,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Cross-Room Access Denied',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: campfireWarningText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Message from "${msg.senderName}" contains domain-fenced parameters. In accordance with Search Isolation, this context is quarantined within this room. Associative vector queries from other project rooms cannot access or bleed into this session.',
                  style: const TextStyle(fontSize: 11.5, color: campfireWarningText, height: 1.35),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: msg.intentTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: campfireWarningBorder),
                      ),
                      child: Text(
                        tag.label,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: campfireWarningText),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: campfireWarningText),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _selectedMessage = null),
          ),
        ],
      ),
    );
  }

  /// Campfire message row with clean typography, timestamp on left, and yellow highlight fade
  Widget _buildCampfireMessageRow(
    Message msg, {
    required bool isSelected,
    required bool isRecent,
  }) {
    final isUser = msg.senderType == 'user';
    final hasFencingTag = _isFencedMessage(msg);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMessage = (_selectedMessage?.id == msg.id) ? null : msg;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF7D6)
              : (isRecent ? campfireYellowFade : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE8D499)
                : (isRecent ? const Color(0xFFF7F2C8) : Colors.transparent),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Timestamp (Campfire style)
            SizedBox(
              width: 58,
              child: Text(
                _formatTime(msg.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: campfireTextMuted,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),

            // Center: Author Name & Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isUser ? const Color(0xFF2C5E28) : const Color(0xFF8A3B14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (msg.senderType == 'agent')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE8DB),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'AGENT',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: campfireGreen),
                          ),
                        ),
                      if (hasFencingTag) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0D4),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFFFFD188)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield, size: 9, color: Color(0xFFB54708)),
                              SizedBox(width: 3),
                              Text(
                                'FENCED',
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFB54708)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    msg.content,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: campfireText,
                    ),
                  ),

                  // Intent Tags Row
                  if (msg.intentTags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: msg.intentTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: SepiaTheme.tagContextBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SepiaTheme.tagContextText.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            tag.label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SepiaTheme.tagContextText),
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
      ),
    );
  }

  /// Campfire Composer with classic "Say" button
  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: campfireCream,
        border: Border(top: BorderSide(color: campfireBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _handleSend(),
                  style: const TextStyle(fontSize: 13.5, color: campfireText),
                  decoration: InputDecoration(
                    hintText: 'Speak into #${widget.selectedChannel.name}...',
                    hintStyle: const TextStyle(fontSize: 13, color: campfireTextMuted),
                    filled: true,
                    fillColor: campfireWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: campfireBorderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: campfireBorderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: campfireGreen, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Classic 37signals "Say" Button
              ElevatedButton(
                onPressed: _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: campfireGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 1,
                ),
                child: const Text(
                  'Say',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    _textController.text = 'Deploy Apollo billing patch to staging (Role Check)';
                    _focusNode.requestFocus();
                  },
                  child: const Text(
                    'Quick: Test Billing Fencing',
                    style: TextStyle(fontSize: 11, color: campfireGreen, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    _textController.text = 'Who has access permissions in this room?';
                    _focusNode.requestFocus();
                  },
                  child: const Text(
                    'Quick: Check Allowed Roles',
                    style: TextStyle(fontSize: 11, color: campfireGreen, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    _textController.text = '@researcher summarize confidential Apollo billing ledger';
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3F2),
                      border: Border.all(color: const Color(0xFFFECDCA)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: Color(0xFFB54708)),
                        SizedBox(width: 4),
                        Text(
                          '🛡️ Trigger Firewall Test (@researcher)',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB54708)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                const Text(
                  'Press Enter to Speak',
                  style: TextStyle(fontSize: 10.5, color: campfireTextMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
