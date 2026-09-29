import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/era_architecture_models.dart';

void main() {
  group('EraArchitectureModels & Catalog Tests', () {
    test('Catalog contains all 6 eras with 4 pipeline steps each and modern cognitive concepts', () {
      final all = EraArchitectureCatalog.allArchitectures;
      expect(all.length, equals(6));

      final expectedEraIds = [
        'era-1988-irc',
        'era-1997-aim',
        'era-2006-campfire',
        'era-2013-slack',
        'era-2017-threads',
        'era-2026-agent-mesh',
      ];

      for (var i = 0; i < expectedEraIds.length; i++) {
        final eraId = expectedEraIds[i];
        final arch = EraArchitectureCatalog.getArchitecture(eraId);
        expect(arch.eraId, equals(eraId));
        expect(arch.steps.length, equals(4), reason: 'Era $eraId must have exactly 4 pipeline steps');
        expect(arch.primaryCodeSnippet.isNotEmpty, isTrue);
        expect(arch.schemaSnippet.isNotEmpty, isTrue);
        expect(arch.title.isNotEmpty, isTrue);
        expect(arch.cognitiveConcept.isNotEmpty, isTrue);
        expect(arch.summary.isNotEmpty, isTrue);

        // Verify absence of obsolete networking jargon
        expect(arch.primaryCodeSnippet.contains('irc_ring_buffer_t'), isFalse);
        expect(arch.schemaSnippet.contains('irc_ring_buffer_t'), isFalse);
        expect(arch.schemaSnippet.contains('typedef struct'), isFalse);

        for (var stepIndex = 0; stepIndex < arch.steps.length; stepIndex++) {
          final step = arch.steps[stepIndex];
          expect(step.stepNumber, equals(stepIndex + 1));
          expect(step.badgeLabel.isNotEmpty, isTrue);
          expect(step.flowTag.isNotEmpty, isTrue);
          expect(step.iconName.isNotEmpty, isTrue);
          expect(step.title.isNotEmpty, isTrue);
          expect(step.techStack.isNotEmpty, isTrue);
          expect(step.metaBadges.isNotEmpty, isTrue);
          expect(step.description.isNotEmpty, isTrue);
          expect(step.sampleCode.isNotEmpty, isTrue);
          expect(step.codeLanguage.isNotEmpty, isTrue);

          // Verify no obsolete networking protocol jargon in steps
          expect(step.techStack.contains('TCP RFC 1459'), isFalse);
          expect(step.techStack.contains('OSCAR SNAC'), isFalse);
          expect(step.techStack.contains('FLAP Framing'), isFalse);
          for (final badge in step.metaBadges) {
            expect(badge.contains('TCP RFC 1459'), isFalse);
            expect(badge.contains('OSCAR'), isFalse);
            expect(badge.contains('FLAP'), isFalse);
          }
        }
      }

      // Verify specific cognitive concepts for each era
      expect(
        EraArchitectureCatalog.getArchitecture('era-1988-irc').cognitiveConcept,
        equals('Short-Term Memory (STM) & FIFO Sliding Context Windows'),
      );
      expect(
        EraArchitectureCatalog.getArchitecture('era-1997-aim').cognitiveConcept,
        equals('1:1 Session Working Memory & Attentional Liveness'),
      );
      expect(
        EraArchitectureCatalog.getArchitecture('era-2006-campfire').cognitiveConcept,
        equals('Context Fencing & Role-Based Isolation'),
      );
      expect(
        EraArchitectureCatalog.getArchitecture('era-2013-slack').cognitiveConcept,
        equals('Long-Term Memory (LTM) & Spanner Vector RAG'),
      );
      expect(
        EraArchitectureCatalog.getArchitecture('era-2017-threads').cognitiveConcept,
        equals('Subagent Scratchpads & Hierarchical Compaction'),
      );
      expect(
        EraArchitectureCatalog.getArchitecture('era-2026-agent-mesh').cognitiveConcept,
        equals('Dual-Layer Cognitive Mesh & REM Dreaming'),
      );
    });

    test('Catalog resolves aliases and unknown eras gracefully', () {
      final arch2017Alias = EraArchitectureCatalog.getArchitecture('era-2017-slack-threads');
      expect(arch2017Alias.eraId, equals('era-2017-threads'));

      final arch2026Alias = EraArchitectureCatalog.getArchitecture('era-2026-mesh');
      expect(arch2026Alias.eraId, equals('era-2026-agent-mesh'));

      final archSubstring = EraArchitectureCatalog.getArchitecture('campfire-room');
      expect(archSubstring.eraId, equals('era-2006-campfire'));

      final fallback = EraArchitectureCatalog.getArchitecture('unknown-era');
      expect(fallback.eraId, equals('era-1988-irc'));
    });

    test('ArchitecturePipelineStep serialization round-trip', () {
      const step = ArchitecturePipelineStep(
        stepNumber: 1,
        badgeLabel: 'STEP 1 • CONTEXT INGESTION',
        flowTag: '→ Sliding Token Window',
        iconName: 'input',
        title: 'Short-Term Ingestion & Fixed Context Budget',
        techStack: 'Go / Tokenizer / Sliding Buffer',
        metaBadges: ['Short-Term Memory', 'Fixed Budget', 'Recency Bias'],
        description: 'Test step description',
        sampleCode: 'fmt.Println("test")',
        codeLanguage: 'go',
      );

      final json = step.toJson();
      expect(json['step_number'], equals(1));
      expect(json['badge_label'], equals('STEP 1 • CONTEXT INGESTION'));
      expect(json['code_language'], equals('go'));

      final decoded = ArchitecturePipelineStep.fromJson(json);
      expect(decoded.stepNumber, equals(1));
      expect(decoded.badgeLabel, equals(step.badgeLabel));
      expect(decoded.metaBadges, equals(['Short-Term Memory', 'Fixed Budget', 'Recency Bias']));
      expect(decoded.sampleCode, equals(step.sampleCode));
    });

    test('EraArchitecture serialization round-trip', () {
      final arch = EraArchitectureCatalog.getArchitecture('era-1988-irc');
      final json = arch.toJson();
      expect(json['era_id'], equals('era-1988-irc'));
      expect(json['year'], equals(1988));
      expect((json['steps'] as List).length, equals(4));

      final decoded = EraArchitecture.fromJson(json);
      expect(decoded.eraId, equals('era-1988-irc'));
      expect(decoded.year, equals(1988));
      expect(decoded.steps.length, equals(4));
      expect(decoded.steps[0].stepNumber, equals(1));
    });

    test('TelemetrySpan parses snake_case and camelCase and serializes accurately', () {
      final now = DateTime.now();
      final spanJson = {
        'id': 'span-1001',
        'era_id': 'era-1988-irc',
        'channel_id': 'chan-1988-irc',
        'thread_id': 'thread-abc',
        'action': 'FIFO_EVICT',
        'active_step': 3,
        'title': 'The Amnesia Trap: Turn Displaced',
        'description': 'RAM buffer capacity exceeded',
        'latency_ms': 12,
        'metrics': {'evicted_count': 1, 'max_buffer_turns': 10},
        'payload': 'Old message content',
        'timestamp': now.toIso8601String(),
      };

      final span = TelemetrySpan.fromJson(spanJson);
      expect(span.id, equals('span-1001'));
      expect(span.eraId, equals('era-1988-irc'));
      expect(span.channelId, equals('chan-1988-irc'));
      expect(span.threadId, equals('thread-abc'));
      expect(span.action, equals('FIFO_EVICT'));
      expect(span.activeStep, equals(3));
      expect(span.title, equals('The Amnesia Trap: Turn Displaced'));
      expect(span.description, equals('RAM buffer capacity exceeded'));
      expect(span.latencyMs, equals(12));
      expect(span.metrics['evicted_count'], equals(1));
      expect(span.payload, equals('Old message content'));

      final outJson = span.toJson();
      expect(outJson['action'], equals('FIFO_EVICT'));
      expect(outJson['active_step'], equals(3));
      expect(outJson['latency_ms'], equals(12));
      expect(outJson['thread_id'], equals('thread-abc'));
    });

    test('EraTradeoff model round-trip and catalog coverage for all 6 eras', () {
      expect(EraArchitectureCatalog.eraTradeoffs.length, equals(6));

      final expectedEras = [
        'era-1988-irc',
        'era-1997-aim',
        'era-2006-campfire',
        'era-2013-slack',
        'era-2017-threads',
        'era-2026-agent-mesh',
      ];

      for (final eraId in expectedEras) {
        final tradeoff = EraArchitectureCatalog.getTradeoff(eraId);
        expect(tradeoff.eraId, equals(eraId));
        expect(tradeoff.title.isNotEmpty, isTrue);
        expect(tradeoff.modernAnalogy.isNotEmpty, isTrue);
        expect(tradeoff.benefits.length, greaterThanOrEqualTo(2));
        expect(tradeoff.drawbacks.length, greaterThanOrEqualTo(2));
        expect(tradeoff.failureModeTitle.isNotEmpty, isTrue);
        expect(tradeoff.failureModeDescription.isNotEmpty, isTrue);
        expect(tradeoff.verdict2026.isNotEmpty, isTrue);

        final json = tradeoff.toJson();
        expect(json['era_id'], equals(eraId));
        expect(json['failure_mode_title'], equals(tradeoff.failureModeTitle));

        final decoded = EraTradeoff.fromJson(json);
        expect(decoded.eraId, equals(tradeoff.eraId));
        expect(decoded.year, equals(tradeoff.year));
        expect(decoded.title, equals(tradeoff.title));
        expect(decoded.modernAnalogy, equals(tradeoff.modernAnalogy));
        expect(decoded.benefits, equals(tradeoff.benefits));
        expect(decoded.drawbacks, equals(tradeoff.drawbacks));
        expect(decoded.failureModeTitle, equals(tradeoff.failureModeTitle));
        expect(decoded.failureModeDescription, equals(tradeoff.failureModeDescription));
        expect(decoded.verdict2026, equals(tradeoff.verdict2026));
      }

      // Test alias resolution in getTradeoff
      expect(EraArchitectureCatalog.getTradeoff('era-2017-slack-threads').eraId, equals('era-2017-threads'));
      expect(EraArchitectureCatalog.getTradeoff('era-2026-mesh').eraId, equals('era-2026-agent-mesh'));
      expect(EraArchitectureCatalog.getTradeoff('aim-dm').eraId, equals('era-1997-aim'));
      expect(EraArchitectureCatalog.getTradeoff('unknown').eraId, equals('era-1988-irc'));
    });

    test('ShowcaseScriptStep model round-trip and all 6 action triggers coverage', () {
      expect(EraArchitectureCatalog.showcaseScriptSteps.length, equals(6));

      final expectedActions = {
        'action-era1-overflow': {
          'label': 'Simulate Amnesia Trap (6 Turns)',
          'eraId': 'era-1988-irc',
          'spanAction': 'FIFO_EVICT',
          'isDestructive': true,
        },
        'action-era2-test-boundary': {
          'label': 'Verify 1:1 Session Isolation',
          'eraId': 'era-1997-aim',
          'spanAction': 'ATTENTIONAL_SHIFT',
          'isDestructive': false,
        },
        'action-era3-trigger-quarantine': {
          'label': 'Trigger RBAC Firewall Quarantine',
          'eraId': 'era-2006-campfire',
          'spanAction': 'FIREWALL_QUARANTINE',
          'isDestructive': true,
        },
        'action-era4-vector-query': {
          'label': 'Run Spanner Vector RAG Query',
          'eraId': 'era-2013-slack',
          'spanAction': 'VECTOR_SEARCH',
          'isDestructive': false,
        },
        'action-era5-compact-thread': {
          'label': 'Compact Thread Context (-96%)',
          'eraId': 'era-2017-threads',
          'spanAction': 'SCRIBE_COMPACT',
          'isDestructive': false,
        },
        'action-era6-trigger-dreaming': {
          'label': 'Trigger REM Dreaming Consolidation',
          'eraId': 'era-2026-agent-mesh',
          'spanAction': 'DREAM_CONSOLIDATION',
          'isDestructive': false,
        },
      };

      for (final step in EraArchitectureCatalog.showcaseScriptSteps) {
        expect(step.id.isNotEmpty, isTrue);
        expect(step.eraId.isNotEmpty, isTrue);
        expect(step.title.isNotEmpty, isTrue);
        expect(step.speakerScript.isNotEmpty, isTrue);
        expect(step.audienceObservation.isNotEmpty, isTrue);
        expect(step.actionLabel.isNotEmpty, isTrue);
        expect(step.actionId.isNotEmpty, isTrue);
        expect(step.expectedSpanAction.isNotEmpty, isTrue);

        final expected = expectedActions[step.actionId];
        expect(expected, isNotNull, reason: 'Action ID ${step.actionId} must match specification');
        expect(step.actionLabel, equals(expected!['label']));
        expect(step.eraId, equals(expected['eraId']));
        expect(step.expectedSpanAction, equals(expected['spanAction']));
        expect(step.isDestructive, equals(expected['isDestructive']));

        // Test serialization round-trip
        final json = step.toJson();
        expect(json['action_id'], equals(step.actionId));
        expect(json['expected_span_action'], equals(step.expectedSpanAction));

        final decoded = ShowcaseScriptStep.fromJson(json);
        expect(decoded.id, equals(step.id));
        expect(decoded.eraId, equals(step.eraId));
        expect(decoded.stepNumber, equals(step.stepNumber));
        expect(decoded.title, equals(step.title));
        expect(decoded.speakerScript, equals(step.speakerScript));
        expect(decoded.audienceObservation, equals(step.audienceObservation));
        expect(decoded.actionLabel, equals(step.actionLabel));
        expect(decoded.actionId, equals(step.actionId));
        expect(decoded.isDestructive, equals(step.isDestructive));
        expect(decoded.expectedSpanAction, equals(step.expectedSpanAction));
      }
    });
  });
}
