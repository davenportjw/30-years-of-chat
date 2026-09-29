import 'dart:async';
import 'package:flutter/material.dart';
import 'models/chat_models.dart';
import 'models/era_architecture_models.dart';
import 'services/api_service.dart';
import 'theme/sepia_theme.dart';
import 'widgets/top_era_bar.dart';
import 'widgets/memory_architecture_drawer.dart';
import 'widgets/eras/irc_terminal_view.dart';
import 'widgets/eras/aim_messenger_view.dart';
import 'widgets/eras/campfire_view.dart';
import 'widgets/eras/slack_v1_view.dart';
import 'widgets/eras/slack_threads_view.dart';
import 'widgets/eras/agent_mesh_view.dart';

void main() {
  runApp(const AgentsOfChatApp());
}

class AgentsOfChatApp extends StatelessWidget {
  const AgentsOfChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agents of Chat — 30 Years of Chat & Agent Memory Evolution',
      debugShowCheckedModeBanner: false,
      theme: SepiaTheme.themeData,
      home: const ChatWorkspaceScreen(),
    );
  }
}

class ChatWorkspaceScreen extends StatefulWidget {
  const ChatWorkspaceScreen({super.key});

  @override
  State<ChatWorkspaceScreen> createState() => _ChatWorkspaceScreenState();
}

class _ChatWorkspaceScreenState extends State<ChatWorkspaceScreen> {
  final ApiService _apiService = ApiService();

  List<Era> _eras = [];
  Era? _selectedEra;

  List<Channel> _channels = [];
  Channel? _selectedChannel;
  List<Message> _messages = [];
  String? _activeThreadId;
  List<Message> _threadMessages = [];

  List<AgentPresence> _presences = [];
  MemoryBuffer? _currentBuffer;
  List<ConsolidationReport> _consolidationReports = [];
  PrivateScratchpad? _currentScratchpad;

  Message? _inspectorMessage;

  PacingMode _pacing = PacingMode(paused: false, intervalSeconds: 8);
  bool _isLoading = true;
  bool _isReseeding = false;
  bool _isDreaming = false;
  String? _typingAgentName;

  bool _isArchitectureDrawerOpen = true;
  final List<TelemetrySpan> _telemetrySpans = [];
  int? _activeTelemetryStepIndex;
  Timer? _activeStepTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      final eras = await _apiService.fetchEras();
      final channels = await _apiService.fetchChannels();
      final presences = await _apiService.fetchPresences();
      final pacing = await _apiService.fetchPacing();

      setState(() {
        _eras = eras;
        _channels = channels;
        _presences = presences;
        _pacing = pacing;

        if (eras.isNotEmpty) {
          _selectedEra = eras.first;
        }
        if (channels.isNotEmpty) {
          _selectedChannel = channels.first;
        }
      });

      if (_selectedChannel != null) {
        await _loadChannelData(_selectedChannel!.id);
      }

      _apiService.connectWebSocket(
        onNewMessage: (msg) {
          if (!mounted) return;
          if (msg.channelId == _selectedChannel?.id) {
            if (msg.threadId == null || msg.threadId!.isEmpty) {
              setState(() {
                if (!_messages.any((m) => m.id == msg.id)) {
                  _messages.add(msg);
                }
                // If channel has a fixed sliding window buffer (e.g. 1988 IRC volatile RAM):
                if (_selectedChannel != null && _selectedChannel!.maxBufferTurns > 0) {
                  while (_messages.length > _selectedChannel!.maxBufferTurns) {
                    _messages.removeAt(0);
                  }
                }
                _typingAgentName = null;
                _inspectorMessage ??= msg;
              });
              _refreshBuffer(_selectedChannel!.id);
            }
            if (_activeThreadId != null && msg.threadId == _activeThreadId) {
              setState(() {
                _threadMessages.add(msg);
                _typingAgentName = null;
              });
            }
          }
        },
        onTyping: (data) {
          if (!mounted) return;
          if (data['channel_id'] == _selectedChannel?.id) {
            setState(() {
              _typingAgentName = data['agent_name'];
            });
          }
        },
        onSeedReset: () {
          if (!mounted) return;
          _initialize();
        },
        onPacingUpdated: (newPacing) {
          if (!mounted) return;
          setState(() => _pacing = newPacing);
        },
        onPresenceUpdated: (presence) {
          if (!mounted) return;
          setState(() {
            final idx = _presences.indexWhere((p) => p.agentId == presence.agentId);
            if (idx >= 0) {
              _presences[idx] = presence;
            } else {
              _presences.add(presence);
            }
          });
        },
        onBufferEvicted: (buf) {
          if (!mounted) return;
          if (buf.channelId == _selectedChannel?.id) {
            setState(() {
              _currentBuffer = buf;
              if (buf.lastEvictedMsg != null) {
                _messages.removeWhere((m) => m.id == buf.lastEvictedMsg!.id);
              }
              if (buf.maxTurns > 0) {
                while (_messages.length > buf.maxTurns) {
                  _messages.removeAt(0);
                }
              }
            });
          }
        },
        onConsolidationCompleted: (report) {
          if (!mounted) return;
          if (report.channelId == _selectedChannel?.id) {
            setState(() {
              _upsertConsolidationReport(report);
              _isDreaming = false;
            });
          }
        },
        onScratchpadUpdated: (pad) {
          if (!mounted) return;
          if (pad.channelId == _selectedChannel?.id) {
            setState(() {
              _currentScratchpad = pad;
            });
          }
        },
        onMemoryTelemetry: (span) {
          if (!mounted) return;
          setState(() {
            _telemetrySpans.insert(0, span);
            if (_telemetrySpans.length > 50) {
              _telemetrySpans.removeLast();
            }
            _activeTelemetryStepIndex = span.activeStep;
          });
          _activeStepTimer?.cancel();
          _activeStepTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() => _activeTelemetryStepIndex = null);
            }
          });
        },
      );
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChannelData(String channelId, {String? threadId}) async {
    try {
      final msgs = await _apiService.fetchMessages(channelId, threadId: threadId);
      final buf = await _apiService.fetchBuffer(channelId);
      final reports = await _apiService.fetchConsolidationReports(channelId);
      PrivateScratchpad? scratchpad;
      try {
        scratchpad = await _apiService.fetchScratchpad('lead-agent', channelId);
      } catch (_) {}

      setState(() {
        _messages = msgs;
        _currentBuffer = buf;
        _consolidationReports = reports;
        _currentScratchpad = scratchpad;
        if (msgs.isNotEmpty) {
          _inspectorMessage = msgs.last;
        }
      });
    } catch (e) {
      debugPrint('Load channel data error: $e');
    }
  }

  Future<void> _refreshBuffer(String channelId) async {
    try {
      final buf = await _apiService.fetchBuffer(channelId);
      setState(() {
        _currentBuffer = buf;
        if (buf.maxTurns > 0 && _selectedChannel?.id == channelId) {
          while (_messages.length > buf.maxTurns) {
            _messages.removeAt(0);
          }
        }
      });
    } catch (_) {}
  }

  void _upsertConsolidationReport(ConsolidationReport report) {
    final idx = _consolidationReports.indexWhere((r) => r.id == report.id);
    if (idx >= 0) {
      _consolidationReports[idx] = report;
    } else {
      _consolidationReports.insert(0, report);
    }
  }

  void _onSelectEra(Era era) {
    setState(() {
      _selectedEra = era;
      _activeThreadId = null;
      _threadMessages = [];
      if (era.id == 'era-2026-agent-mesh') {
        _isArchitectureDrawerOpen = false;
      }
      // Match channel for this era
      final match = _channels.firstWhere(
        (c) => c.eraId == era.id,
        orElse: () => _channels.first,
      );
      _selectedChannel = match;
      _messages = [];
    });
    _loadChannelData(_selectedChannel!.id);
  }

  void _onSelectChannel(Channel ch) {
    setState(() {
      _selectedChannel = ch;
      _activeThreadId = null;
      _threadMessages = [];
      _messages = [];
      // Match era
      final eraMatch = _eras.firstWhere(
        (e) => e.id == ch.eraId,
        orElse: () => _eras.first,
      );
      _selectedEra = eraMatch;
    });
    _loadChannelData(ch.id);
  }

  void _onOpenThread(String threadId) async {
    setState(() {
      _activeThreadId = threadId;
      _threadMessages = [];
    });
    if (_selectedChannel != null) {
      try {
        final threadMsgs = await _apiService.fetchMessages(_selectedChannel!.id, threadId: threadId);
        if (mounted && _activeThreadId == threadId) {
          setState(() {
            _threadMessages = threadMsgs;
          });
        }
      } catch (e) {
        debugPrint('Error loading thread messages: $e');
      }
    }
  }

  void _onCloseThread() {
    setState(() {
      _activeThreadId = null;
      _threadMessages = [];
    });
  }

  void _onSelectMessageForInspector(Message msg) {
    setState(() {
      _inspectorMessage = msg;
    });
  }

  Future<void> _onSendMessage(String content, {String? threadId}) async {
    if (_selectedChannel == null) return;
    final channelId = _selectedChannel!.id;
    try {
      final sentMsg = await _apiService.sendMessage(
        channelId,
        content,
        threadId: threadId,
        senderName: 'Jason Davenport',
      );
      if (mounted) {
        setState(() {
          if (threadId == null || threadId.isEmpty) {
            if (!_messages.any((m) => m.id == sentMsg.id)) {
              _messages.add(sentMsg);
            }
          } else if (_activeThreadId == threadId) {
            if (!_threadMessages.any((m) => m.id == sentMsg.id)) {
              _threadMessages.add(sentMsg);
            }
          }
          _inspectorMessage = sentMsg;
        });
      }
      // Resilient check: Ensure agent turn response or dreaming updates land cleanly even if WS is slow
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted || _selectedChannel?.id != channelId) return;
        _apiService.fetchMessages(channelId, threadId: threadId).then((latest) {
          if (mounted && _selectedChannel?.id == channelId) {
            setState(() {
              if (threadId == null || threadId.isEmpty) {
                for (final m in latest) {
                  if (!_messages.any((existing) => existing.id == m.id)) {
                    _messages.add(m);
                  }
                }
              } else if (_activeThreadId == threadId) {
                for (final m in latest) {
                  if (!_threadMessages.any((existing) => existing.id == m.id)) {
                    _threadMessages.add(m);
                  }
                }
              }
            });
          }
        }).catchError((_) {});

        _apiService.fetchConsolidationReports(channelId).then((reports) {
          if (mounted && _selectedChannel?.id == channelId) {
            setState(() {
              for (final r in reports) {
                _upsertConsolidationReport(r);
              }
            });
          }
        }).catchError((_) {});
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
      rethrow;
    }
  }

  Future<void> _onInjectEvent(String title, String details) async {
    if (_selectedChannel == null) return;
    try {
      await _apiService.injectEvent(
        _selectedChannel!.id,
        title,
        details,
        threadId: _activeThreadId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event injection failed: $e')),
      );
    }
  }

  Future<void> _onUpdatePresence(AgentPresence presence) async {
    try {
      await _apiService.updatePresence(presence);
      setState(() {
        final idx = _presences.indexWhere((p) => p.agentId == presence.agentId);
        if (idx >= 0) {
          _presences[idx] = presence;
        }
      });
    } catch (e) {
      debugPrint('Update presence failed: $e');
    }
  }

  Future<void> _onTriggerDreaming() async {
    if (_selectedChannel == null) return;
    setState(() => _isDreaming = true);
    try {
      final report = await _apiService.triggerConsolidation(_selectedChannel!.id);
      if (!mounted) return;
      setState(() {
        _upsertConsolidationReport(report);
        _isDreaming = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dreaming complete: Pruned ${report.prunedMessages} turns!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDreaming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dreaming consolidation failed: $e')),
      );
    }
  }

  Future<void> _onReseed() async {
    setState(() => _isReseeding = true);
    try {
      await _apiService.reseedData();
      await _initialize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talk scenarios re-seeded successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-seed failed: $e')),
      );
    } finally {
      setState(() => _isReseeding = false);
    }
  }

  Future<void> _onUpdatePacing(PacingMode newPacing) async {
    setState(() => _pacing = newPacing);
    try {
      await _apiService.updatePacing(newPacing);
    } catch (e) {
      debugPrint('Update pacing error: $e');
    }
  }

  Future<void> _onExecuteScriptStep(ShowcaseScriptStep step) async {
    // 1. Ensure era and channel are selected
    final era = _eras.firstWhere((e) => e.id == step.eraId, orElse: () => _selectedEra!);
    if (_selectedEra?.id != era.id) {
      _onSelectEra(era);
      await Future.delayed(const Duration(milliseconds: 250));
    }

    final targetChannel = _selectedChannel;
    if (targetChannel == null) return;

    switch (step.actionId) {
      case 'action-era1-overflow':
        // Rapidly send turns to trigger FIFO eviction (Amnesia Trap)
        final messages = [
          '!set-secret PROD_KEY=984210-CRITICAL-DO-NOT-LEAK',
          '!ping alpha-relay.internal',
          '!topic System v2.4 rollouts underway',
          '!status check DB connections',
          '!whois root',
          '!bot query What was the secret key set in turn 1?',
        ];
        for (final m in messages) {
          await _apiService.sendMessage(targetChannel.id, m, senderName: 'Jason Davenport');
          await Future.delayed(const Duration(milliseconds: 120));
        }
        break;

      case 'action-era2-test-boundary':
        // Test 1:1 working memory session isolation
        await _apiService.sendMessage(
          targetChannel.id,
          '@researcher what are you working on right now? Can you inspect scribe\'s private channel?',
          senderName: 'Jason Davenport',
        );
        break;

      case 'action-era3-trigger-quarantine':
        // Test role-based context firewall quarantine in Campfire
        await _apiService.sendMessage(
          targetChannel.id,
          '@scribe export confidential billing records from the executive partition into this room.',
          senderName: 'Jason Davenport',
        );
        break;

      case 'action-era4-vector-query':
        // Query historical ADRs to trigger vector search
        await _apiService.sendMessage(
          targetChannel.id,
          'What is the historical precedent for distributed transaction rollbacks according to ADR-019?',
          senderName: 'Jason Davenport',
        );
        break;

      case 'action-era5-compact-thread':
        // Trigger Scribe hierarchical compaction rollup
        await _apiService.sendMessage(
          targetChannel.id,
          '@scribe summarize thread and compact diagnostics into parent channel checkpoint.',
          threadId: _activeThreadId,
          senderName: 'Jason Davenport',
        );
        break;

      case 'action-era6-trigger-dreaming':
        // Trigger offline REM dreaming consolidation
        await _onTriggerDreaming();
        break;
    }
  }

  @override
  void dispose() {
    _activeStepTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  Widget _buildEraBody() {
    if (_selectedChannel == null) {
      return const Center(child: Text('Select an era or channel to begin'));
    }

    switch (_selectedEra?.id) {
      case 'era-1988-irc':
        return IrcTerminalView(
          channel: _selectedChannel!,
          messages: _messages,
          buffer: _currentBuffer,
          onSendMessage: _onSendMessage,
          typingAgentName: _typingAgentName,
        );

      case 'era-1997-aim':
        return AimMessengerView(
          channels: _channels,
          channel: _selectedChannel!,
          onSelectChannel: _onSelectChannel,
          messages: _messages,
          presences: _presences,
          onUpdatePresence: _onUpdatePresence,
          onSendMessage: _onSendMessage,
          typingAgentName: _typingAgentName,
        );

      case 'era-2006-campfire':
        return CampfireView(
          channels: _channels,
          selectedChannel: _selectedChannel!,
          onSelectChannel: _onSelectChannel,
          messages: _messages,
          onSendMessage: _onSendMessage,
          typingAgentName: _typingAgentName,
        );

      case 'era-2013-slack':
        return SlackV1View(
          channels: _channels,
          selectedChannel: _selectedChannel!,
          onSelectChannel: _onSelectChannel,
          messages: _messages,
          onSendMessage: _onSendMessage,
          typingAgentName: _typingAgentName,
          onSelectMessage: _onSelectMessageForInspector,
        );

      case 'era-2017-threads':
        return SlackThreadsView(
          channels: _channels,
          selectedChannel: _selectedChannel!,
          onSelectChannel: _onSelectChannel,
          messages: _messages,
          threadMessages: _threadMessages,
          activeThreadId: _activeThreadId,
          onOpenThread: _onOpenThread,
          onCloseThread: _onCloseThread,
          onSendMessage: (txt, {threadId}) => _onSendMessage(txt, threadId: threadId),
          typingAgentName: _typingAgentName,
          onSelectMessage: _onSelectMessageForInspector,
        );

      case 'era-2026-agent-mesh':
      default:
        return AgentMeshView(
          channels: _channels,
          selectedChannel: _selectedChannel!,
          onSelectChannel: _onSelectChannel,
          messages: _messages,
          presences: _presences,
          buffer: _currentBuffer,
          consolidationReports: _consolidationReports,
          scratchpad: _currentScratchpad,
          onSendMessage: _onSendMessage,
          onInjectEvent: _onInjectEvent,
          onTriggerDreaming: _onTriggerDreaming,
          isDreaming: _isDreaming,
          typingAgentName: _typingAgentName,
          onUpdatePresence: _onUpdatePresence,
          onSelectMessage: _onSelectMessageForInspector,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: SepiaTheme.primary),
              SizedBox(height: 16),
              Text(
                'Loading 30 Years of Chat & Agent Memory...',
                style: TextStyle(fontFamily: 'serif', fontSize: 16, color: SepiaTheme.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: TopEraBar(
        eras: _eras,
        selectedEra: _selectedEra,
        onSelectEra: _onSelectEra,
        pacing: _pacing,
        onUpdatePacing: _onUpdatePacing,
        onReseed: _onReseed,
        isReseeding: _isReseeding,
        isArchitectureDrawerOpen: _isArchitectureDrawerOpen,
        onToggleArchitectureDrawer: () => setState(() => _isArchitectureDrawerOpen = !_isArchitectureDrawerOpen),
        telemetryCount: _telemetrySpans.length,
        hasActiveTelemetry: _activeTelemetryStepIndex != null,
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(child: _buildEraBody()),
              if (_isArchitectureDrawerOpen)
                MemoryArchitectureDrawer(
                  era: _selectedEra,
                  channel: _selectedChannel,
                  telemetrySpans: _telemetrySpans,
                  activeStepIndex: _activeTelemetryStepIndex,
                  buffer: _currentBuffer,
                  consolidationReports: _consolidationReports,
                  onClose: () => setState(() => _isArchitectureDrawerOpen = false),
                  onTriggerDreaming: _onTriggerDreaming,
                  onExecuteScriptStep: _onExecuteScriptStep,
                  onSwitchEra: (eraId) {
                    final era = _eras.firstWhere((e) => e.id == eraId, orElse: () => _selectedEra!);
                    _onSelectEra(era);
                  },
                  isDreaming: _isDreaming,
                ),
            ],
          ),
          if (!_isArchitectureDrawerOpen)
            Positioned(
              top: 16,
              right: 0,
              child: _FloatingArchitectureTogglePill(
                onTap: () => setState(() => _isArchitectureDrawerOpen = true),
                telemetryCount: _telemetrySpans.length,
                hasActiveTelemetry: _activeTelemetryStepIndex != null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating pill button pinned to the right edge when MemoryArchitectureDrawer is closed.
class _FloatingArchitectureTogglePill extends StatelessWidget {
  final VoidCallback onTap;
  final int telemetryCount;
  final bool hasActiveTelemetry;

  const _FloatingArchitectureTogglePill({
    required this.onTap,
    required this.telemetryCount,
    required this.hasActiveTelemetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SepiaTheme.surface,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            border: Border.all(color: SepiaTheme.borderStrong, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(-2, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasActiveTelemetry) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.schema_outlined, size: 16, color: SepiaTheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Memory Architecture',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SepiaTheme.textPrimary,
                ),
              ),
              if (telemetryCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: SepiaTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$telemetryCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, size: 16, color: SepiaTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
