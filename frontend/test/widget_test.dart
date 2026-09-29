import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chat_models.dart';
import 'package:frontend/widgets/eras/aim_messenger_view.dart';
import 'package:frontend/widgets/eras/campfire_view.dart';
import 'package:frontend/widgets/eras/slack_threads_view.dart';
import 'package:frontend/widgets/eras/slack_v1_view.dart';
import 'package:frontend/widgets/eras/irc_terminal_view.dart';
import 'package:frontend/widgets/eras/agent_mesh_view.dart';
import 'package:frontend/widgets/top_era_bar.dart';
import 'package:frontend/widgets/memory_architecture_drawer.dart';

void main() {
  group('TopEraBar Widget Tests', () {
    testWidgets('Renders era title and navigation steppers', (WidgetTester tester) async {
      final eras = [
        Era(
          id: 'era-1988-irc',
          year: 1988,
          name: '1988: Ephemeral Buffer (IRC)',
          platform: 'IRC',
          memoryConcept: 'Short-Term Memory & FIFO Eviction',
          shortDescription: 'The Amnesia Trap',
          description: 'The Amnesia Trap description',
          iconName: 'terminal',
        ),
        Era(
          id: 'era-1997-aim',
          year: 1997,
          name: '1997: 1:1 Direct Presence (AIM)',
          platform: 'AIM',
          memoryConcept: 'Working Memory & Attention',
          shortDescription: '1:1 Working Memory',
          description: '1:1 Working Memory description',
          iconName: 'chat_bubble',
        ),
      ];

      final pacing = PacingMode(paused: false, intervalSeconds: 8);
      Era? selectedEra = eras.first;

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TopEraBar(
              eras: eras,
              selectedEra: selectedEra,
              onSelectEra: (e) => selectedEra = e,
              pacing: pacing,
              onUpdatePacing: (_) {},
              onReseed: () {},
            ),
          ),
        ),
      );

      // Verify Prev Era and Next Era buttons exist
      expect(find.text('Prev Era'), findsOneWidget);
      expect(find.text('Next Era'), findsOneWidget);
      // Verify progress pill 1/2
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('Renders Memory Architecture button and toggles on tap', (WidgetTester tester) async {
      final eras = [
        Era(
          id: 'era-1988-irc',
          year: 1988,
          name: '1988: Ephemeral Buffer (IRC)',
          platform: 'IRC',
          memoryConcept: 'Short-Term Memory & FIFO Eviction',
          shortDescription: 'The Amnesia Trap',
          description: 'The Amnesia Trap description',
          iconName: 'terminal',
        ),
      ];

      final pacing = PacingMode(paused: false, intervalSeconds: 8);
      bool drawerToggled = false;

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TopEraBar(
              eras: eras,
              selectedEra: eras.first,
              onSelectEra: (_) {},
              pacing: pacing,
              onUpdatePacing: (_) {},
              onReseed: () {},
              isArchitectureDrawerOpen: false,
              onToggleArchitectureDrawer: () => drawerToggled = true,
              telemetryCount: 5,
              hasActiveTelemetry: true,
            ),
          ),
        ),
      );

      // Verify Memory Architecture button is rendered
      expect(find.text('Memory Architecture'), findsOneWidget);

      // Verify telemetry count pill
      expect(find.text('5'), findsOneWidget);

      // Ensure button is visible in horizontal scroll and tap it
      await tester.ensureVisible(find.text('Memory Architecture'));
      await tester.tap(find.text('Memory Architecture'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(drawerToggled, isTrue);
    });
  });

  group('AimMessengerView Widget Tests', () {
    testWidgets('Renders buddy list and switches channel on buddy tap', (WidgetTester tester) async {
      final chanLead = Channel(
        id: 'chan-1997-aim',
        eraId: 'era-1997-aim',
        name: '1997-aim-lead',
        topic: '1:1 Direct Message: Jason <-> Lead',
        description: 'AIM buddy chat with Lead',
        systemPrompt: 'You are Lead Coordinator',
        retentionHours: 24,
      );
      final chanScribe = Channel(
        id: 'chan-1997-aim-scribe',
        eraId: 'era-1997-aim',
        name: '1997-aim-scribe',
        topic: '1:1 Direct Message: Jason <-> Scribe',
        description: 'AIM buddy chat with Scribe',
        systemPrompt: 'You are Staff Architect Scribe',
        retentionHours: 24,
      );

      final presences = [
        AgentPresence(
          agentId: 'lead-agent',
          agentName: 'Lead Coordinator',
          avatarUrl: '',
          status: 'available',
          statusMessage: 'Online and routing requests',
          currentTask: 'Triage',
          lastHeartbeat: DateTime.now(),
        ),
        AgentPresence(
          agentId: 'scribe-agent',
          agentName: 'Staff Scribe',
          avatarUrl: '',
          status: 'away',
          statusMessage: 'Away from keyboard - compacting memory',
          currentTask: 'Compaction',
          lastHeartbeat: DateTime.now(),
        ),
      ];

      final messages = [
        Message(
          id: 'msg-aim-1',
          channelId: 'chan-1997-aim',
          senderType: 'agent',
          senderId: 'lead-agent',
          senderName: 'Lead Coordinator',
          content: 'Hello Jason! This is 1:1 direct working memory.',
          tokenCount: 15,
          intentTags: [],
          createdAt: DateTime.now(),
        ),
      ];

      Channel? selectedChannel;

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AimMessengerView(
              channels: [chanLead, chanScribe],
              channel: chanLead,
              onSelectChannel: (c) => selectedChannel = c,
              messages: messages,
              presences: presences,
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Verify buddy list header and buddies render
      expect(find.textContaining('Buddy List'), findsWidgets);
      expect(find.text('Lead Coordinator'), findsWidgets);
      expect(find.text('Staff Scribe'), findsOneWidget);

      // Verify the chat message is visible in RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Hello Jason! This is 1:1 direct working memory.'),
        ),
        findsOneWidget,
      );

      // Tap on Staff Scribe in the buddy list
      await tester.tap(find.text('Staff Scribe'));
      await tester.pumpAndSettle();

      // Verify onSelectChannel was called with the scribe channel
      expect(selectedChannel, isNotNull);
      expect(selectedChannel?.id, equals('chan-1997-aim-scribe'));
    });
  });

  group('CampfireView Widget Tests', () {
    testWidgets('Renders rooms and switches room on click', (WidgetTester tester) async {
      final chanLobby = Channel(
        id: 'chan-2006-campfire-lobby',
        eraId: 'era-2006-campfire',
        name: 'campfire-general-lobby',
        topic: 'General project chat',
        description: 'Lobby',
        systemPrompt: 'Campfire assistant',
        retentionHours: 48,
      );
      final chanEng = Channel(
        id: 'chan-2006-campfire-eng',
        eraId: 'era-2006-campfire',
        name: 'campfire-engineering',
        topic: 'Engineering coordination',
        description: 'Engineering',
        systemPrompt: 'Engineering lead',
        retentionHours: 48,
      );

      Channel? selectedChannel;

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampfireView(
              channels: [chanLobby, chanEng],
              selectedChannel: chanLobby,
              onSelectChannel: (c) => selectedChannel = c,
              messages: const [],
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Verify rooms are visible
      expect(find.text('#general-lobby'), findsOneWidget);
      expect(find.text('#engineering'), findsOneWidget);
      expect(find.text('#billing-confidential'), findsWidgets);

      // Tap on #engineering
      await tester.tap(find.text('#engineering'));
      await tester.pumpAndSettle();

      // Verify onSelectChannel was called with engineering channel
      expect(selectedChannel, isNotNull);
      expect(selectedChannel?.id, equals('chan-2006-campfire-eng'));
    });
  });

  group('SlackThreadsView Widget Tests', () {
    testWidgets('Displays root stream and thread drawer side-by-side', (WidgetTester tester) async {
      final chanSlack = Channel(
        id: 'chan-2017-threads',
        eraId: 'era-2017-slack-threads',
        name: 'general-threads',
        topic: 'Sub-task context isolation',
        description: 'Threads demo',
        systemPrompt: 'Thread orchestrator',
        retentionHours: 168,
      );

      final rootMessages = [
        Message(
          id: 'msg-root-1',
          channelId: 'chan-2017-threads',
          senderType: 'user',
          senderId: 'user-jason',
          senderName: 'Jason',
          content: 'Investigating database deadlock issue',
          tokenCount: 12,
          intentTags: [
            IntentTag(label: 'investigate', type: 'context', color: 'sepia', description: 'Investigation'),
          ],
          threadId: null,
          createdAt: DateTime.now(),
        ),
      ];

      final threadMessages = [
        Message(
          id: 'msg-thread-1',
          channelId: 'chan-2017-threads',
          senderType: 'agent',
          senderId: 'researcher-agent',
          senderName: 'Researcher Agent',
          content: 'Checking table lock logs for Apollo transactions',
          tokenCount: 18,
          intentTags: [
            IntentTag(label: 'analysis', type: 'context', color: 'sepia', description: 'Analysis'),
          ],
          threadId: 'msg-root-1',
          createdAt: DateTime.now(),
        ),
      ];

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlackThreadsView(
              channels: [chanSlack],
              selectedChannel: chanSlack,
              onSelectChannel: (_) {},
              messages: rootMessages,
              threadMessages: threadMessages,
              activeThreadId: 'msg-root-1',
              onOpenThread: (_) {},
              onCloseThread: () {},
              onSendMessage: (txt, {threadId}) {},
            ),
          ),
        ),
      );

      // Verify root message is visible (in main stream and as thread header)
      expect(find.text('Investigating database deadlock issue'), findsWidgets);
      // Verify thread message is visible inside drawer
      expect(find.text('Checking table lock logs for Apollo transactions'), findsOneWidget);
      // Verify Thread header in drawer
      expect(find.text('Thread Scratchpad'), findsOneWidget);
    });
  });

  group('SlackV1View Widget Tests', () {
    testWidgets('Tapping a bot in roster inserts mention into composer', (WidgetTester tester) async {
      final chanSlackV1 = Channel(
        id: 'chan-2013-slack',
        eraId: 'era-2013-slack',
        name: 'general',
        topic: 'Slack 1.0 RAG Search',
        description: 'Slack 1.0',
        systemPrompt: 'Slack bot',
        retentionHours: 168,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlackV1View(
              channels: [chanSlackV1],
              selectedChannel: chanSlackV1,
              onSelectChannel: (_) {},
              messages: const [],
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Tap on the @researcher bot in the sidebar roster
      expect(find.text('Dev Researcher'), findsOneWidget);
      await tester.tap(find.text('Dev Researcher'));
      await tester.pumpAndSettle();

      // Verify composer text now contains @researcher
      expect(find.text('@researcher '), findsOneWidget);
    });
  });

  group('IrcTerminalView Widget Tests', () {
    testWidgets('Renders retro CRT terminal and prompt', (WidgetTester tester) async {
      final chanIrc = Channel(
        id: 'chan-1988-irc',
        eraId: 'era-1988-irc',
        name: 'agentic',
        topic: 'Short-term memory amnesia demo',
        description: 'IRC Channel',
        systemPrompt: 'Eggdrop bot',
        retentionHours: 1,
      );

      final buffer = MemoryBuffer(
        channelId: 'chan-1988-irc',
        currentTurns: 5,
        maxTurns: 10,
        evictedCount: 2,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IrcTerminalView(
              channel: chanIrc,
              messages: const [],
              buffer: buffer,
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Verify terminal status bar and channel title
      expect(find.textContaining('agentic'), findsWidgets);
      expect(find.textContaining('5/10'), findsOneWidget);
    });
  });

  group('AgentMeshView Widget Tests', () {
    testWidgets('Renders 3-panel mesh layout and presence roster', (WidgetTester tester) async {
      final chanMesh = Channel(
        id: 'chan-2026-mesh',
        eraId: 'era-2026-mesh',
        name: 'mesh-blackboard',
        topic: 'Autonomous Multi-Agent Mesh',
        description: 'Blackboard',
        systemPrompt: 'Mesh coordinator',
        retentionHours: 720,
      );

      final presences = [
        AgentPresence(
          agentId: 'lead-coordinator',
          agentName: 'Lead Coordinator',
          avatarUrl: '',
          status: 'online',
          statusMessage: 'Routing sub-tasks',
          currentTask: 'Architecture review',
          lastHeartbeat: DateTime.now(),
        ),
      ];

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentMeshView(
              channels: [chanMesh],
              selectedChannel: chanMesh,
              onSelectChannel: (_) {},
              messages: const [],
              presences: presences,
              consolidationReports: const [],
              isDreaming: false,
              onSendMessage: (_) {},
              onInjectEvent: (_, _) {},
            ),
          ),
        ),
      );

      // Verify presence name and 3-panel elements render
      expect(find.text('Lead Coordinator'), findsWidgets);
    });
  });

  group('Architecture Drawer Layout & Toggle Integration Tests', () {
    testWidgets('Toggles MemoryArchitectureDrawer open and closed with floating pill fallback',
        (WidgetTester tester) async {
      final era = Era(
        id: 'era-1988-irc',
        year: 1988,
        name: '1988: Ephemeral Buffer (IRC)',
        platform: 'IRC',
        memoryConcept: 'Short-Term Memory & FIFO Eviction',
        shortDescription: 'The Amnesia Trap',
        description: 'The Amnesia Trap description',
        iconName: 'terminal',
      );
      final channel = Channel(
        id: 'chan-1988-irc',
        eraId: 'era-1988-irc',
        name: 'agentic',
        topic: 'IRC Channel',
        description: 'IRC Test Channel',
        systemPrompt: 'You are IRC Eggdrop bot',
        retentionHours: 1,
      );

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool isOpen = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                appBar: TopEraBar(
                  eras: [era],
                  selectedEra: era,
                  onSelectEra: (_) {},
                  pacing: PacingMode(paused: false, intervalSeconds: 8),
                  onUpdatePacing: (_) {},
                  onReseed: () {},
                  isArchitectureDrawerOpen: isOpen,
                  onToggleArchitectureDrawer: () => setState(() => isOpen = !isOpen),
                  telemetryCount: 3,
                ),
                body: Stack(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Center(child: Text('Main Stream Body'))),
                        if (isOpen)
                          MemoryArchitectureDrawer(
                            era: era,
                            channel: channel,
                            telemetrySpans: const [],
                            onClose: () => setState(() => isOpen = false),
                          ),
                      ],
                    ),
                    if (!isOpen)
                      Positioned(
                        top: 16,
                        right: 0,
                        child: InkWell(
                          key: const ValueKey('floating_toggle_pill'),
                          onTap: () => setState(() => isOpen = true),
                          child: const Text('Floating Architecture Pill'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Architecture Drawer is open by default: verify 4-stage steps are rendered
      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('STEP 1'), findsWidgets);
      expect(find.text('Main Stream Body'), findsOneWidget);

      // Close the drawer using the close button in MemoryArchitectureDrawer
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Drawer is closed: floating toggle pill is now visible
      expect(find.text('Floating Architecture Pill'), findsOneWidget);
      expect(find.text('Architecture'), findsNothing);

      // Tap the floating pill to re-open the drawer
      await tester.tap(find.text('Floating Architecture Pill'));
      await tester.pumpAndSettle();

      // Drawer is reopened: verify Architecture tab is back
      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('Floating Architecture Pill'), findsNothing);
    });

    testWidgets('AgentMeshView renders both with default closed drawer and when manually opened',
        (WidgetTester tester) async {
      final chanMesh = Channel(
        id: 'chan-2026-mesh',
        eraId: 'era-2026-mesh',
        name: 'mesh-blackboard',
        topic: 'Autonomous Multi-Agent Mesh',
        description: 'Blackboard',
        systemPrompt: 'Mesh coordinator',
        retentionHours: 720,
      );

      final presences = [
        AgentPresence(
          agentId: 'lead-coordinator',
          agentName: 'Lead Coordinator',
          avatarUrl: '',
          status: 'online',
          statusMessage: 'Routing sub-tasks',
          currentTask: 'Architecture review',
          lastHeartbeat: DateTime.now(),
        ),
      ];

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentMeshView(
              channels: [chanMesh],
              selectedChannel: chanMesh,
              onSelectChannel: (_) {},
              messages: const [],
              presences: presences,
              consolidationReports: const [],
              isDreaming: false,
              onSendMessage: (_) {},
              onInjectEvent: (_, _) {},
              initialDrawerOpen: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Roster is visible
      expect(find.text('Lead Coordinator'), findsWidgets);

      // Tap the Memory Lens drawer toggle icon in Blackboard header
      final toggleButton = find.byTooltip('Open Memory Lens Drawer');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Memory Lens Drawer is now opened
      expect(find.text('Memory Lens Drawer'), findsOneWidget);

      // Verify close button in drawer closes it
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('Memory Lens Drawer'), findsNothing);
    });
  });
}
