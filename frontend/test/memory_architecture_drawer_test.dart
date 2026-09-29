import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chat_models.dart';
import 'package:frontend/models/era_architecture_models.dart';
import 'package:frontend/widgets/memory_architecture_drawer.dart';

void main() {
  final testEra1988 = Era(
    id: 'era-1988-irc',
    year: 1988,
    name: '1988: Ephemeral Buffer (IRC & Unix talk)',
    platform: 'IRC',
    memoryConcept: 'Short-Term Memory & FIFO Eviction',
    shortDescription: 'The Amnesia Trap',
    description: 'Volatile in-memory circular ring buffer',
    iconName: 'terminal',
  );

  final testEra2026 = Era(
    id: 'era-2026-agent-mesh',
    year: 2026,
    name: '2026: Collaborative Multi-Agent Mesh',
    platform: 'Agent Mesh',
    memoryConcept: 'Dual-Layer Memory: Blackboard vs Scratchpad',
    shortDescription: 'Multi-Agent Mesh',
    description: 'Dual layer memory with dreaming consolidation',
    iconName: 'hub',
  );

  final testChannel = Channel(
    id: 'chan-1988-irc',
    eraId: 'era-1988-irc',
    name: 'agentic',
    topic: 'IRC Channel',
    description: 'IRC Test Channel',
    systemPrompt: 'You are IRC Eggdrop bot',
    retentionHours: 1,
  );

  Widget createTestWidget({
    Era? era,
    Channel? channel,
    List<TelemetrySpan> telemetrySpans = const [],
    int? activeStepIndex,
    MemoryBuffer? buffer,
    List<ConsolidationReport>? consolidationReports,
    VoidCallback? onClose,
    VoidCallback? onTriggerDreaming,
    Future<void> Function(ShowcaseScriptStep step)? onExecuteScriptStep,
    Function(String eraId)? onSwitchEra,
    bool isDreaming = false,
    bool enableAnimations = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MemoryArchitectureDrawer(
          era: era ?? testEra1988,
          channel: channel ?? testChannel,
          telemetrySpans: telemetrySpans,
          activeStepIndex: activeStepIndex,
          buffer: buffer,
          consolidationReports: consolidationReports,
          onClose: onClose,
          onTriggerDreaming: onTriggerDreaming,
          onExecuteScriptStep: onExecuteScriptStep,
          onSwitchEra: onSwitchEra,
          isDreaming: isDreaming,
          enableAnimations: enableAnimations,
        ),
      ),
    );
  }

  group('MemoryArchitectureDrawer Header & Controls Tests', () {
    testWidgets('Renders Era Year pill, title, paradigm, and IDLE status when inactive',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check Era year pill
      expect(find.text('1988'), findsOneWidget);

      // Check Era Title
      expect(find.textContaining('1988: Ephemeral Buffer'), findsWidgets);

      // Check Cognitive Paradigm
      expect(find.textContaining('Short-Term Memory & FIFO Eviction'), findsOneWidget);

      // Check Idle Badge
      expect(find.textContaining('IDLE'), findsOneWidget);

      // Check 4 Tabs
      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('Tradeoffs & Script'), findsOneWidget);
      expect(find.text('Sample Code'), findsOneWidget);
      expect(find.text('Live Telemetry'), findsOneWidget);
    });

    testWidgets('Renders LIVE EXECUTION badge when activeStepIndex is set',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(activeStepIndex: 2, enableAnimations: true));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('LIVE EXECUTION'), findsOneWidget);
    });

    testWidgets('Tapping close button triggers onClose callback', (WidgetTester tester) async {
      bool closed = false;

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(onClose: () => closed = true));
      await tester.pumpAndSettle();

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });

  group('Tab 1: Architecture & 4-Stage Pipeline Grid Tests', () {
    testWidgets('Renders 4 pipeline step cards with step numbers and flow tags',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify all 4 step badges exist
      expect(find.text('STEP 1'), findsWidgets);
      expect(find.text('STEP 2'), findsWidgets);
      expect(find.text('STEP 3'), findsWidgets);
      expect(find.text('STEP 4'), findsWidgets);

      // Verify flow tags
      expect(find.text('→ Sliding Token Window'), findsOneWidget);
      expect(find.text('→ RAM Ring Buffer'), findsOneWidget);
      expect(find.text('→ Slide Window Boundary'), findsOneWidget);
      expect(find.text('→ Active Buffer Window'), findsOneWidget);

      // Verify step deep-dive inspector is visible
      expect(find.textContaining('INSPECTOR: STEP 1'), findsOneWidget);
      expect(find.textContaining('MEMORY MECHANISM:'), findsOneWidget);
      expect(find.textContaining('STEP IMPLEMENTATION CODE:'), findsOneWidget);
    });

    testWidgets('Tapping step 3 card updates deep-dive inspector to Step 3 FIFO Context Eviction',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on STEP 3 card
      final step3Card = find.text('STEP 3').first;
      await tester.tap(step3Card);
      await tester.pumpAndSettle();

      // Deep dive inspector now inspects STEP 3
      expect(find.textContaining('INSPECTOR: STEP 3'), findsOneWidget);
      expect(find.textContaining('FIFO Context Eviction'), findsWidgets);
    });

    testWidgets('Active step displays animated LIVE chip', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(activeStepIndex: 3, enableAnimations: true));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('LIVE'), findsOneWidget);
    });
  });

  group('Tab 2: Tradeoffs & Showcase Script Tests', () {
    testWidgets('Renders tradeoffs card with benefits, drawbacks, and showcase script with action triggers',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ShowcaseScriptStep? executedStep;
      await tester.pumpWidget(createTestWidget(
        onExecuteScriptStep: (step) async {
          executedStep = step;
        },
      ));
      await tester.pumpAndSettle();

      // Switch to Tab 2: Tradeoffs & Script
      await tester.tap(find.text('Tradeoffs & Script'));
      await tester.pumpAndSettle();

      // Check modern agent architecture card
      expect(find.text('MODERN AGENT ARCHITECTURE EQUIVALENT'), findsOneWidget);

      // Check benefits and drawbacks headers
      expect(find.text('Key Architectural Benefits'), findsOneWidget);
      expect(find.textContaining('Cognitive Drawbacks:'), findsOneWidget);

      // Scroll to presenter script section and action button
      await tester.drag(find.byKey(const Key('tradeoffs-script-listview')), const Offset(0, -650));
      await tester.pumpAndSettle();

      // Verify action button exists and tap it
      final buttonFinder = find.byKey(const Key('run-step-action-era1-overflow'));
      expect(buttonFinder, findsOneWidget);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(executedStep, isNotNull);
      expect(executedStep!.actionId, equals('action-era1-overflow'));
    });
  });

  group('Tab 3: Production Sample Code & Schemas Tests', () {
    testWidgets('Switches between primary implementation and schema with syntax highlighting and copy button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Tab 3: Sample Code
      await tester.ensureVisible(find.text('Sample Code'));
      await tester.tap(find.text('Sample Code'));
      await tester.pumpAndSettle();

      // Check language selector buttons exist
      expect(find.textContaining('GO Implementation'), findsOneWidget);
      expect(find.textContaining('REDIS DDL / Schema'), findsOneWidget);

      // Verify copy code button exists
      expect(find.text('Copy Code'), findsOneWidget);

      // Switch to schema tab
      await tester.tap(find.textContaining('REDIS DDL / Schema'));
      await tester.pumpAndSettle();

      // Verify schema content rendered
      expect(find.textContaining('context:chan-1988-irc:sliding_window'), findsWidgets);

      // Tap copy code button
      await tester.tap(find.text('Copy Code'));
      await tester.pump();

      // Verify feedback 'Copied!'
      expect(find.text('Copied!'), findsOneWidget);

      // Advance past the 2-second timer so no pending timers remain
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Tab 3: Live Telemetry Trace Tests', () {
    testWidgets('Displays empty state message when no telemetry spans',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(telemetrySpans: const []));
      await tester.pumpAndSettle();

      // Switch to Tab 4: Live Telemetry
      await tester.ensureVisible(find.text('Live Telemetry'));
      await tester.tap(find.text('Live Telemetry'));
      await tester.pumpAndSettle();

      // Check empty state message
      expect(
        find.text(
          'No live telemetry yet. Send a message, trigger dreaming, or inject an event to watch the cognitive memory pipeline execute.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Displays telemetry cards with action pill, latency, metrics, and expandable payload',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final spans = [
        TelemetrySpan(
          id: 'span-test-1',
          eraId: 'era-1988-irc',
          channelId: 'chan-1988-irc',
          action: 'FIFO_EVICT',
          activeStep: 3,
          title: 'The Amnesia Trap: Turn Displaced',
          description: 'Turn 0 dropped from volatile RAM buffer.',
          latencyMs: 14,
          metrics: {
            'evicted_count': 1,
            'max_turns': 10,
            'tokens': 120,
          },
          payload: 'Displaced Message: "Database password is secret123"',
          timestamp: now,
        ),
      ];

      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(telemetrySpans: spans));
      await tester.pumpAndSettle();

      // Switch to Tab 4: Live Telemetry
      await tester.ensureVisible(find.text('Live Telemetry'));
      await tester.tap(find.text('Live Telemetry'));
      await tester.pumpAndSettle();

      // Verify action pill
      expect(find.text('FIFO_EVICT'), findsOneWidget);

      // Verify title & latency
      expect(find.text('The Amnesia Trap: Turn Displaced'), findsOneWidget);
      expect(find.text('⏱️ 14ms'), findsOneWidget);

      // Verify metrics chips
      expect(find.text('Displaced: 1'), findsOneWidget);
      expect(find.text('Max Turns: 10'), findsOneWidget);
      expect(find.text('Tokens: 120'), findsOneWidget);

      // Verify expandable payload toggle
      expect(find.text('Show Payload Preview'), findsOneWidget);
      await tester.tap(find.text('Show Payload Preview'));
      await tester.pumpAndSettle();

      // Verify payload content visible
      expect(find.textContaining('Database password is secret123'), findsOneWidget);
    });

    testWidgets('Era 2026 Agent Mesh displays Trigger REM Dreaming Pass button and triggers callback',
        (WidgetTester tester) async {
      bool dreamingTriggered = false;

      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(
        era: testEra2026,
        onTriggerDreaming: () => dreamingTriggered = true,
      ));
      await tester.pumpAndSettle();

      // Switch to Tab 4: Live Telemetry
      await tester.ensureVisible(find.text('Live Telemetry'));
      await tester.tap(find.text('Live Telemetry'));
      await tester.pumpAndSettle();

      // Verify dreaming button is visible
      expect(find.text('Trigger REM Dreaming Pass'), findsOneWidget);

      // Tap dreaming button
      await tester.tap(find.text('Trigger REM Dreaming Pass'));
      await tester.pumpAndSettle();

      expect(dreamingTriggered, isTrue);
    });
  });
}
