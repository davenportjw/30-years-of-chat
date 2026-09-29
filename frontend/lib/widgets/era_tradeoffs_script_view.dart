import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/era_architecture_models.dart';
import '../theme/sepia_theme.dart';

/// EraTradeoffsScriptView provides:
/// 1. A structured Trade-off Matrix (Benefits vs. Drawbacks & 2026 Verdict) for each era.
/// 2. An Interactive Presenter / Showcase Script with one-click live execution triggers.
class EraTradeoffsScriptView extends StatefulWidget {
  final Era? era;
  final Channel? channel;
  final List<TelemetrySpan> telemetrySpans;
  final Future<void> Function(ShowcaseScriptStep step)? onExecuteScriptStep;
  final Function(String eraId)? onSwitchEra;

  const EraTradeoffsScriptView({
    super.key,
    this.era,
    this.channel,
    this.telemetrySpans = const [],
    this.onExecuteScriptStep,
    this.onSwitchEra,
  });

  @override
  State<EraTradeoffsScriptView> createState() => _EraTradeoffsScriptViewState();
}

class _EraTradeoffsScriptViewState extends State<EraTradeoffsScriptView> {
  String? _executingActionId;
  String? _selectedEraId;

  @override
  void initState() {
    super.initState();
    _selectedEraId = widget.era?.id ?? widget.channel?.eraId ?? 'era-1988-irc';
  }

  @override
  void didUpdateWidget(covariant EraTradeoffsScriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.era?.id != null && widget.era!.id != oldWidget.era?.id) {
      _selectedEraId = widget.era!.id;
    }
  }

  String get _currentEraId => _selectedEraId ?? widget.era?.id ?? 'era-1988-irc';

  EraTradeoff get _currentTradeoff => EraArchitectureCatalog.getTradeoff(_currentEraId);

  List<ShowcaseScriptStep> get _scriptSteps => EraArchitectureCatalog.showcaseScriptSteps;

  Future<void> _handleRunStep(ShowcaseScriptStep step) async {
    if (_executingActionId != null) return;
    setState(() => _executingActionId = step.actionId);

    // If step belongs to another era, switch era first
    if (widget.onSwitchEra != null && step.eraId != widget.era?.id) {
      widget.onSwitchEra!(step.eraId);
    }

    try {
      if (widget.onExecuteScriptStep != null) {
        await widget.onExecuteScriptStep!(step);
      }
    } finally {
      if (mounted) {
        setState(() => _executingActionId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tradeoff = _currentTradeoff;

    return ListView(
      key: const Key('tradeoffs-script-listview'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // 1. Era Selector Carousel / Chips
        _buildEraSwitcherRow(),

        const SizedBox(height: 14),

        // 2. Cognitive Trade-offs & Architecture Matrix Section
        _buildTradeoffMatrixCard(tradeoff),

        const SizedBox(height: 20),

        // 3. Interactive Presenter / Showcase Script Section Header
        _buildScriptSectionHeader(),

        const SizedBox(height: 12),

        // 4. Sequential Script Chapters
        for (final step in _scriptSteps) ...[
          _buildScriptStepCard(step),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEraSwitcherRow() {
    final allEras = [
      {'id': 'era-1988-irc', 'label': '1988 IRC'},
      {'id': 'era-1997-aim', 'label': '1997 AIM'},
      {'id': 'era-2006-campfire', 'label': '2006 Campfire'},
      {'id': 'era-2013-slack', 'label': '2013 Slack'},
      {'id': 'era-2017-threads', 'label': '2017 Threads'},
      {'id': 'era-2026-agent-mesh', 'label': '2026 Mesh'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: allEras.map((e) {
          final isSelected = e['id'] == _currentEraId;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                e['label']!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : SepiaTheme.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: SepiaTheme.primary,
              backgroundColor: SepiaTheme.card,
              side: BorderSide(
                color: isSelected ? SepiaTheme.primary : SepiaTheme.border,
                width: 1,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedEraId = e['id']);
                  if (widget.onSwitchEra != null) {
                    widget.onSwitchEra!(e['id']!);
                  }
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTradeoffMatrixCard(EraTradeoff tradeoff) {
    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Year + Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: SepiaTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${tradeoff.year}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tradeoff.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.textPrimary,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Modern Agent Analogy Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SepiaTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_alt, size: 18, color: SepiaTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MODERN AGENT ARCHITECTURE EQUIVALENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: SepiaTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tradeoff.modernAnalogy,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SepiaTheme.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Benefits / Strengths Section
          const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF2E7D32)),
              SizedBox(width: 6),
              Text(
                'Key Architectural Benefits',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final b in tradeoff.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(fontSize: 11.5, color: SepiaTheme.textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Drawbacks & Cognitive Pitfalls Section
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFC62828)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cognitive Drawbacks: ${tradeoff.failureModeTitle}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Text(
              tradeoff.failureModeDescription,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B0000), height: 1.35),
            ),
          ),
          const SizedBox(height: 6),
          for (final d in tradeoff.drawbacks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      d,
                      style: const TextStyle(fontSize: 11.5, color: SepiaTheme.textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // 2026 Production Verdict
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SepiaTheme.primaryLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel, size: 14, color: SepiaTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '2026 Verdict: ${tradeoff.verdict2026}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: SepiaTheme.textPrimary,
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

  Widget _buildScriptSectionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 16, color: SepiaTheme.primary),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Interactive Demo Scenarios',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SepiaTheme.textPrimary,
                fontFamily: 'serif',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: const Text(
              '6 Chapters',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptStepCard(ShowcaseScriptStep step) {
    final isActiveEra = step.eraId == _currentEraId;
    final isExecutingThis = _executingActionId == step.actionId;

    // Check if expected span fired recently in telemetry
    final hasRecentSpan = widget.telemetrySpans.any((span) =>
        span.action == step.expectedSpanAction &&
        DateTime.now().difference(span.timestamp).inSeconds.abs() <= 10);

    return Container(
      decoration: BoxDecoration(
        color: isActiveEra ? SepiaTheme.surface : SepiaTheme.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActiveEra ? SepiaTheme.primary : SepiaTheme.border,
          width: isActiveEra ? 1.5 : 1,
        ),
        boxShadow: isActiveEra
            ? [
                BoxShadow(
                  color: SepiaTheme.primary.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: isActiveEra ? SepiaTheme.primary : SepiaTheme.borderStrong,
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isActiveEra ? SepiaTheme.textPrimary : SepiaTheme.textSecondary,
                  ),
                ),
              ),
              if (isActiveEra)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Text(
                    'ACTIVE ERA',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Architectural Demo Cue & Observation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: SepiaTheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 14, color: SepiaTheme.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    step.audienceObservation,
                    style: const TextStyle(
                      fontSize: 11,
                      color: SepiaTheme.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Trigger Button & Telemetry Indicator
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                key: Key('run-step-${step.actionId}'),
                icon: isExecutingThis
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        step.isDestructive ? Icons.warning_amber : Icons.play_arrow,
                        size: 14,
                        color: Colors.white,
                      ),
                label: Text(
                  step.actionLabel,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: step.isDestructive ? const Color(0xFFC62828) : SepiaTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: isExecutingThis ? null : () => _handleRunStep(step),
              ),

              if (hasRecentSpan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 12, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(
                        'SPAN FIRED: ${step.expectedSpanAction}',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
