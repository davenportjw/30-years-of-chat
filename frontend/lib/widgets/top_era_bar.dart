import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/sepia_theme.dart';

/// TopEraBar provides the presentation navigation header for Agents of Chat.
///
/// Features:
/// 1. Prominent Era Selector Dropdown on the top-left highlighting:
///    - 1988: The Ephemeral Buffer (IRC & Unix talk) • Short-Term Memory
///    - 1997: The 1:1 Direct Session & Presence (AIM & ICQ) • Working Memory
///    - 2006: Scoped Rooms & Context Fencing (Campfire) • Search Isolation
///    - 2013: The Searchable Vector Archive (Slack 1.0) • Long-Term Memory (RAG)
///    - 2017: Threads & Scribe Compaction (Slack Threads) • Sub-Task Scratchpads
///    - 2026: Collaborative Multi-Agent Mesh • Dual-Layer Memory & Dreaming
/// 2. Quick Stepper buttons: `< Prev Era` and `Next Era >` for talk presentations.
/// 3. Controls on the right:
///    - Reset & Re-seed button.
///    - Memory Architecture & Live Trace button.
class TopEraBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Era> eras;
  final Era? selectedEra;
  final Function(Era) onSelectEra;
  final PacingMode? pacing;
  final Function(PacingMode)? onUpdatePacing;
  final VoidCallback onReseed;
  final bool isReseeding;
  final bool isArchitectureDrawerOpen;
  final VoidCallback? onToggleArchitectureDrawer;
  final int telemetryCount;
  final bool hasActiveTelemetry;

  const TopEraBar({
    super.key,
    required this.eras,
    required this.selectedEra,
    required this.onSelectEra,
    this.pacing,
    this.onUpdatePacing,
    required this.onReseed,
    this.isReseeding = false,
    this.isArchitectureDrawerOpen = false,
    this.onToggleArchitectureDrawer,
    this.telemetryCount = 0,
    this.hasActiveTelemetry = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  int get _currentIndex =>
      selectedEra != null ? eras.indexWhere((e) => e.id == selectedEra!.id || e.year == selectedEra!.year) : -1;

  bool get _canGoPrev => _currentIndex > 0;
  bool get _canGoNext => _currentIndex >= 0 && _currentIndex < eras.length - 1;

  static String getDisplayPlatform(Era era) {
    switch (era.year) {
      case 1988:
        return 'IRC & Unix talk';
      case 1997:
        return 'AIM & ICQ';
      case 2006:
        return 'Campfire';
      case 2013:
        return 'Slack 1.0';
      case 2017:
        return 'Slack Threads';
      case 2026:
        return 'Agent Mesh';
      default:
        return era.platform.isNotEmpty ? era.platform : 'Chat';
    }
  }

  static String getCognitiveConcept(Era era) {
    switch (era.year) {
      case 1988:
        return 'Short-Term Memory';
      case 1997:
        return 'Working Memory';
      case 2006:
        return 'Search Isolation';
      case 2013:
        return 'Long-Term Memory (RAG)';
      case 2017:
        return 'Sub-Task Scratchpads';
      case 2026:
        return 'Dual-Layer Memory & Dreaming';
      default:
        return era.memoryConcept.isNotEmpty ? era.memoryConcept : 'Agent Memory';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: SepiaTheme.surface,
        border: Border(
          bottom: BorderSide(color: SepiaTheme.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Prominent Era Selector Dropdown
                      _EraSelectorDropdown(
                        eras: eras,
                        selectedEra: selectedEra,
                        onSelectEra: onSelectEra,
                      ),

                      const SizedBox(width: 12),

                      // 2. Quick Stepper Buttons (< Prev Era, Next Era >)
                      _EraStepperControls(
                        canGoPrev: _canGoPrev,
                        canGoNext: _canGoNext,
                        currentIndex: _currentIndex,
                        totalEras: eras.length,
                        onPrev: _canGoPrev ? () => onSelectEra(eras[_currentIndex - 1]) : null,
                        onNext: _canGoNext ? () => onSelectEra(eras[_currentIndex + 1]) : null,
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reset & Re-seed button
                      _ReseedButton(
                        isReseeding: isReseeding,
                        onReseed: onReseed,
                      ),

                      const SizedBox(width: 12),

                      // 5. Memory Architecture & Live Trace button
                      _ArchitectureToggleButton(
                        isOpen: isArchitectureDrawerOpen,
                        onToggle: onToggleArchitectureDrawer,
                        telemetryCount: telemetryCount,
                        hasActiveTelemetry: hasActiveTelemetry,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Prominent Era Selector Dropdown
class _EraSelectorDropdown extends StatelessWidget {
  final List<Era> eras;
  final Era? selectedEra;
  final Function(Era) onSelectEra;

  const _EraSelectorDropdown({
    required this.eras,
    required this.selectedEra,
    required this.onSelectEra,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Era>(
      tooltip: 'Select historical era (1988–2026)',
      offset: const Offset(0, 50),
      color: SepiaTheme.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: SepiaTheme.borderStrong, width: 1),
      ),
      onSelected: onSelectEra,
      itemBuilder: (BuildContext context) {
        return eras.map((era) {
          final bool isCurrent = selectedEra?.id == era.id || selectedEra?.year == era.year;
          return PopupMenuItem<Era>(
            value: era,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              width: 480,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? SepiaTheme.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCurrent ? SepiaTheme.primary : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Year badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCurrent ? SepiaTheme.primary : SepiaTheme.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCurrent ? SepiaTheme.primary : SepiaTheme.border,
                        ),
                      ),
                      child: Text(
                        '${era.year}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : SepiaTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Era Details
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '${era.year}: ${era.name}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent ? SepiaTheme.primary : SepiaTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent ? SepiaTheme.primary.withValues(alpha: 0.15) : SepiaTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isCurrent ? SepiaTheme.primary : SepiaTheme.border),
                            ),
                            child: Text(
                              TopEraBar.getCognitiveConcept(era),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isCurrent ? SepiaTheme.primary : SepiaTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCurrent)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: SepiaTheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: SepiaTheme.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.borderStrong, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SepiaTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                selectedEra != null ? '${selectedEra!.year}' : 'ERA',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Current Era text with compact Intent Pill
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedEra != null
                      ? '${selectedEra!.year}: ${selectedEra!.name}'
                      : 'Select Historical Era',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                  ),
                ),
                if (selectedEra != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: SepiaTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      TopEraBar.getCognitiveConcept(selectedEra!),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: SepiaTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: SepiaTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Quick Stepper Buttons (< Prev Era and Next Era >)
class _EraStepperControls extends StatelessWidget {
  final bool canGoPrev;
  final bool canGoNext;
  final int currentIndex;
  final int totalEras;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _EraStepperControls({
    required this.canGoPrev,
    required this.canGoNext,
    required this.currentIndex,
    required this.totalEras,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // < Prev Era
        Tooltip(
          message: canGoPrev ? 'Previous historical era' : 'At earliest era',
          child: OutlinedButton(
            onPressed: onPrev,
            style: OutlinedButton.styleFrom(
              foregroundColor: SepiaTheme.primary,
              disabledForegroundColor: SepiaTheme.textMuted.withValues(alpha: 0.4),
              side: BorderSide(
                color: canGoPrev ? SepiaTheme.borderStrong : SepiaTheme.border.withValues(alpha: 0.5),
              ),
              backgroundColor: canGoPrev ? SepiaTheme.surface : SepiaTheme.surface.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, size: 16),
                SizedBox(width: 2),
                Text(
                  'Prev Era',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Sequential progress pill (e.g., "1 of 6")
        if (totalEras > 0 && currentIndex >= 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Text(
              '${currentIndex + 1}/$totalEras',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: SepiaTheme.textSecondary,
              ),
            ),
          ),

        const SizedBox(width: 6),

        // Next Era >
        Tooltip(
          message: canGoNext ? 'Next historical era' : 'At latest era',
          child: OutlinedButton(
            onPressed: onNext,
            style: OutlinedButton.styleFrom(
              foregroundColor: SepiaTheme.primary,
              disabledForegroundColor: SepiaTheme.textMuted.withValues(alpha: 0.4),
              side: BorderSide(
                color: canGoNext ? SepiaTheme.borderStrong : SepiaTheme.border.withValues(alpha: 0.5),
              ),
              backgroundColor: canGoNext ? SepiaTheme.surface : SepiaTheme.surface.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next Era',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


/// Reset & Re-seed Button
class _ReseedButton extends StatelessWidget {
  final bool isReseeding;
  final VoidCallback onReseed;

  const _ReseedButton({
    required this.isReseeding,
    required this.onReseed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: isReseeding
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SepiaTheme.primary,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 15, color: SepiaTheme.primary),
      label: Text(
        isReseeding ? 'Reseeding...' : 'Reset & Re-seed',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: SepiaTheme.primary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: SepiaTheme.borderStrong),
        backgroundColor: SepiaTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: isReseeding ? null : onReseed,
    );
  }
}

/// Button in TopEraBar to toggle the Memory Architecture & Live Trace Drawer
class _ArchitectureToggleButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback? onToggle;
  final int telemetryCount;
  final bool hasActiveTelemetry;

  const _ArchitectureToggleButton({
    required this.isOpen,
    required this.onToggle,
    required this.telemetryCount,
    required this.hasActiveTelemetry,
  });

  @override
  State<_ArchitectureToggleButton> createState() => _ArchitectureToggleButtonState();
}

class _ArchitectureToggleButtonState extends State<_ArchitectureToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.hasActiveTelemetry) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _ArchitectureToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveTelemetry != oldWidget.hasActiveTelemetry) {
      if (widget.hasActiveTelemetry) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.value = 1.0;
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.isOpen;
    final hasActive = widget.hasActiveTelemetry;

    return OutlinedButton(
      onPressed: widget.onToggle,
      style: OutlinedButton.styleFrom(
        backgroundColor: isOpen ? SepiaTheme.primaryLight : SepiaTheme.surface,
        foregroundColor: isOpen ? SepiaTheme.primary : SepiaTheme.textPrimary,
        side: BorderSide(
          color: isOpen ? SepiaTheme.primary : SepiaTheme.borderStrong,
          width: isOpen ? 1.5 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schema_outlined,
            size: 16,
            color: isOpen ? SepiaTheme.primary : SepiaTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            'Memory Architecture',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isOpen ? FontWeight.bold : FontWeight.w600,
              color: isOpen ? SepiaTheme.primary : SepiaTheme.textPrimary,
            ),
          ),
          if (hasActive) ...[
            const SizedBox(width: 6),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: _pulseAnimation.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.4 * _pulseAnimation.value),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (widget.telemetryCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isOpen ? SepiaTheme.primary : SepiaTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOpen ? SepiaTheme.primary : SepiaTheme.border,
                ),
              ),
              child: Text(
                '${widget.telemetryCount}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isOpen ? Colors.white : SepiaTheme.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
