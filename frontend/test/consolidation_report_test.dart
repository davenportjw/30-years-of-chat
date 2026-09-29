import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chat_models.dart';
import 'package:frontend/widgets/eras/agent_mesh_view.dart';

void main() {
  group('CrystallizedBelief & ConsolidationReport fromJson Tests', () {
    test('parses comma-separated keywords string without throwing TypeError', () {
      final json = {
        'key': 'cloud_run_stack',
        'value': 'Cloud Run with Vertex AI Gemini 3.8',
        'category': 'Infrastructure',
        'confidence': 0.98,
        'keywords': 'Cloud Run, Terraform, Gemini 3.8 Flash, orchestration, deployment',
        'statement': 'Production stack runs on Cloud Run.',
      };

      final belief = CrystallizedBelief.fromJson(json);
      expect(belief.key, equals('cloud_run_stack'));
      expect(belief.keywords, equals([
        'Cloud Run',
        'Terraform',
        'Gemini 3.8 Flash',
        'orchestration',
        'deployment',
      ]));
    });

    test('parses list of keyword strings normally', () {
      final json = {
        'key': 'security_policies',
        'value': 'Application Default Credentials (ADC) with zero secrets in code',
        'category': 'Security',
        'confidence': 0.99,
        'keywords': ['ADC', 'Vertex AI', 'Gemini 3.8', 'Auth', 'Zero-Trust'],
        'statement': 'Security policies strictly require ADC.',
      };

      final belief = CrystallizedBelief.fromJson(json);
      expect(belief.keywords, equals(['ADC', 'Vertex AI', 'Gemini 3.8', 'Auth', 'Zero-Trust']));
    });

    test('parses null or missing keywords gracefully as empty list', () {
      final json = {
        'key': 'empty_test',
        'value': 'Value',
      };

      final belief = CrystallizedBelief.fromJson(json);
      expect(belief.keywords, isEmpty);
    });

    test('parses ConsolidationReport with comma-separated keywords in beliefs', () {
      final reportJson = {
        'id': 'dream-1727581234567',
        'channel_id': 'chan-product-launch',
        'pruned_messages': 7,
        'distilled_facts': [
          'ADC auth is mandatory for Vertex AI Gemini 3.8 calls in davenport-boutique',
          'BigQuery vector indexing uses COSINE distance with ML.DISTANCE',
        ],
        'insight_summary': 'Consolidation cycle completed successfully.',
        'completed_at': '2026-09-28T22:20:00.000Z',
        'crystallized_beliefs': [
          {
            'key': 'deployment_stack',
            'value': 'Cloud Run & Vertex AI Gemini 3.8 Flash in davenport-boutique',
            'category': 'Infrastructure',
            'confidence': 0.98,
            'keywords': 'Cloud Run, Terraform, Gemini 3.8 Flash, orchestration, deployment',
            'statement': 'The production deployment stack runs on Cloud Run.',
          },
        ],
        'dream_prompt_used': '### REM DREAM SYNTHESIS PROMPT ###',
        'intent_trajectory': 'Inception -> Design -> Hardening -> GA Sign-off',
      };

      final report = ConsolidationReport.fromJson(reportJson);
      expect(report.id, equals('dream-1727581234567'));
      expect(report.prunedMessages, equals(7));
      expect(report.distilledFacts.length, equals(2));
      expect(report.crystallizedBeliefs.length, equals(1));
      expect(report.crystallizedBeliefs.first.keywords, equals([
        'Cloud Run',
        'Terraform',
        'Gemini 3.8 Flash',
        'orchestration',
        'deployment',
      ]));
    });

    test('parses ConsolidationReport with Map<dynamic, dynamic> and string distilled_facts', () {
      final Map<dynamic, dynamic> rawMap = {
        'id': 'dream-999',
        'channel_id': 'chan-test',
        'pruned_messages': 3,
        'distilled_facts': 'Fact 1\nFact 2',
        'insight_summary': 'Summary',
        'crystallized_beliefs': [
          <dynamic, dynamic>{
            'key': 'test_key',
            'value': 'test_val',
            'keywords': 'tag1, tag2',
          }
        ],
      };

      final report = ConsolidationReport.fromJson(Map<String, dynamic>.from(rawMap));
      expect(report.distilledFacts, equals(['Fact 1', 'Fact 2']));
      expect(report.crystallizedBeliefs.first.keywords, equals(['tag1', 'tag2']));
    });

    test('parses generated_at in CrystallizedBelief.fromJson and serializes in toJson', () {
      final json = {
        'key': 'cloud_run_spec',
        'value': 'Production on Cloud Run with Gemini 3.8',
        'category': 'Infrastructure',
        'confidence': 0.98,
        'keywords': 'Cloud Run, Terraform',
        'statement': 'Production stack runs on Cloud Run.',
        'generated_at': '2026-09-29T08:30:00.000Z',
      };

      final belief = CrystallizedBelief.fromJson(json);
      expect(belief.generatedAt, isNotNull);
      expect(belief.generatedAt!.toIso8601String(), equals('2026-09-29T08:30:00.000Z'));

      final serialized = belief.toJson();
      expect(serialized['generated_at'], equals('2026-09-29T08:30:00.000Z'));
    });

    test('parses generation_time as fallback in CrystallizedBelief.fromJson', () {
      final json = {
        'key': 'sec_adc',
        'value': 'ADC Auth',
        'category': 'Security',
        'confidence': 0.99,
        'keywords': 'ADC',
        'statement': 'ADC is mandatory.',
        'generation_time': '2026-09-29T08:45:00.000Z',
      };

      final belief = CrystallizedBelief.fromJson(json);
      expect(belief.generatedAt, isNotNull);
      expect(belief.generatedAt!.toIso8601String(), equals('2026-09-29T08:45:00.000Z'));
    });

    test('falls back to null generatedAt when time fields are absent', () {
      final json = {
        'key': 'sec_adc',
        'value': 'ADC Auth',
      };

      final belief = CrystallizedBelief.fromJson(json);
      expect(belief.generatedAt, isNull);
      expect(belief.toJson()['generated_at'], isNull);
    });

    test('ConsolidationReport.fromJson assigns report.completedAt when belief generatedAt is null', () {
      final reportJson = {
        'id': 'dream-fallback-time',
        'channel_id': 'chan-mesh',
        'pruned_messages': 5,
        'distilled_facts': ['Durable fact 1'],
        'insight_summary': 'Summary',
        'completed_at': '2026-09-29T09:15:00.000Z',
        'crystallized_beliefs': [
          {
            'key': 'belief_without_timestamp',
            'value': 'Distilled invariant',
            'category': 'Security',
            'confidence': 0.97,
            'statement': 'Durable security invariant.',
          },
        ],
      };

      final report = ConsolidationReport.fromJson(reportJson);
      expect(report.crystallizedBeliefs.length, equals(1));
      expect(report.crystallizedBeliefs.first.generatedAt, isNotNull);
      expect(report.crystallizedBeliefs.first.generatedAt, equals(report.completedAt));
      expect(report.crystallizedBeliefs.first.generatedAt!.toIso8601String(), equals('2026-09-29T09:15:00.000Z'));
    });

    test('ConsolidationReport.fromJson preserves belief generatedAt when explicitly provided', () {
      final reportJson = {
        'id': 'dream-explicit-time',
        'channel_id': 'chan-mesh',
        'pruned_messages': 2,
        'distilled_facts': ['Durable fact 2'],
        'insight_summary': 'Summary',
        'completed_at': '2026-09-29T10:00:00.000Z',
        'crystallized_beliefs': [
          {
            'key': 'belief_with_timestamp',
            'value': 'Distilled invariant',
            'category': 'Database',
            'confidence': 0.99,
            'statement': 'BigQuery cosine distance indexing.',
            'generated_at': '2026-09-29T09:50:00.000Z',
          },
        ],
      };

      final report = ConsolidationReport.fromJson(reportJson);
      expect(report.crystallizedBeliefs.length, equals(1));
      expect(report.crystallizedBeliefs.first.generatedAt, isNotNull);
      expect(report.crystallizedBeliefs.first.generatedAt!.toIso8601String(), equals('2026-09-29T09:50:00.000Z'));
    });
  });

  group('ConsolidationReport Upserting Tests', () {
    test('inserts new report at index 0 when ID does not exist', () {
      final existingReport = ConsolidationReport(
        id: 'dream-101',
        channelId: 'chan-product-launch',
        prunedMessages: 4,
        distilledFacts: ['Fact 1'],
        insightSummary: 'First consolidation',
        completedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final reports = <ConsolidationReport>[existingReport];

      final newReport = ConsolidationReport(
        id: 'dream-102',
        channelId: 'chan-product-launch',
        prunedMessages: 8,
        distilledFacts: ['Fact 2'],
        insightSummary: 'Second consolidation',
        completedAt: DateTime.now(),
      );

      upsertConsolidationReport(reports, newReport);

      expect(reports.length, equals(2));
      expect(reports.first.id, equals('dream-102'));
      expect(reports[1].id, equals('dream-101'));
    });

    test('updates existing report in place without duplicating', () {
      final reportV1 = ConsolidationReport(
        id: 'dream-race-1',
        channelId: 'chan-product-launch',
        prunedMessages: 5,
        distilledFacts: ['Incomplete fact'],
        insightSummary: 'Initial broadcast report',
        completedAt: DateTime.now(),
      );
      final reportOther = ConsolidationReport(
        id: 'dream-other',
        channelId: 'chan-product-launch',
        prunedMessages: 2,
        distilledFacts: ['Other fact'],
        insightSummary: 'Other report',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final reports = <ConsolidationReport>[reportV1, reportOther];

      final reportV2 = ConsolidationReport(
        id: 'dream-race-1',
        channelId: 'chan-product-launch',
        prunedMessages: 12,
        distilledFacts: ['Complete fact', 'Durable architecture'],
        insightSummary: 'Updated HTTP report response',
        completedAt: DateTime.now(),
      );

      upsertConsolidationReport(reports, reportV2);

      expect(reports.length, equals(2));
      expect(reports[0].id, equals('dream-race-1'));
      expect(reports[0].prunedMessages, equals(12));
      expect(reports[0].insightSummary, equals('Updated HTTP report response'));
      expect(reports[0].distilledFacts.length, equals(2));
      expect(reports[1].id, equals('dream-other'));
    });

    test('prevents race duplicate when WebSocket and HTTP return same report', () {
      final reports = <ConsolidationReport>[];
      final report = ConsolidationReport(
        id: 'dream-shared-id',
        channelId: 'chan-product-launch',
        prunedMessages: 7,
        distilledFacts: ['Consolidated turn data'],
        insightSummary: 'Race test summary',
        completedAt: DateTime.now(),
      );

      // 1. Simulating WebSocket broadcast onConsolidationCompleted arrival
      upsertConsolidationReport(reports, report);
      expect(reports.length, equals(1));

      // 2. Simulating HTTP POST _onTriggerDreaming response arrival for the same report ID
      upsertConsolidationReport(reports, report);
      expect(reports.length, equals(1));
      expect(reports.first.id, equals('dream-shared-id'));
    });

    test('deduplicates report history using putIfAbsent matching _buildDreamingTab', () {
      final r1 = ConsolidationReport(
        id: 'dream-001',
        channelId: 'chan-1',
        prunedMessages: 3,
        distilledFacts: [],
        insightSummary: 'Run 1',
        completedAt: DateTime.now(),
      );
      final r2 = ConsolidationReport(
        id: 'dream-002',
        channelId: 'chan-1',
        prunedMessages: 6,
        distilledFacts: [],
        insightSummary: 'Run 2',
        completedAt: DateTime.now(),
      );
      final r1Dup = ConsolidationReport(
        id: 'dream-001',
        channelId: 'chan-1',
        prunedMessages: 3,
        distilledFacts: [],
        insightSummary: 'Duplicate Run 1',
        completedAt: DateTime.now(),
      );

      final reports = [r1, r2, r1Dup];
      final uniqueReports = <String, ConsolidationReport>{};
      for (final r in reports) {
        uniqueReports.putIfAbsent(r.id, () => r);
      }

      final reportList = uniqueReports.values.toList();
      expect(reportList.length, equals(2));
      expect(reportList.map((r) => r.id).toList(), equals(['dream-001', 'dream-002']));
    });
  });

  group('CrystallizedBelief Deduplication Tests', () {
    test('deduplicates beliefs by normalized key (lowercase and trimmed)', () {
      final b1 = CrystallizedBelief(
        key: 'cloud_run_stack',
        value: 'Cloud Run V1',
        category: 'Infrastructure',
        confidence: 0.90,
        keywords: ['Cloud Run'],
        statement: 'Runs on Cloud Run.',
      );
      final b2 = CrystallizedBelief(
        key: '  CLOUD_RUN_STACK  ',
        value: 'Cloud Run V2 with BigQuery',
        category: 'Infrastructure',
        confidence: 0.98,
        keywords: ['Cloud Run', 'BigQuery'],
        statement: 'Runs on Cloud Run V2.',
      );

      final deduplicated = AgentMeshView.deduplicateBeliefs([b1, b2]);
      expect(deduplicated.length, equals(1));
      expect(deduplicated.first.confidence, equals(0.98));
      expect(deduplicated.first.value, equals('Cloud Run V2 with BigQuery'));
    });

    test('prefers higher confidence belief when key already exists', () {
      final lowConfidence = CrystallizedBelief(
        key: 'sec_auth_mode',
        value: 'Basic Auth',
        category: 'Security',
        confidence: 0.70,
        keywords: ['Auth'],
        statement: 'Basic Auth.',
      );
      final highConfidence = CrystallizedBelief(
        key: 'sec_auth_mode',
        value: 'Application Default Credentials (ADC)',
        category: 'Security',
        confidence: 0.99,
        keywords: ['ADC', 'Zero-Trust'],
        statement: 'ADC strictly required.',
      );

      // Low first, then high updates
      final result1 = AgentMeshView.deduplicateBeliefs([lowConfidence, highConfidence]);
      expect(result1.length, equals(1));
      expect(result1.first.value, equals('Application Default Credentials (ADC)'));
      expect(result1.first.confidence, equals(0.99));

      // High first, then low does NOT overwrite
      final result2 = AgentMeshView.deduplicateBeliefs([highConfidence, lowConfidence]);
      expect(result2.length, equals(1));
      expect(result2.first.value, equals('Application Default Credentials (ADC)'));
      expect(result2.first.confidence, equals(0.99));
    });

    test('extractCrystallizedBeliefs prefers belief from more recent consolidation report', () {
      final olderReport = ConsolidationReport(
        id: 'dream-old',
        channelId: 'chan-product-launch',
        prunedMessages: 5,
        distilledFacts: [],
        insightSummary: 'Older consolidation',
        completedAt: DateTime.parse('2026-09-28T10:00:00Z'),
        crystallizedBeliefs: [
          CrystallizedBelief(
            key: 'vector_distance_metric',
            value: 'EUCLIDEAN distance',
            category: 'Database',
            confidence: 0.95,
            keywords: ['Vector', 'Euclidean'],
            statement: 'Uses euclidean distance.',
          ),
        ],
      );

      final newerReport = ConsolidationReport(
        id: 'dream-new',
        channelId: 'chan-product-launch',
        prunedMessages: 8,
        distilledFacts: [],
        insightSummary: 'Newer consolidation',
        completedAt: DateTime.parse('2026-09-28T11:00:00Z'),
        crystallizedBeliefs: [
          CrystallizedBelief(
            key: 'VECTOR_DISTANCE_METRIC',
            value: 'COSINE distance with ML.DISTANCE indexing',
            category: 'Database',
            confidence: 0.92, // Lower confidence, but more recent report!
            keywords: ['Vector', 'Cosine', 'BigQuery'],
            statement: 'Uses cosine distance with ML.DISTANCE indexing.',
          ),
        ],
      );

      // Case A: Passed in chronological order [older, newer]
      final resultA = AgentMeshView.extractCrystallizedBeliefs([olderReport, newerReport]);
      expect(resultA.length, equals(1));
      expect(resultA.first.value, equals('COSINE distance with ML.DISTANCE indexing'));

      // Case B: Passed in reverse chronological order [newer, older]
      final resultB = AgentMeshView.extractCrystallizedBeliefs([newerReport, olderReport]);
      expect(resultB.length, equals(1));
      expect(resultB.first.value, equals('COSINE distance with ML.DISTANCE indexing'));
    });

    test('extractCrystallizedBeliefs falls back to default beliefs when reports have no beliefs', () {
      final emptyReport = ConsolidationReport(
        id: 'dream-empty',
        channelId: 'chan-1',
        prunedMessages: 0,
        distilledFacts: [],
        insightSummary: 'Empty',
        completedAt: DateTime.now(),
        crystallizedBeliefs: [],
      );

      final beliefs = AgentMeshView.extractCrystallizedBeliefs([emptyReport]);
      expect(beliefs.isNotEmpty, isTrue);
      expect(beliefs.length, equals(4));
      expect(beliefs.map((b) => b.key).toSet(), containsAll([
        'sec_auth_adc',
        'db_vector_search',
        'arch_scribe_compaction',
        'infra_cloud_run',
      ]));
    });

    test('extractCrystallizedBeliefs derives and deduplicates beliefs from distilledFacts if beliefs empty', () {
      final report = ConsolidationReport(
        id: 'dream-facts',
        channelId: 'chan-1',
        prunedMessages: 6,
        distilledFacts: [
          'ADC auth is mandatory for Vertex AI Gemini 3.8 calls in davenport-boutique',
          'BigQuery vector indexing uses COSINE distance with ML.DISTANCE',
        ],
        insightSummary: 'Facts consolidation',
        completedAt: DateTime.now(),
        crystallizedBeliefs: [],
      );

      final beliefs = AgentMeshView.extractCrystallizedBeliefs([report]);
      expect(beliefs.length, equals(2));
      expect(beliefs[0].category, equals('Security'));
      expect(beliefs[1].category, equals('Database'));
    });
  });
}
