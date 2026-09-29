import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/sepia_theme.dart';

class LeftNavPanel extends StatelessWidget {
  final List<Era> eras;
  final Era? selectedEra;
  final Function(Era) onSelectEra;
  final List<Channel> channels;
  final Channel? selectedChannel;
  final Function(Channel) onSelectChannel;
  final List<AgentPresence> presences;
  final Function(AgentPresence)? onUpdatePresence;
  final PacingMode? pacing;
  final Function(PacingMode)? onUpdatePacing;
  final VoidCallback onReseed;
  final bool isReseeding;

  const LeftNavPanel({
    super.key,
    required this.eras,
    required this.selectedEra,
    required this.onSelectEra,
    required this.channels,
    required this.selectedChannel,
    required this.onSelectChannel,
    this.presences = const [],
    this.onUpdatePresence,
    this.pacing,
    this.onUpdatePacing,
    required this.onReseed,
    this.isReseeding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: SepiaTheme.card,
        border: Border(
          right: BorderSide(color: SepiaTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: SepiaTheme.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: SepiaTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.history_edu, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Agents of Chat',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: SepiaTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  '30 Years of Chat & Agent Memory Evolution',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: SepiaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Sections: Eras Timeline, Channels, Buddy List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // 1. Era Evolution Stepper
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EVOLUTIONARY ERAS (1988–2026)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: SepiaTheme.textMuted,
                        ),
                      ),
                      Text(
                        '${eras.length} ERAS',
                        style: const TextStyle(fontSize: 10, color: SepiaTheme.textMuted),
                      ),
                    ],
                  ),
                ),

                ...eras.map((era) {
                  final isSelected = selectedEra?.id == era.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: InkWell(
                      onTap: () => onSelectEra(era),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? SepiaTheme.primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? SepiaTheme.primary : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? SepiaTheme.primary : SepiaTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: SepiaTheme.border),
                              ),
                              child: Text(
                                '${era.year}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : SepiaTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    era.name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? SepiaTheme.primary : SepiaTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    era.memoryConcept,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isSelected ? SepiaTheme.primary : SepiaTheme.textSecondary,
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
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: SepiaTheme.border),
                ),

                // 2. Channels Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ERA CHANNELS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: SepiaTheme.textMuted,
                        ),
                      ),
                      const Icon(Icons.tag, size: 14, color: SepiaTheme.textMuted),
                    ],
                  ),
                ),

                ...channels.map((ch) {
                  final isSelected = selectedChannel?.id == ch.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
                    child: InkWell(
                      onTap: () => onSelectChannel(ch),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? SepiaTheme.primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              ch.isDirectMessage ? Icons.person_outline : Icons.tag,
                              size: 15,
                              color: isSelected ? SepiaTheme.primary : SepiaTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ch.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? SepiaTheme.primary : SepiaTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ch.maxBufferTurns > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: SepiaTheme.card,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: SepiaTheme.border),
                                ),
                                child: Text(
                                  'FIFO:${ch.maxBufferTurns}',
                                  style: const TextStyle(fontSize: 9, color: SepiaTheme.textMuted),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: SepiaTheme.border),
                ),

                // 3. Buddy List & Attentional Presence Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BUDDY LIST & PRESENCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: SepiaTheme.textMuted,
                        ),
                      ),
                      const Icon(Icons.circle, size: 10, color: Colors.green),
                    ],
                  ),
                ),

                if (presences.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'No agent presences loaded.',
                      style: TextStyle(fontSize: 11, color: SepiaTheme.textMuted),
                    ),
                  )
                else
                  ...presences.map((p) => _BuddyPresenceTile(
                        presence: p,
                        onToggleAway: onUpdatePresence != null
                            ? () {
                                final newStatus = p.status == 'away' ? 'available' : 'away';
                                final newMsg = newStatus == 'away'
                                    ? 'Stepped out for RFC review'
                                    : 'Available / Standing by';
                                onUpdatePresence!(AgentPresence(
                                  agentId: p.agentId,
                                  agentName: p.agentName,
                                  avatarUrl: p.avatarUrl,
                                  status: newStatus,
                                  statusMessage: newMsg,
                                  currentTask: p.currentTask,
                                  lastHeartbeat: DateTime.now(),
                                ));
                              }
                            : null,
                      )),
              ],
            ),
          ),

          const Divider(height: 1, color: SepiaTheme.border),

          // Re-seed Controls
          Container(
            padding: const EdgeInsets.all(14),
            color: SepiaTheme.background,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: isReseeding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: SepiaTheme.primary),
                      )
                    : const Icon(Icons.refresh, size: 14, color: SepiaTheme.primary),
                label: const Text(
                  'Reset & Re-seed 6-Era Scenarios',
                  style: TextStyle(fontSize: 11.5, color: SepiaTheme.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: SepiaTheme.borderStrong),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: isReseeding ? null : onReseed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuddyPresenceTile extends StatelessWidget {
  final AgentPresence presence;
  final VoidCallback? onToggleAway;

  const _BuddyPresenceTile({
    required this.presence,
    this.onToggleAway,
  });

  Color _getStatusColor() {
    switch (presence.status) {
      case 'available':
        return Colors.green;
      case 'away':
        return Colors.amber.shade700;
      case 'dnd':
        return Colors.red;
      case 'typing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isAway = presence.status == 'away';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: SepiaTheme.surface,
          border: Border.all(color: SepiaTheme.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: SepiaTheme.primaryLight,
                  child: Text(
                    presence.agentName.isNotEmpty ? presence.agentName[0] : 'A',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SepiaTheme.primary),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presence.agentName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    presence.statusMessage.isNotEmpty ? presence.statusMessage : presence.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: isAway ? FontStyle.italic : FontStyle.normal,
                      color: isAway ? Colors.amber.shade800 : SepiaTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onToggleAway != null)
              IconButton(
                icon: Icon(
                  isAway ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                  size: 14,
                  color: isAway ? Colors.amber.shade800 : SepiaTheme.textMuted,
                ),
                tooltip: isAway ? 'Set Available' : 'Set Away (Test Persona Priming)',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onToggleAway,
              ),
          ],
        ),
      ),
    );
  }
}
