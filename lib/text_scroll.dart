library text_scroll;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class TextScroll extends StatefulWidget {
  const TextScroll(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.textDirection = TextDirection.ltr,
    this.numberOfReps,
    this.delayBefore,
    this.pauseBetween,
    this.mode = TextScrollMode.endless,
    this.velocity = const Velocity(pixelsPerSecond: Offset(80, 0)),
    this.selectable = false,
    this.intervalSpaces,
    this.paddingLeft = 0.0,
  }) : super(key: key);

  final String text;
  final TextAlign? textAlign;
  final TextDirection textDirection;
  final TextStyle? style;
  final int? numberOfReps;
  final Duration? delayBefore;
  final Duration? pauseBetween;
  final TextScrollMode mode;
  final Velocity velocity;
  final bool selectable;
  final int? intervalSpaces;
  final double paddingLeft;

  @override
  State<TextScroll> createState() => _TextScrollState();
}

class _TextScrollState extends State<TextScroll>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  String? _endlessText;
  double? _originalTextWidth;
  bool _running = false;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initScroller();
    });
  }

  @override
  void didUpdateWidget(covariant TextScroll oldWidget) {
    if (widget.text != oldWidget.text) {
      _resetScroller();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
        widget.intervalSpaces == null || widget.mode == TextScrollMode.endless,
        'intervalSpaces is only available in TextScrollMode.endless mode');

    return Directionality(
      textDirection: widget.textDirection,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: EdgeInsets.only(left: widget.paddingLeft),
          child: widget.selectable
              ? SelectableText(
                  _endlessText ?? widget.text,
                  style: widget.style,
                  textAlign: widget.textAlign,
                )
              : Text(
                  _endlessText ?? widget.text,
                  style: widget.style,
                  textAlign: widget.textAlign,
                ),
        ),
      ),
    );
  }

  Future<void> _initScroller() async {
    await _delayBefore();
    if (!_ticker.isActive && mounted) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_available) {
      _ticker.stop();
      return;
    }
    final int? maxReps = widget.numberOfReps;
    if (maxReps != null && _counter >= maxReps) {
      _ticker.stop();
      return;
    }

    if (!_running) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
      _run();
    }
  }

  Future<void> _run() async {
    _running = true;
    final int? maxReps = widget.numberOfReps;
    if (maxReps == null || _counter < maxReps) {
      _counter++;
      switch (widget.mode) {
        case TextScrollMode.bouncing:
          await _animateBouncing();
          break;
        default:
          await _animateEndless();
      }
    }
    _running = false;
  }

  Future<void> _animateEndless() async {
    if (!_available) return;
    final ScrollPosition position = _scrollController.position;
    final bool needsScrolling = position.maxScrollExtent > 0;
    if (!needsScrolling) {
      if (_endlessText != null) setState(() => _endlessText = null);
      return;
    }

    if (_endlessText == null || _originalTextWidth == null) {
      setState(() {
        _originalTextWidth =
            position.maxScrollExtent + position.viewportDimension;
        _endlessText =
            widget.text + _getSpaces(widget.intervalSpaces ?? 1) + widget.text;
      });
      return;
    }

    final double endlessTextWidth =
        position.maxScrollExtent + position.viewportDimension;
    final double singleRoundExtent = endlessTextWidth - _originalTextWidth!;
    final Duration duration = _getDuration(singleRoundExtent);
    if (duration == Duration.zero) return;

    await _animateToPosition(singleRoundExtent, duration);
    if (_available) {
      // ここでチェックを追加
      _scrollController.jumpTo(position.minScrollExtent);
    }

    if (widget.pauseBetween != null) {
      await Future.delayed(widget.pauseBetween!);
    }
  }

  Future<void> _animateBouncing() async {
    final double maxExtent = _scrollController.position.maxScrollExtent;
    final double minExtent = _scrollController.position.minScrollExtent;
    final double extent = maxExtent - minExtent;
    final Duration duration = _getDuration(extent);
    if (duration == Duration.zero) return;

    await _animateToPosition(maxExtent, duration);
    await _animateToPosition(minExtent, duration);
    if (widget.pauseBetween != null) {
      await Future<dynamic>.delayed(widget.pauseBetween!);
    }
  }

  Future<void> _delayBefore() async {
    final Duration? delayBefore = widget.delayBefore;
    if (delayBefore == null) return;
    await Future<dynamic>.delayed(delayBefore);
  }

  Duration _getDuration(double extent) {
    final int milliseconds =
        (extent * 1000 / widget.velocity.pixelsPerSecond.dx).round();
    return Duration(milliseconds: milliseconds);
  }

  void _resetScroller() {
    setState(() {
      _endlessText = null;
      _originalTextWidth = null;
    });
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  String _getSpaces(int number) {
    return List.filled(number, '\u{00A0}').join();
  }

  bool get _available => mounted && _scrollController.hasClients;

  Future<void> _animateToPosition(double position, Duration duration) async {
    if (!_available) return;
    await _scrollController.animateTo(
      position,
      duration: duration,
      curve: Curves.linear,
    );
    if (!_available) return;
  }
}

enum TextScrollMode {
  bouncing,
  endless,
}
