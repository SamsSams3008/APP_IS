import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Indicador de carga tipo ola con barras verticales subiendo y bajando.
class WaveLoadingIndicator extends StatefulWidget {
  const WaveLoadingIndicator({
    super.key,
    this.barCount = 5,
    this.barWidth = 4,
    this.barSpacing = 6,
    this.height = 24,
    this.color,
    this.duration = const Duration(milliseconds: 600),
  });

  final int barCount;
  final double barWidth;
  final double barSpacing;
  final double height;
  final Color? color;
  final Duration duration;

  @override
  State<WaveLoadingIndicator> createState() => _WaveLoadingIndicatorState();
}

class _WaveLoadingIndicatorState extends State<WaveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.barCount * widget.barWidth +
          (widget.barCount - 1) * widget.barSpacing,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (i) {
          return Padding(
            padding: EdgeInsets.only(
              right: i < widget.barCount - 1 ? widget.barSpacing : 0,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = (_controller.value + i / widget.barCount) % 1.0;
                final h = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: widget.barWidth,
                    height: widget.height * h,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(widget.barWidth / 2),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
