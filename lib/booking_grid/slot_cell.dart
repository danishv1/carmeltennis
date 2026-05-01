import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'tokens.dart';

enum SlotState { free, preview, pending, failed, taken, mine, mineLocked, past }

class SlotCell extends StatefulWidget {
  final SlotState state;
  final String? label; // "·שלי" / "·נעול" / partner name on .taken
  final VoidCallback? onTap;

  const SlotCell({
    super.key,
    required this.state,
    this.label,
    this.onTap,
  });

  @override
  State<SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<SlotCell> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  late final AnimationController _shake;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: BgDurations.pulse,
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: BgDurations.shimmer,
    );
    _shake = AnimationController(
      vsync: this,
      duration: BgDurations.shake,
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant SlotCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncAnimations();
  }

  void _syncAnimations() {
    if (widget.state == SlotState.preview) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
    if (widget.state == SlotState.pending) {
      _shimmer.repeat();
    } else {
      _shimmer.stop();
    }
    if (widget.state == SlotState.failed) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shimmer.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BgTokens.of(context);
    final scheme = _styleFor(t, widget.state);

    Widget content = Container(
      constraints: const BoxConstraints(minHeight: 38),
      decoration: BoxDecoration(
        color: scheme.bg,
        borderRadius: BorderRadius.circular(BgRadii.slot),
        border: scheme.border,
        boxShadow: scheme.shadow,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: _SlotLabel(
        state: widget.state,
        color: scheme.fg,
        label: widget.label,
      ),
    );

    // Hatching overlay on .free
    if (widget.state == SlotState.free) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(BgRadii.slot),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HatchPainter(
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            content,
          ],
        ),
      );
    }

    // Dashed clay border on .preview is implemented via CustomPaint border below.
    if (widget.state == SlotState.preview) {
      content = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final v = (math.sin(_pulse.value * math.pi * 2) + 1) / 2;
          return Opacity(opacity: 0.85 + 0.15 * v, child: child);
        },
        child: Stack(
          children: [
            content,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: t.clay,
                    radius: BgRadii.slot,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Sweeping shimmer on .pending
    if (widget.state == SlotState.pending) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(BgRadii.slot),
        child: Stack(
          children: [
            content,
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ShimmerPainter(
                      progress: _shimmer.value,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Shake on .failed
    if (widget.state == SlotState.failed) {
      content = AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          // 4-keyframe ±4px horizontal shake.
          final v = math.sin(_shake.value * math.pi * 4) * 4 *
              (1 - _shake.value);
          return Transform.translate(offset: Offset(v, 0), child: child);
        },
        child: content,
      );
    }

    final canTap = widget.onTap != null && widget.state != SlotState.past;
    return GestureDetector(
      onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
      onTapUp: canTap ? (_) => setState(() => _pressed = false) : null,
      onTap: canTap ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: BgDurations.slotPress,
        curve: Curves.easeOut,
        child: MouseRegion(
          cursor: widget.state == SlotState.past
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          child: content,
        ),
      ),
    );
  }
}

class _SlotStyle {
  final Color bg;
  final Color fg;
  final Border? border;
  final List<BoxShadow>? shadow;
  _SlotStyle({required this.bg, required this.fg, this.border, this.shadow});
}

_SlotStyle _styleFor(BgTokens t, SlotState s) {
  switch (s) {
    case SlotState.free:
      return _SlotStyle(bg: t.green, fg: Colors.white);
    case SlotState.preview:
      return _SlotStyle(bg: t.clayTint, fg: t.clayInk);
    case SlotState.pending:
      return _SlotStyle(bg: t.green, fg: Colors.white);
    case SlotState.failed:
      return _SlotStyle(bg: t.clay, fg: Colors.white);
    case SlotState.taken:
      return _SlotStyle(
        bg: t.surface,
        fg: t.ink2,
        border: Border.all(color: t.line2, width: 1.5),
      );
    case SlotState.mine:
      return _SlotStyle(
        bg: t.clay,
        fg: Colors.white,
        shadow: t.shadowMine,
      );
    case SlotState.mineLocked:
      return _SlotStyle(
        bg: t.clay,
        fg: Colors.white,
        shadow: t.shadowMine,
      );
    case SlotState.past:
      return _SlotStyle(
        bg: t.pastBg,
        fg: t.pastInk,
        border: Border.all(color: t.line2, width: 1.5),
      );
  }
}

class _SlotLabel extends StatelessWidget {
  final SlotState state;
  final Color color;
  final String? label;
  const _SlotLabel({required this.state, required this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    String? badge;
    if (state == SlotState.mine) badge = '·שלי';
    if (state == SlotState.mineLocked) badge = '·נעול';

    return Text.rich(
      TextSpan(children: [
        if (label != null) TextSpan(text: label, style: base),
        if (badge != null)
          TextSpan(
            text: ' $badge',
            style: base.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(0.85),
            ),
          ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

class _HatchPainter extends CustomPainter {
  final Color color;
  _HatchPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 6.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashed(path, dash: 4, gap: 3);
    canvas.drawPath(dashed, paint);
  }

  Path _dashed(Path source, {required double dash, required double gap}) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        out.addPath(
          metric.extractPath(dist, math.min(next, metric.length)),
          Offset.zero,
        );
        dist = next + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _ShimmerPainter extends CustomPainter {
  final double progress; // 0..1
  _ShimmerPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = -w + progress * (w * 2);
    final rect = Rect.fromLTWH(cx, 0, w * 0.6, size.height);
    final shader = LinearGradient(
      colors: [
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0.35),
        Colors.white.withOpacity(0),
      ],
      stops: const [0, 0.5, 1],
    ).createShader(rect);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}
