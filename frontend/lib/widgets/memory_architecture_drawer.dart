import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import '../models/era_architecture_models.dart';
import '../theme/sepia_theme.dart';
import 'era_tradeoffs_script_view.dart';

/// MemoryArchitectureDrawer is an expandable, academic-styled right pane
/// demonstrating the 4-stage cognitive memory pipeline of the active era,
/// production sample code/schemas, and live execution telemetry traces.
class MemoryArchitectureDrawer extends StatefulWidget {
  final Era? era;
  final Channel? channel;
  final List<TelemetrySpan> telemetrySpans;
  final int? activeStepIndex; // 1..4 (which step is currently executing live)
  final MemoryBuffer? buffer;
  final List<ConsolidationReport>? consolidationReports;
  final VoidCallback? onClose;
  final VoidCallback? onTriggerDreaming;
  final Future<void> Function(ShowcaseScriptStep step)? onExecuteScriptStep;
  final Function(String eraId)? onSwitchEra;
  final bool isDreaming;
  final bool enableAnimations;

  const MemoryArchitectureDrawer({
    super.key,
    this.era,
    this.channel,
    this.telemetrySpans = const [],
    this.activeStepIndex,
    this.buffer,
    this.consolidationReports,
    this.onClose,
    this.onTriggerDreaming,
    this.onExecuteScriptStep,
    this.onSwitchEra,
    this.isDreaming = false,
    this.enableAnimations = true,
  });

  @override
  State<MemoryArchitectureDrawer> createState() => _MemoryArchitectureDrawerState();
}

class _MemoryArchitectureDrawerState extends State<MemoryArchitectureDrawer>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _selectedStepNumber = 1;
  int _selectedCodeSnippetIndex = 0; // 0: Primary code, 1: Schema snippet
  bool _isCopiedPrimary = false;
  bool _isCopiedStep = false;
  Timer? _copyTimerPrimary;
  Timer? _copyTimerStep;
  final Set<String> _expandedPayloadSpanIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.enableAnimations && _isLiveActivity) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    if (widget.activeStepIndex != null && widget.activeStepIndex! >= 1 && widget.activeStepIndex! <= 4) {
      _selectedStepNumber = widget.activeStepIndex!;
    }
  }

  @override
  void didUpdateWidget(covariant MemoryArchitectureDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeStepIndex != null &&
        widget.activeStepIndex != oldWidget.activeStepIndex &&
        widget.activeStepIndex! >= 1 &&
        widget.activeStepIndex! <= 4) {
      setState(() {
        _selectedStepNumber = widget.activeStepIndex!;
      });
    }

    if (widget.enableAnimations && _isLiveActivity) {
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

  @override
  void dispose() {
    _copyTimerPrimary?.cancel();
    _copyTimerStep?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  EraArchitecture get _currentArch {
    final eraId = widget.era?.id ?? widget.channel?.eraId ?? '';
    return EraArchitectureCatalog.getArchitecture(eraId);
  }

  bool get _isLiveActivity {
    if (widget.activeStepIndex != null) return true;
    if (widget.telemetrySpans.isNotEmpty) {
      final now = DateTime.now();
      for (final span in widget.telemetrySpans) {
        if (now.difference(span.timestamp).inSeconds.abs() <= 3) {
          return true;
        }
      }
    }
    return false;
  }

  bool get _isAgentMeshEra {
    final eraId = widget.era?.id ?? widget.channel?.eraId ?? '';
    return eraId == 'era-2026-agent-mesh' || eraId == 'era-2026-mesh' || eraId.contains('2026');
  }

  @override
  Widget build(BuildContext context) {
    final arch = _currentArch;

    return Container(
      width: 460,
      decoration: const BoxDecoration(
        color: SepiaTheme.surface,
        border: Border(left: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drawer Header
          _buildDrawerHeader(arch),

          // 2. Navigation Tabs
          _buildTabBar(),

          // 3. Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildArchitecturePipelineTab(arch),
                EraTradeoffsScriptView(
                  era: widget.era,
                  channel: widget.channel,
                  telemetrySpans: widget.telemetrySpans,
                  onExecuteScriptStep: widget.onExecuteScriptStep,
                  onSwitchEra: widget.onSwitchEra,
                ),
                _buildSampleCodeTab(arch),
                _buildTelemetryTraceTab(arch),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Drawer Header
  // ==========================================================================
  Widget _buildDrawerHeader(EraArchitecture arch) {
    final year = widget.era?.year ?? arch.year;
    final eraName = widget.era?.name.isNotEmpty == true ? widget.era!.name : arch.title;
    final cognitiveConcept = widget.era?.memoryConcept.isNotEmpty == true
        ? widget.era!.memoryConcept
        : arch.cognitiveConcept;
    final isLive = _isLiveActivity;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: const BoxDecoration(
        color: SepiaTheme.card,
        border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Year Pill + Activity Indicator + Close Button
          Row(
            children: [
              // Era Year Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SepiaTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$year',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Activity Badge
              _buildActivityIndicator(isLive),

              const Spacer(),

              // Close IconButton
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: SepiaTheme.textSecondary),
                tooltip: 'Close Architecture Drawer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: widget.onClose,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Era Title
          Text(
            eraName,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: SepiaTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Cognitive Paradigm Intent Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SepiaTheme.primaryLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_outlined, size: 13, color: SepiaTheme.primary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    cognitiveConcept,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: SepiaTheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityIndicator(bool isLive) {
    if (isLive) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E7D32).withValues(alpha: _pulseAnimation.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.25 * _pulseAnimation.value),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _pulseAnimation.value,
                  child: const Text(
                    '●',
                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, height: 1.0),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.activeStepIndex != null
                      ? '● LIVE EXECUTION (STEP ${widget.activeStepIndex})'
                      : '● LIVE EXECUTION',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: SepiaTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SepiaTheme.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '●',
              style: TextStyle(color: SepiaTheme.textMuted, fontSize: 10, height: 1.0),
            ),
            SizedBox(width: 5),
            Text(
              '● IDLE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: SepiaTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ==========================================================================
  // Tabs Bar
  // ==========================================================================
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: SepiaTheme.surface,
        border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: SepiaTheme.primary,
        unselectedLabelColor: SepiaTheme.textMuted,
        indicatorColor: SepiaTheme.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.normal),
        tabs: [
          const Tab(text: 'Architecture'),
          const Tab(text: 'Tradeoffs & Script'),
          const Tab(text: 'Sample Code'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Live Telemetry'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: widget.telemetrySpans.isNotEmpty ? SepiaTheme.primaryLight : SepiaTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.telemetrySpans.isNotEmpty ? SepiaTheme.primary : SepiaTheme.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${widget.telemetrySpans.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.telemetrySpans.isNotEmpty ? SepiaTheme.primary : SepiaTheme.textMuted,
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

  // ==========================================================================
  // Tab 1: Architecture & Pipeline
  // ==========================================================================
  Widget _buildArchitecturePipelineTab(EraArchitecture arch) {
    final steps = arch.steps;
    final inspectedStep = steps.firstWhere(
      (s) => s.stepNumber == _selectedStepNumber,
      orElse: () => steps.first,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Era Architectural Overview Callout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: SepiaTheme.primaryLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hub_outlined, size: 16, color: SepiaTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  arch.summary,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: SepiaTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4-Stage Pipeline Grid Header
        const Text(
          '4-STAGE COGNITIVE PIPELINE',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: SepiaTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),

        // 4-Stage Pipeline Grid (2x2 layout with flow connectors)
        _buildPipelineGrid(steps),

        const SizedBox(height: 20),

        // Selected Step Deep-Dive Inspector
        _buildStepDeepDiveInspector(arch, inspectedStep),
      ],
    );
  }

  Widget _buildPipelineGrid(List<ArchitecturePipelineStep> steps) {
    if (steps.length < 4) {
      return const SizedBox();
    }

    final step1 = steps[0];
    final step2 = steps[1];
    final step3 = steps[2];
    final step4 = steps[3];

    return Column(
      children: [
        // Row 1: Step 1 and Step 2
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildPipelineStepCard(step1)),
              const SizedBox(width: 8),
              Expanded(child: _buildPipelineStepCard(step2)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Flow connector bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.south, size: 14, color: SepiaTheme.primary.withValues(alpha: 0.5)),
              Expanded(
                child: Center(
                  child: Text(
                    'CONTINUOUS PIPELINE FLOW',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                      color: SepiaTheme.primary.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Icon(Icons.south, size: 14, color: SepiaTheme.primary.withValues(alpha: 0.5)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Row 2: Step 3 and Step 4
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildPipelineStepCard(step3)),
              const SizedBox(width: 8),
              Expanded(child: _buildPipelineStepCard(step4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineStepCard(ArchitecturePipelineStep step) {
    final isActive = widget.activeStepIndex == step.stepNumber;
    final isSelected = _selectedStepNumber == step.stepNumber;

    Color borderColor;
    Color bgColor;
    List<BoxShadow> shadows = [];

    if (isActive) {
      borderColor = const Color(0xFF2E7D32);
      bgColor = const Color(0xFFF1F8E9);
      shadows = [
        BoxShadow(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else if (isSelected) {
      borderColor = SepiaTheme.primary;
      bgColor = SepiaTheme.primaryLight.withValues(alpha: 0.5);
    } else {
      borderColor = SepiaTheme.border;
      bgColor = SepiaTheme.card;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStepNumber = step.stepNumber;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isActive || isSelected ? 1.8 : 1.0),
          boxShadow: shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Stage badge + Live Chip or Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF2E7D32)
                        : (isSelected ? SepiaTheme.primary : SepiaTheme.surface),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF2E7D32)
                          : (isSelected ? SepiaTheme.primary : SepiaTheme.border),
                    ),
                  ),
                  child: Text(
                    'STEP ${step.stepNumber}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isActive || isSelected ? Colors.white : SepiaTheme.textPrimary,
                    ),
                  ),
                ),
                if (isActive)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: _pulseAnimation.value,
                              child: const Text('●', style: TextStyle(color: Colors.white, fontSize: 8)),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  Icon(
                    _getStepIconData(step.iconName),
                    size: 15,
                    color: isSelected ? SepiaTheme.primary : SepiaTheme.textMuted,
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Step Title
            Text(
              step.title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                height: 1.25,
                color: SepiaTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Tech Stack Label
            Text(
              step.techStack,
              style: const TextStyle(
                fontSize: 9.5,
                color: SepiaTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Flow Tag Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: SepiaTheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SepiaTheme.border),
              ),
              child: Text(
                step.flowTag,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: SepiaTheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Selected Step Deep-Dive Inspector
  // ==========================================================================
  Widget _buildStepDeepDiveInspector(EraArchitecture arch, ArchitecturePipelineStep step) {
    final failureModeName = _getFailureModeName(arch, step);
    final failureModeDesc = _getFailureModeDescription(arch, step);

    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inspector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: SepiaTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.find_in_page_outlined, size: 16, color: SepiaTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'INSPECTOR: STEP ${step.stepNumber} • ${step.title.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: SepiaTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SepiaTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SepiaTheme.border),
                  ),
                  child: Text(
                    step.codeLanguage.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: SepiaTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: SepiaTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                // Invariants Meta Badges
                if (step.metaBadges.isNotEmpty) ...[
                  const Text(
                    'ARCHITECTURAL INVARIANTS & GUARANTEES:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: SepiaTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: step.metaBadges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: SepiaTheme.card,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SepiaTheme.borderStrong),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: SepiaTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Cognitive Mechanism Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SepiaTheme.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SepiaTheme.borderStrong),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.memory, size: 16, color: SepiaTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'MEMORY MECHANISM: $failureModeName',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: SepiaTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        failureModeDesc,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: SepiaTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Inline Implementation Code Snippet
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'STEP IMPLEMENTATION CODE:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: SepiaTheme.textMuted,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: step.sampleCode));
                        _copyTimerStep?.cancel();
                        setState(() => _isCopiedStep = true);
                        _copyTimerStep = Timer(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _isCopiedStep = false);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SepiaTheme.card,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SepiaTheme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isCopiedStep ? Icons.check : Icons.copy,
                              size: 12,
                              color: _isCopiedStep ? Colors.green.shade800 : SepiaTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isCopiedStep ? 'Copied' : 'Copy Code',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isCopiedStep ? Colors.green.shade800 : SepiaTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Code Container
                _buildMonospaceCodeBlock(step.sampleCode, step.codeLanguage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Tab 2: Production Sample Code & Schemas
  // ==========================================================================
  Widget _buildSampleCodeTab(EraArchitecture arch) {
    final isPrimarySelected = _selectedCodeSnippetIndex == 0;
    final currentCode = isPrimarySelected ? arch.primaryCodeSnippet : arch.schemaSnippet;
    final currentLang = isPrimarySelected ? arch.primaryCodeLanguage : arch.schemaLanguage;

    final primaryLabel = '${arch.primaryCodeLanguage.toUpperCase()} Implementation';
    final schemaLabel = '${arch.schemaLanguage.toUpperCase()} DDL / Schema';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language Selector Segmented Buttons
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: SepiaTheme.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SepiaTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedCodeSnippetIndex = 0),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isPrimarySelected ? SepiaTheme.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isPrimarySelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      primaryLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isPrimarySelected ? FontWeight.bold : FontWeight.w500,
                        color: isPrimarySelected ? SepiaTheme.primary : SepiaTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedCodeSnippetIndex = 1),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !isPrimarySelected ? SepiaTheme.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: !isPrimarySelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      schemaLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: !isPrimarySelected ? FontWeight.bold : FontWeight.w500,
                        color: !isPrimarySelected ? SepiaTheme.primary : SepiaTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Description of what this code represents
        Text(
          isPrimarySelected
              ? 'Primary production engine implementation for ${arch.title}. Invariant enforcement, mutex concurrency, and pipeline transitions.'
              : 'Production schema and relational DDL specifying table layouts, vector dimensions, and secondary indexes.',
          style: const TextStyle(fontSize: 11.5, height: 1.4, color: SepiaTheme.textSecondary),
        ),

        const SizedBox(height: 12),

        // Monospace Code Container with Copy Button
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1C1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF38322C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Code Block Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF262320),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(bottom: BorderSide(color: Color(0xFF38322C))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38322C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentLang.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE8E2D9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPrimarySelected ? '${arch.eraId}_pipeline.go' : '${arch.eraId}_schema.sql',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFB0A597),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentCode));
                        _copyTimerPrimary?.cancel();
                        setState(() => _isCopiedPrimary = true);
                        _copyTimerPrimary = Timer(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _isCopiedPrimary = false);
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38322C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isCopiedPrimary ? Icons.check : Icons.copy,
                              size: 12,
                              color: _isCopiedPrimary ? Colors.green.shade400 : const Color(0xFFD4C8B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isCopiedPrimary ? 'Copied!' : 'Copy Code',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isCopiedPrimary ? Colors.green.shade400 : const Color(0xFFD4C8B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Code Body with Line Numbers
              _buildCodeWithLineNumbers(currentCode, currentLang),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Tab 3: Live Telemetry Trace
  // ==========================================================================
  Widget _buildTelemetryTraceTab(EraArchitecture arch) {
    final spans = List<TelemetrySpan>.from(widget.telemetrySpans)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final isAgentMesh = _isAgentMeshEra;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // REM Dreaming trigger action bar for Era 2026
        if (isAgentMesh && widget.onTriggerDreaming != null) ...[
          _buildDreamingTriggerCard(),
          const SizedBox(height: 14),
        ],

        // Header info
        Row(
          children: [
            const Expanded(
              child: Text(
                'LIVE TELEMETRY TRACE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: SepiaTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${spans.length} events recorded',
              style: const TextStyle(
                fontSize: 10.5,
                color: SepiaTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Empty state or list of spans
        if (spans.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            decoration: BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SepiaTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: SepiaTheme.border),
                  ),
                  child: const Icon(Icons.timeline_outlined, size: 32, color: SepiaTheme.primary),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No Live Telemetry Yet',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No live telemetry yet. Send a message, trigger dreaming, or inject an event to watch the cognitive memory pipeline execute.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: SepiaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...spans.map((span) => _buildTelemetrySpanCard(span)),
      ],
    );
  }

  Widget _buildDreamingTriggerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.nights_stay, size: 16, color: Color(0xFF6A1B9A)),
              SizedBox(width: 6),
              Text(
                'COGNITIVE REM DREAMING DAEMON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF4A148C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Asynchronously consolidates recent chat turns into durable semantic memory, resolving contradictions and promoting scratchpad insights.',
            style: TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF4A148C)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: widget.isDreaming
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology_outlined, size: 16),
              label: Text(
                widget.isDreaming
                    ? 'Consolidating Swarm Memory...'
                    : 'Trigger REM Dreaming Pass',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: widget.isDreaming ? null : widget.onTriggerDreaming,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetrySpanCard(TelemetrySpan span) {
    final actionColor = _getActionColor(span.action);
    final timestampFormatted = _formatTimestamp(span.timestamp);
    final isExpanded = _expandedPayloadSpanIds.contains(span.id);
    final hasPayload = span.payload != null && span.payload!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SepiaTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Span Card Header: Action Pill + Latency Chip + Timestamp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: SepiaTheme.border)),
            ),
            child: Row(
              children: [
                // Action Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: actionColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    span.action,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: actionColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Active Step badge
                if (span.activeStep > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: SepiaTheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SepiaTheme.border),
                    ),
                    child: Text(
                      'STEP ${span.activeStep}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: SepiaTheme.primary,
                      ),
                    ),
                  ),

                const Spacer(),

                // Latency Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SepiaTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SepiaTheme.border),
                  ),
                  child: Text(
                    '⏱️ ${span.latencyMs}ms',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: SepiaTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Timestamp
                Text(
                  timestampFormatted,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: SepiaTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Span Card Body
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  span.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),

                // Description
                Text(
                  span.description,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: SepiaTheme.textSecondary,
                  ),
                ),

                // Dynamic Metrics Chips
                if (span.metrics.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: span.metrics.entries.map((entry) {
                      final label = _formatMetricEntry(entry.key, entry.value);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SepiaTheme.primaryLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SepiaTheme.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: SepiaTheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Expandable Payload Box
                if (hasPayload) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedPayloadSpanIds.remove(span.id);
                        } else {
                          _expandedPayloadSpanIds.add(span.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: SepiaTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpanded ? 'Hide Payload Preview' : 'Show Payload Preview',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: SepiaTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isExpanded)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1C1A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF38322C)),
                      ),
                      child: SelectableText(
                        span.payload!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          height: 1.4,
                          color: Color(0xFFE8E2D9),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Monospace Code Container Helpers
  // ==========================================================================
  Widget _buildMonospaceCodeBlock(String code, String language) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF38322C)),
      ),
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText.rich(
          _tokenizeCodeToSpans(code, language),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeWithLineNumbers(String code, String language) {
    final lines = code.split('\n');
    final lineCount = lines.length;
    final lineNumbersText = List.generate(lineCount, (i) => '${i + 1}').join('\n');

    return Container(
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers
              Text(
                lineNumbersText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.45,
                  color: Color(0xFF6B6258),
                ),
              ),
              const SizedBox(width: 12),

              // Vertical divider line
              Container(
                width: 1,
                height: (lineCount * 16.0).clamp(20.0, 5000.0),
                color: const Color(0xFF38322C),
              ),
              const SizedBox(width: 12),

              // Highlighted Code View
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText.rich(
                    _tokenizeCodeToSpans(code, language),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _tokenizeCodeToSpans(String code, String language) {
    final lines = code.split('\n');
    final List<TextSpan> spans = [];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      spans.add(_tokenizeSingleLine(line));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans);
  }

  TextSpan _tokenizeSingleLine(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('--') || trimmed.startsWith('/*')) {
      return TextSpan(
        text: line,
        style: const TextStyle(
          color: Color(0xFF8C8275),
          fontStyle: FontStyle.italic,
          fontFamily: 'monospace',
        ),
      );
    }

    final tokenRegex = RegExp(
      r'(\/\/[^\n]*|--[^\n]*|".*?"|'
      r"'.*?'|\b(?:func|type|struct|package|import|return|defer|go|select|chan|make|new|nil|true|false|if|else|switch|case|for|range|var|const|int|int64|uint32|uint64|string|bool|float32|float64|byte|error|typedef|char|void|SELECT|FROM|WHERE|AND|OR|ORDER|BY|LIMIT|GROUP|HAVING|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|INDEX|PRIMARY|KEY|NOT|NULL|OPTIONS|ARRAY|VECTOR|FORCE_INDEX|COSINE_DISTANCE|ASC|DESC|DEFAULT|BOOLEAN|TEXT|VARCHAR|TIMESTAMP)\b|\b\d+\b|[a-zA-Z_]\w*|[^\s\w])",
      caseSensitive: false,
    );

    final matches = tokenRegex.allMatches(line);
    if (matches.isEmpty) {
      return TextSpan(
        text: line,
        style: const TextStyle(color: Color(0xFFD4C8B8), fontFamily: 'monospace'),
      );
    }

    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: line.substring(lastIndex, match.start),
          style: const TextStyle(color: Color(0xFFD4C8B8), fontFamily: 'monospace'),
        ));
      }

      final token = match.group(0)!;
      Color color = const Color(0xFFD4C8B8);
      FontStyle fontStyle = FontStyle.normal;
      FontWeight fontWeight = FontWeight.normal;

      if (token.startsWith('//') || token.startsWith('--')) {
        color = const Color(0xFF8C8275);
        fontStyle = FontStyle.italic;
      } else if ((token.startsWith('"') && token.endsWith('"')) || (token.startsWith("'") && token.endsWith("'"))) {
        color = const Color(0xFF86EFAC); // soft green
      } else if (RegExp(r'^\d+$').hasMatch(token)) {
        color = const Color(0xFFFDE047); // soft yellow
      } else if (_isKeyword(token)) {
        color = const Color(0xFFE5A04D); // warm amber
        fontWeight = FontWeight.bold;
      } else if (_isTypeOrIdentifier(token)) {
        color = const Color(0xFF93C5FD); // soft blue
      }

      spans.add(TextSpan(
        text: token,
        style: TextStyle(
          color: color,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
          fontFamily: 'monospace',
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastIndex),
        style: const TextStyle(color: Color(0xFFD4C8B8), fontFamily: 'monospace'),
      ));
    }

    return TextSpan(children: spans);
  }

  bool _isKeyword(String text) {
    const keywords = {
      'func', 'type', 'struct', 'package', 'import', 'return', 'defer', 'go',
      'select', 'chan', 'make', 'new', 'nil', 'true', 'false', 'if', 'else',
      'switch', 'case', 'for', 'range', 'var', 'const', 'typedef', 'void',
      'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'ORDER', 'BY', 'LIMIT', 'GROUP',
      'HAVING', 'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE', 'CREATE',
      'TABLE', 'INDEX', 'PRIMARY', 'KEY', 'NOT', 'NULL', 'OPTIONS', 'ARRAY',
      'VECTOR', 'FORCE_INDEX', 'COSINE_DISTANCE', 'ASC', 'DESC', 'DEFAULT',
    };
    return keywords.contains(text) || keywords.contains(text.toUpperCase());
  }

  bool _isTypeOrIdentifier(String text) {
    const types = {
      'int', 'int64', 'uint32', 'uint64', 'string', 'bool', 'float32', 'float64',
      'byte', 'error', 'char', 'BOOLEAN', 'TEXT', 'VARCHAR', 'TIMESTAMP', 'STRING',
    };
    if (types.contains(text) || types.contains(text.toUpperCase())) return true;
    if (text.length > 1 && text[0].toUpperCase() == text[0] && text != text.toUpperCase()) {
      return true;
    }
    return false;
  }

  // ==========================================================================
  // Formatting & Mapping Helpers
  // ==========================================================================
  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _formatMetricEntry(String key, dynamic val) {
    final k = key.toLowerCase();
    if (k.contains('turn') && k.contains('max')) {
      return 'Max Turns: $val';
    } else if (k == 'turns' || k == 'current_turns') {
      return 'Turns: $val';
    } else if (k == 'evicted_count') {
      return 'Displaced: $val';
    } else if (k.contains('token')) {
      return 'Tokens: $val';
    } else if (k.contains('compression')) {
      final numVal = val is num ? val : double.tryParse(val.toString());
      if (numVal != null) {
        return 'Compression: ${(numVal * 100).toStringAsFixed(0)}%';
      }
      return 'Compression: $val';
    } else if (k.contains('sim') || k.contains('distance')) {
      final numVal = val is num ? val : double.tryParse(val.toString());
      if (numVal != null) {
        return 'Sim: ${numVal.toStringAsFixed(2)}';
      }
      return 'Sim: $val';
    } else if (k.contains('pruned')) {
      return 'Pruned: $val';
    }

    final formattedKey = key.replaceAll('_', ' ');
    final capitalizedKey = formattedKey.isEmpty
        ? ''
        : '${formattedKey[0].toUpperCase()}${formattedKey.substring(1)}';
    return '$capitalizedKey: $val';
  }

  IconData _getStepIconData(String iconName) {
    switch (iconName) {
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'terminal':
        return Icons.terminal;
      case 'memory':
        return Icons.memory;
      case 'delete_outline':
        return Icons.delete_outline;
      case 'psychology':
        return Icons.psychology;
      case 'chat_bubble':
        return Icons.chat_bubble_outline;
      case 'timer':
        return Icons.timer_outlined;
      case 'edit_note':
        return Icons.edit_note;
      case 'meeting_room':
        return Icons.meeting_room_outlined;
      case 'security':
        return Icons.security;
      case 'shield':
        return Icons.shield_outlined;
      case 'webhook':
        return Icons.webhook;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'search':
        return Icons.search;
      case 'alt_route':
        return Icons.alt_route;
      case 'developer_board':
        return Icons.developer_board;
      case 'compress':
        return Icons.compress;
      case 'fact_check':
        return Icons.fact_check_outlined;
      case 'hub':
        return Icons.hub_outlined;
      case 'lock':
        return Icons.lock_outline;
      case 'nights_stay':
        return Icons.nights_stay_outlined;
      default:
        return Icons.schema_outlined;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'FIFO_WRITE':
        return const Color(0xFF0288D1);
      case 'FIFO_EVICT':
        return const Color(0xFFE65100);
      case 'ATTENTIONAL_SHIFT':
        return const Color(0xFF7B1FA2);
      case 'SESSION_BOUNDARY_CHECK':
        return const Color(0xFF004D40);
      case 'FIREWALL_EVAL':
        return const Color(0xFF00796B);
      case 'FIREWALL_QUARANTINE':
        return const Color(0xFFC62828);
      case 'VECTOR_SEARCH':
        return const Color(0xFF1565C0);
      case 'LLM_INFERENCE':
        return const Color(0xFFB75500);
      case 'SCRIBE_COMPACT':
        return const Color(0xFF2E7D32);
      case 'DREAM_CONSOLIDATION':
        return const Color(0xFF4A148C);
      case 'STORE_WRITE':
        return SepiaTheme.primary;
      default:
        return SepiaTheme.accent;
    }
  }

  String _getFailureModeName(EraArchitecture arch, ArchitecturePipelineStep step) {
    switch (arch.eraId) {
      case 'era-1988-irc':
        switch (step.stepNumber) {
          case 1:
            return 'Sliding Token Budget';
          case 2:
            return 'RAM Buffer Allocation';
          case 3:
            return 'FIFO Window Pruning';
          case 4:
            return 'Stateless Window Assembly';
        }
        break;
      case 'era-1997-aim':
        switch (step.stepNumber) {
          case 1:
            return '1:1 Working Memory Fencing';
          case 2:
            return 'Attentional Heartbeat';
          case 3:
            return 'Dynamic Persona Conditioning';
          case 4:
            return 'Bilateral Model Inference';
        }
        break;
      case 'era-2006-jabber':
        switch (step.stepNumber) {
          case 1:
            return 'Perimeter Domain Scoping';
          case 2:
            return 'RBAC Firewall Validation';
          case 3:
            return 'Channel Query Isolation';
          case 4:
            return 'Fenced Context Assembly';
        }
        break;
      case 'era-2013-hipchat':
        switch (step.stepNumber) {
          case 1:
            return 'Durable Event Logging';
          case 2:
            return 'Semantic Vector Projection';
          case 3:
            return 'Cosine Distance Matching';
          case 4:
            return 'Evidence Prompt Grounding';
        }
        break;
      case 'era-2017-threads':
        switch (step.stepNumber) {
          case 1:
            return 'Thread Context Partitioning';
          case 2:
            return 'Specialist Autonomous Deliberation';
          case 3:
            return 'Hierarchical Scribe Compaction';
          case 4:
            return 'Checkpoint Root Injection';
        }
        break;
      case 'era-2026-agent-mesh':
        switch (step.stepNumber) {
          case 1:
            return 'Blackboard Intent Tagging';
          case 2:
            return 'Confidential Scratchpad State';
          case 3:
            return 'Background REM Consolidation';
          case 4:
            return 'Dual-Layer Swarm Synthesis';
        }
        break;
    }
    return 'Cognitive Memory Pipeline';
  }

  String _getFailureModeDescription(EraArchitecture arch, ArchitecturePipelineStep step) {
    switch (arch.eraId) {
      case 'era-1988-irc':
        switch (step.stepNumber) {
          case 1:
            return 'Meters inbound stream turns against a fixed buffer limit to bound RAM usage.';
          case 2:
            return 'Appends incoming turns to an in-memory slice guarded by concurrent read-write mutexes.';
          case 3:
            return 'Slices off the earliest turn when capacity is reached, keeping the latest N turns active.';
          case 4:
            return 'Pours active in-memory turns directly into the Gemini prompt for generation.';
        }
        break;
      case 'era-1997-aim':
        switch (step.stepNumber) {
          case 1:
            return 'Isolates conversation turns to the bilateral user-agent pair, preventing channel crosstalk.';
          case 2:
            return 'Monitors agent activity states and fires transitions when computing in background.';
          case 3:
            return 'Pours away status strings directly into system instructions to guide model responses.';
          case 4:
            return 'Restricts generation context strictly to the 1:1 conversation history.';
        }
        break;
      case 'era-2006-jabber':
        switch (step.stepNumber) {
          case 1:
            return 'Partitions interactions into room channels with independent conversational contexts.';
          case 2:
            return 'Checks caller role permissions against channel security policies before execution.';
          case 3:
            return 'Scopes all database lookups to channel_id to maintain tenant privacy.';
          case 4:
            return 'Injects verified room topic, policy, and history into the generation prompt.';
        }
        break;
      case 'era-2013-hipchat':
        switch (step.stepNumber) {
          case 1:
            return 'Persists all interaction turns to append-only cloud storage with commit timestamps.';
          case 2:
            return 'Generates normalized 16-d embeddings representing semantic content in geometric space.';
          case 3:
            return 'Performs cosine similarity searches across vector tables to locate top-K precedents.';
          case 4:
            return 'Augments the Gemini prompt with retrieved historical ADRs and precedents.';
        }
        break;
      case 'era-2017-threads':
        switch (step.stepNumber) {
          case 1:
            return 'Forks diagnostic tasks into an isolated thread linked to the parent issue.';
          case 2:
            return 'Runs multi-agent investigation turns inside the thread while tracking tokens.';
          case 3:
            return 'Compresses lengthy thread turns into a structured summary using Gemini 3.8 Flash.';
          case 4:
            return 'Publishes the compacted summary back to the main channel with intent tags.';
        }
        break;
      case 'era-2026-agent-mesh':
        switch (step.stepNumber) {
          case 1:
            return 'Broadcasts turns to a shared bus tagged with semantic intents for rapid routing.';
          case 2:
            return 'Maintains private scratchpads for internal deliberation before public posting.';
          case 3:
            return 'Synthesizes unconsolidated events and crystallizes long-term beliefs during idle periods.';
          case 4:
            return 'Combines blackboard events, private scratchpad state, and crystallized beliefs for consensus action.';
        }
        break;
    }
    return 'Executes step-level cognitive memory transformation.';
  }
}
