import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../core/controllers/teleprompter_controller.dart' hide AsrFrame;
import '../../core/models/app_models.dart';
import '../../core/services/asr_service.dart';
import '../../core/services/asr_service_base.dart';

class TeleprompterView extends StatefulWidget {
  const TeleprompterView({super.key, required this.controller});

  final TeleprompterController controller;

  @override
  State<TeleprompterView> createState() => _TeleprompterViewState();
}

class _TeleprompterViewState extends State<TeleprompterView> {
  final ScrollController _scrollController = ScrollController();
  final TeleprompterAsrService _asrService = createAsrService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<AsrFrame>? _asrSubscription;
  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _autoTimer;
  DateTime? _lastTick;
  bool _voiceStarted = false;
  bool _autoStarted = false;

  TeleprompterController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncTransport);
    _boot();
  }

  Future<void> _boot() async {
    await controller.initialize();
    _syncTransport();
  }

  @override
  void dispose() {
    controller.removeListener(_syncTransport);
    _autoTimer?.cancel();
    _asrSubscription?.cancel();
    _audioSubscription?.cancel();
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncTransport() async {
    if (!mounted || !controller.loaded) {
      return;
    }

    if (controller.mode == TeleprompterMode.voice && controller.isPlaying) {
      if (!_voiceStarted) {
        await _startVoiceFollow();
      }
    } else if (_voiceStarted) {
      await _stopVoiceFollow();
    }

    if (controller.mode == TeleprompterMode.auto && controller.isPlaying) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }

    _scrollToCurrentLine();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startVoiceFollow() async {
    final active = controller.activeScript;
    if (active == null) {
      return;
    }

    if (!await _audioRecorder.hasPermission()) {
      controller.setPlaying(false);
      return;
    }

    await _asrService.initialize(model: controller.selectedModelPackage);
    await _asrService.start(
      scriptText: controller.parsedActiveScript.plainText,
    );
    _asrSubscription ??= _asrService.frames.listen((frame) {
      controller.consumeAsrFrame(frame.text, isFinal: frame.isFinal);
      if (frame.isFinal && frame.text.isEmpty) {
        _stopAutoScroll();
      }
    });

    final stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioSubscription = stream.listen((data) {
      // pcm16bits is 2 bytes per sample (little-endian or native).
      final byteData = ByteData.sublistView(Uint8List.fromList(data));
      final floatList = Float32List(data.length ~/ 2);
      for (int i = 0; i < floatList.length; i++) {
        final sample = byteData.getInt16(i * 2, Endian.host);
        floatList[i] = sample / 32768.0;
      }
      _asrService.acceptWaveform(floatList, 16000);
    });

    _voiceStarted = true;
  }

  Future<void> _stopVoiceFollow() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    await _asrService.stop();
    await _asrSubscription?.cancel();
    _asrSubscription = null;
    _voiceStarted = false;
  }

  void _startAutoScroll() {
    if (_autoStarted) {
      return;
    }
    _lastTick = DateTime.now();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted ||
          !controller.isPlaying ||
          controller.mode != TeleprompterMode.auto) {
        _stopAutoScroll();
        return;
      }
      final now = DateTime.now();
      final elapsedMs = now.difference(_lastTick ?? now).inMilliseconds;
      _lastTick = now;
      final charsPerSecond = controller.settings.speedWpm / 60.0;
      final advance = (elapsedMs * charsPerSecond / 1000.0).floor();
      if (advance <= 0) {
        return;
      }
      controller.setCurrentIndex(controller.currentCharIndex + advance);
      _scrollToCurrentLine();
    });
    _autoStarted = true;
  }

  void _stopAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _autoStarted = false;
    _lastTick = null;
  }

  void _scrollToCurrentLine() {
    if (!_scrollController.hasClients) {
      return;
    }
    final lines = controller.parsedActiveScript.lines;
    if (lines.isEmpty) {
      return;
    }

    final viewportHeight = _scrollController.position.viewportDimension;
    final rowExtent =
        controller.settings.fontSize * controller.settings.lineHeight + 18;
    final targetOffset =
        (controller.currentLineIndex * rowExtent) -
        viewportHeight * controller.settings.readingLineRatio;
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(clamped.toDouble());
  }

  @override
  void didUpdateWidget(covariant TeleprompterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _initListeners();
    }
  }

  String _parseDuration(num durationOrMap) {
    if (durationOrMap is num) {
      return (durationOrMap / 1000).toStringAsFixed(2);
    } else if (durationOrMap is Map) {
      // Sometimes whispered returns mapping or str
      return durationOrMap.toString();
    }
    return '0.00';
  }

  void _scrollToCenter() {
    if (!mounted) {
      return;
    }
    try {
      if (_scrollController.hasClients &&
          _scrollController.position.hasViewportDimension) {
        _scrollController.jumpTo(
          (_scrollController.position.maxScrollExtent +
                  _scrollController.position.viewportDimension) /
              2,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.currentScript == null) {
      return const Center(child: Text('没有选中的稿件'));
    }

    final TeleprompterState state = widget.controller.state;
    final theme = Theme.of(context);
    final TextStyle textStyle = theme.textTheme.displayMedium!.copyWith(
      fontSize: state.fontSize,
      color: state.fontColor,
      height: 1.5,
    );

    Widget content = Center(
      child: ValueListenableBuilder<double>(
        valueListenable: _voiceVolumeNotifier,
        builder: (context, volume, child) {
          final wordsInfo = _getTimedWords(
            widget.controller.currentScript!.content,
          );

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: state.margin),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    state.backgroundColor,
                    Colors.transparent,
                    Colors.transparent,
                    state.backgroundColor,
                  ],
                  stops: const <double>[0.0, 0.4, 0.6, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstOut,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  controller.settings.paddingX,
                  180,
                  controller.settings.paddingX,
                  220,
                ),
                itemCount: wordsInfo.length,
                itemBuilder: (context, index) {
                  final wordInfo = wordsInfo[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(wordInfo.text, style: textStyle),
                  );
                },
              ),
            ),
          );
        },
      ),
    );

    if (state.isMirrored) {
      content = Transform.scale(
        scaleX: -1,
        alignment: Alignment.center,
        child: content,
      );
    }

    return Card(
      elevation: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF111318), Color(0xFF0A0B0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment(
                    0,
                    controller.settings.readingLineRatio * 2 - 1,
                  ),
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.45),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          activeScript?.title ?? '未选择稿件',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            controller.setPlaying(!controller.isPlaying),
                        icon: Icon(
                          controller.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(controller.isPlaying ? '暂停' : '开始'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('手动'),
                        selected: controller.mode == TeleprompterMode.manual,
                        onSelected: (_) =>
                            controller.setMode(TeleprompterMode.manual),
                      ),
                      ChoiceChip(
                        label: const Text('自动'),
                        selected: controller.mode == TeleprompterMode.auto,
                        onSelected: (_) =>
                            controller.setMode(TeleprompterMode.auto),
                      ),
                      ChoiceChip(
                        label: const Text('语音跟随'),
                        selected: controller.mode == TeleprompterMode.voice,
                        onSelected: (_) =>
                            controller.setMode(TeleprompterMode.voice),
                      ),
                      ActionChip(
                        label: const Text('回到开头'),
                        avatar: const Icon(Icons.replay_rounded, size: 18),
                        onPressed: () {
                          controller.setCurrentIndex(0);
                          _scrollToCurrentLine();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      controller.settings.paddingX,
                      180,
                      controller.settings.paddingX,
                      220,
                    ),
                    itemCount: wordsInfo.length,
                    itemBuilder: (context, index) {
                      final wordInfo = wordsInfo[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(wordInfo.text, style: textStyle),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        controller.mode.name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
