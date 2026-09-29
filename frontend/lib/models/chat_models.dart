class IntentTag {
  final String label;
  final String type; // "context", "compaction", "scoping", "vector_hit", "permission"
  final String color;
  final String description;

  IntentTag({
    required this.label,
    required this.type,
    required this.color,
    required this.description,
  });

  factory IntentTag.fromJson(Map<String, dynamic> json) {
    return IntentTag(
      label: json['label'] ?? '',
      type: json['type'] ?? 'context',
      color: json['color'] ?? 'sepia',
      description: json['description'] ?? '',
    );
  }
}

class Era {
  final String id;
  final int year;
  final String name;
  final String platform;
  final String memoryConcept;
  final String shortDescription;
  final String description;
  final String iconName;

  Era({
    required this.id,
    required this.year,
    required this.name,
    required this.platform,
    required this.memoryConcept,
    required this.shortDescription,
    required this.description,
    required this.iconName,
  });

  factory Era.fromJson(Map<String, dynamic> json) {
    return Era(
      id: json['id'] ?? '',
      year: json['year'] ?? 1988,
      name: json['name'] ?? '',
      platform: json['platform'] ?? '',
      memoryConcept: json['memory_concept'] ?? '',
      shortDescription: json['short_description'] ?? '',
      description: json['description'] ?? '',
      iconName: json['icon_name'] ?? 'forum',
    );
  }
}

class Channel {
  final String id;
  final String eraId;
  final String name;
  final String topic;
  final String description;
  final String systemPrompt;
  final int retentionHours;
  final int maxBufferTurns;
  final bool isDirectMessage;
  final List<String> allowedRoles;

  Channel({
    required this.id,
    this.eraId = '',
    required this.name,
    required this.topic,
    required this.description,
    required this.systemPrompt,
    required this.retentionHours,
    this.maxBufferTurns = 0,
    this.isDirectMessage = false,
    this.allowedRoles = const [],
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    var rawRoles = json['allowed_roles'];
    List<String> roles = [];
    if (rawRoles is List) {
      roles = rawRoles.map((r) => r.toString()).toList();
    } else if (rawRoles is String) {
      roles = rawRoles.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
    }

    return Channel(
      id: json['id'] ?? '',
      eraId: json['era_id'] ?? '',
      name: json['name'] ?? '',
      topic: json['topic'] ?? '',
      description: json['description'] ?? '',
      systemPrompt: json['system_prompt'] ?? '',
      retentionHours: json['retention_hours'] ?? 24,
      maxBufferTurns: json['max_buffer_turns'] ?? 0,
      isDirectMessage: json['is_direct_message'] ?? false,
      allowedRoles: roles,
    );
  }
}

class AgentPresence {
  final String agentId;
  final String agentName;
  final String avatarUrl;
  final String status; // "available", "away", "dnd", "typing"
  final String statusMessage;
  final String currentTask;
  final DateTime lastHeartbeat;

  AgentPresence({
    required this.agentId,
    required this.agentName,
    required this.avatarUrl,
    required this.status,
    required this.statusMessage,
    required this.currentTask,
    required this.lastHeartbeat,
  });

  factory AgentPresence.fromJson(Map<String, dynamic> json) {
    return AgentPresence(
      agentId: json['agent_id'] ?? '',
      agentName: json['agent_name'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      status: json['status'] ?? 'available',
      statusMessage: json['status_message'] ?? '',
      currentTask: json['current_task'] ?? '',
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.tryParse(json['last_heartbeat']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'agent_id': agentId,
        'agent_name': agentName,
        'avatar_url': avatarUrl,
        'status': status,
        'status_message': statusMessage,
        'current_task': currentTask,
        'last_heartbeat': lastHeartbeat.toIso8601String(),
      };
}

class MemoryBuffer {
  final String channelId;
  final int maxTurns;
  final int currentTurns;
  final int evictedCount;
  final Message? lastEvictedMsg;

  MemoryBuffer({
    required this.channelId,
    required this.maxTurns,
    required this.currentTurns,
    required this.evictedCount,
    this.lastEvictedMsg,
  });

  factory MemoryBuffer.fromJson(Map<String, dynamic> json) {
    return MemoryBuffer(
      channelId: json['channel_id'] ?? '',
      maxTurns: json['max_turns'] ?? 0,
      currentTurns: json['current_turns'] ?? 0,
      evictedCount: json['evicted_count'] ?? 0,
      lastEvictedMsg: json['last_evicted_msg'] != null
          ? Message.fromJson(json['last_evicted_msg'])
          : null,
    );
  }
}

class CrystallizedBelief {
  final String key;
  final String value;
  final String category;
  final double confidence;
  final List<String> keywords;
  final String statement;
  final DateTime? generatedAt;

  CrystallizedBelief({
    required this.key,
    required this.value,
    required this.category,
    required this.confidence,
    required this.keywords,
    required this.statement,
    this.generatedAt,
  });

  CrystallizedBelief copyWith({
    String? key,
    String? value,
    String? category,
    double? confidence,
    List<String>? keywords,
    String? statement,
    DateTime? generatedAt,
  }) {
    return CrystallizedBelief(
      key: key ?? this.key,
      value: value ?? this.value,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      keywords: keywords ?? this.keywords,
      statement: statement ?? this.statement,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  factory CrystallizedBelief.fromJson(Map<String, dynamic> json) {
    List<String> kw = [];
    final rawKeywords = json['keywords'];
    if (rawKeywords is List) {
      kw = rawKeywords
          .map((k) => k.toString().trim())
          .where((k) => k.isNotEmpty)
          .toList();
    } else if (rawKeywords is String) {
      kw = rawKeywords
          .split(RegExp(r'[,;]\s*'))
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();
    }

    final rawTime = json['generated_at'] ?? json['generation_time'];
    DateTime? genAt;
    if (rawTime != null) {
      genAt = DateTime.tryParse(rawTime.toString());
    }

    return CrystallizedBelief(
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      category: json['category']?.toString() ?? 'architecture',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      keywords: kw,
      statement: json['statement']?.toString() ?? '',
      generatedAt: genAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'category': category,
        'confidence': confidence,
        'keywords': keywords,
        'statement': statement,
        'generated_at': generatedAt?.toIso8601String(),
      };
}

class ConsolidationReport {
  final String id;
  final String channelId;
  final int prunedMessages;
  final List<String> distilledFacts;
  final String insightSummary;
  final DateTime completedAt;
  final List<CrystallizedBelief> crystallizedBeliefs;
  final String? dreamPromptUsed;
  final String? intentTrajectory;

  ConsolidationReport({
    required this.id,
    required this.channelId,
    required this.prunedMessages,
    required this.distilledFacts,
    required this.insightSummary,
    required this.completedAt,
    this.crystallizedBeliefs = const [],
    this.dreamPromptUsed,
    this.intentTrajectory,
  });

  factory ConsolidationReport.fromJson(Map<String, dynamic> json) {
    List<String> facts = [];
    final rawFacts = json['distilled_facts'];
    if (rawFacts is List) {
      facts = rawFacts.map((f) => f.toString()).toList();
    } else if (rawFacts is String) {
      facts = rawFacts
          .split('\n')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();
    }

    final completedAt = json['completed_at'] != null
        ? DateTime.tryParse(json['completed_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    List<CrystallizedBelief> beliefs = [];
    final rawBeliefs = json['crystallized_beliefs'];
    if (rawBeliefs is List) {
      for (final b in rawBeliefs) {
        if (b is Map) {
          final belief = CrystallizedBelief.fromJson(Map<String, dynamic>.from(b));
          if (belief.generatedAt == null) {
            beliefs.add(belief.copyWith(generatedAt: completedAt));
          } else {
            beliefs.add(belief);
          }
        }
      }
    }

    return ConsolidationReport(
      id: json['id']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? '',
      prunedMessages: (json['pruned_messages'] as num?)?.toInt() ?? 0,
      distilledFacts: facts,
      insightSummary: json['insight_summary']?.toString() ?? '',
      completedAt: completedAt,
      crystallizedBeliefs: beliefs,
      dreamPromptUsed: json['dream_prompt_used']?.toString(),
      intentTrajectory: json['intent_trajectory']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel_id': channelId,
        'pruned_messages': prunedMessages,
        'distilled_facts': distilledFacts,
        'insight_summary': insightSummary,
        'completed_at': completedAt.toIso8601String(),
        'crystallized_beliefs': crystallizedBeliefs.map((b) => b.toJson()).toList(),
        'dream_prompt_used': dreamPromptUsed,
        'intent_trajectory': intentTrajectory,
      };
}

/// Upserts a [ConsolidationReport] into a list of reports.
/// If a report with [report.id] already exists, it is updated in place.
/// Otherwise, it is inserted at index 0.
void upsertConsolidationReport(List<ConsolidationReport> reports, ConsolidationReport report) {
  final idx = reports.indexWhere((r) => r.id == report.id);
  if (idx >= 0) {
    reports[idx] = report;
  } else {
    reports.insert(0, report);
  }
}

class PrivateScratchpad {
  final String agentId;
  final String channelId;
  final List<String> innerThoughts;
  final String draftPlan;
  final List<String> toolTraces;
  final DateTime updatedAt;

  PrivateScratchpad({
    required this.agentId,
    required this.channelId,
    required this.innerThoughts,
    required this.draftPlan,
    required this.toolTraces,
    required this.updatedAt,
  });

  factory PrivateScratchpad.fromJson(Map<String, dynamic> json) {
    List<String> thoughts = [];
    final rawThoughts = json['inner_thoughts'];
    if (rawThoughts is List) {
      thoughts = rawThoughts.map((t) => t.toString()).toList();
    } else if (rawThoughts is String) {
      thoughts = rawThoughts.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    List<String> traces = [];
    final rawTraces = json['tool_traces'];
    if (rawTraces is List) {
      traces = rawTraces.map((t) => t.toString()).toList();
    } else if (rawTraces is String) {
      traces = rawTraces.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    return PrivateScratchpad(
      agentId: json['agent_id']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? '',
      innerThoughts: thoughts,
      draftPlan: json['draft_plan']?.toString() ?? '',
      toolTraces: traces,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'agent_id': agentId,
        'channel_id': channelId,
        'inner_thoughts': innerThoughts,
        'draft_plan': draftPlan,
        'tool_traces': toolTraces,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class Message {
  final String id;
  final String channelId;
  final String? threadId;
  final String senderType; // "user", "agent", "system"
  final String senderId;
  final String senderName;
  final String? avatarUrl;
  final String content;
  final int tokenCount;
  final List<IntentTag> intentTags;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.channelId,
    this.threadId,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    this.avatarUrl,
    required this.content,
    required this.tokenCount,
    required this.intentTags,
    this.metadata,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    List<IntentTag> tags = [];
    final rawTags = json['intent_tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is Map) {
          tags.add(IntentTag.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    return Message(
      id: json['id']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? '',
      threadId: json['thread_id']?.toString(),
      senderType: json['sender_type']?.toString() ?? 'user',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      content: json['content']?.toString() ?? '',
      tokenCount: (json['token_count'] as num?)?.toInt() ?? 0,
      intentTags: tags,
      metadata: json['metadata'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class Summary {
  final String id;
  final String channelId;
  final String? threadId;
  final String condensedState;
  final int originalTokens;
  final int compactedTokens;
  final double compressionRatio;
  final DateTime createdAt;

  Summary({
    required this.id,
    required this.channelId,
    this.threadId,
    required this.condensedState,
    required this.originalTokens,
    required this.compactedTokens,
    required this.compressionRatio,
    required this.createdAt,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      id: json['id'] ?? '',
      channelId: json['channel_id'] ?? '',
      threadId: json['thread_id'],
      condensedState: json['condensed_state'] ?? '',
      originalTokens: json['original_tokens'] ?? 0,
      compactedTokens: json['compacted_tokens'] ?? 0,
      compressionRatio: (json['compression_ratio'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PacingMode {
  final bool paused;
  final int intervalSeconds;

  PacingMode({required this.paused, required this.intervalSeconds});

  factory PacingMode.fromJson(Map<String, dynamic> json) {
    return PacingMode(
      paused: json['paused'] ?? false,
      intervalSeconds: json['interval_seconds'] ?? 8,
    );
  }

  Map<String, dynamic> toJson() => {
        'paused': paused,
        'interval_seconds': intervalSeconds,
      };
}
