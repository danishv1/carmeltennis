import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme_controller.dart';
import 'booking_state.dart';
import 'slot_cell.dart';
import 'tokens.dart';

class BookingGridScreen extends StatefulWidget {
  const BookingGridScreen({super.key});

  @override
  State<BookingGridScreen> createState() => _BookingGridScreenState();
}

class _BookingGridScreenState extends State<BookingGridScreen> {
  late final BookingState _state;

  // Local UI state — mirrors the v3.1 prototype.
  String? _previewKey;
  String? _pendingKey;
  String? _failedKey;
  Timer? _previewTimer;
  Timer? _pendingTimer;
  Timer? _failedTimer;

  _ToastData? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _state = BookingState();
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _pendingTimer?.cancel();
    _failedTimer?.cancel();
    _toastTimer?.cancel();
    _state.removeListener(_onStateChanged);
    _state.dispose();
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  // ---------- toast ----------
  void _showToast(String msg, _ToastKind kind) {
    _toastTimer?.cancel();
    setState(() => _toast = _ToastData(msg, kind));
    _toastTimer = Timer(BgDurations.toastVisible, () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ---------- slot tap ----------
  String _key(int court, int hour) => '$court:$hour';

  void _onSlotTap(int court, int hour) {
    final key = _key(court, hour);
    final slot = _state.slotAt(court, hour);

    // Past — no-op.
    if (_state.isPast(hour)) return;

    // Mine?
    if (_state.isMine(slot)) {
      if (_state.isLocked(hour)) {
        _showToast('לא ניתן לבטל פחות מ-3 שעות לפני', _ToastKind.warn);
        return;
      }
      _openCancelSheet(slot!);
      return;
    }

    // Taken by someone else?
    if (slot != null) {
      _openWaitlistSheet(slot);
      return;
    }

    // Free → preview → pending → mine flow
    if (_state.partnerName == null || _state.partnerName!.isEmpty) {
      _showToast('בחר.י שותפ.ה', _ToastKind.warn);
      return;
    }

    if (_previewKey != key) {
      // First tap: preview.
      setState(() => _previewKey = key);
      _previewTimer?.cancel();
      _previewTimer = Timer(BgDurations.previewTimeout, () {
        if (mounted && _previewKey == key) {
          setState(() => _previewKey = null);
        }
      });
      return;
    }

    // Second tap within preview: commit.
    _previewTimer?.cancel();
    setState(() {
      _previewKey = null;
      _pendingKey = key;
    });

    () async {
      final docId = await _state.book(court, hour);
      _pendingTimer?.cancel();
      // Hold .pending visible for at least 700ms for visual feedback.
      _pendingTimer = Timer(BgDurations.pending, () {
        if (!mounted) return;
        setState(() => _pendingKey = null);
        if (docId != null) {
          _showToast('הוזמן', _ToastKind.good);
        } else {
          setState(() => _failedKey = key);
          _showToast('נכשל — נסה שוב', _ToastKind.warn);
          _failedTimer?.cancel();
          _failedTimer = Timer(BgDurations.shake, () {
            if (mounted) setState(() => _failedKey = null);
          });
        }
      });
    }();
  }

  SlotState _resolveSlotState(int court, int hour) {
    final key = _key(court, hour);
    if (_failedKey == key) return SlotState.failed;
    if (_pendingKey == key) return SlotState.pending;
    if (_previewKey == key) return SlotState.preview;
    if (_state.isPast(hour)) return SlotState.past;
    final slot = _state.slotAt(court, hour);
    if (_state.isMine(slot)) {
      return _state.isLocked(hour) ? SlotState.mineLocked : SlotState.mine;
    }
    if (slot != null) return SlotState.taken;
    return SlotState.free;
  }

  // ---------- bottom sheets ----------
  Future<void> _openCancelSheet(Booking slot) async {
    final t = BgTokens.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x801F1715),
      isScrollControlled: true,
      builder: (ctx) => _SheetCard(
        title: 'לבטל את ההזמנה?',
        sub: '${slot.hour}:00 · מגרש ${slot.court} · עם ${slot.partner}',
        options: [
          _SheetOption(
            iconText: '✕',
            title: 'בטל הזמנה',
            sub: 'המגרש יחזור לזמין',
            onTap: () async {
              Navigator.of(ctx).pop();
              final ok = await _state.cancel(slot);
              _showToast(
                ok ? 'בוטל' : 'נכשל — נסה שוב',
                ok ? _ToastKind.good : _ToastKind.warn,
              );
            },
          ),
          _SheetOption(
            iconText: '◐',
            title: 'השאר',
            sub: 'המשך כרגיל',
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
        tokens: t,
      ),
    );
  }

  Future<void> _openWaitlistSheet(Booking slot) async {
    final t = BgTokens.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x801F1715),
      isScrollControlled: true,
      builder: (ctx) => _SheetCard(
        title: 'המגרש תפוס',
        sub: '${slot.hour}:00 · מגרש ${slot.court} · ${slot.userName}',
        options: [
          _SheetOption(
            iconText: '⏳',
            title: 'הצטרף.י לרשימת המתנה',
            sub: 'נודיע אם יתפנה',
            onTap: () {
              Navigator.of(ctx).pop();
              _showToast('נוספת לרשימת המתנה', _ToastKind.good);
            },
          ),
          _SheetOption(
            iconText: '✕',
            title: 'סגור',
            sub: '',
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
        tokens: t,
      ),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final t = BgTokens.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Hero(state: _state, tokens: t),
                  _PartnerBar(state: _state, tokens: t),
                  _RecentsStrip(state: _state, tokens: t),
                  _CourtHeader(tokens: t),
                  Expanded(
                    child: _TimeGrid(
                      state: _state,
                      tokens: t,
                      resolveState: _resolveSlotState,
                      onTap: _onSlotTap,
                    ),
                  ),
                ],
              ),
              if (_toast != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: _Toast(data: _toast!, tokens: t),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _Hero extends StatelessWidget {
  final BookingState state;
  final BgTokens tokens;
  const _Hero({required this.state, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final next = state.myNext;
    final isToday = state.day == BookingDay.today;
    final dayLabel = isToday ? 'היום' : 'מחר';
    final date = DateFormat('d.M').format(state.selectedDate);

    final hasNext = next != null;
    return AnimatedContainer(
      duration: BgDurations.heroPad,
      curve: Curves.easeOut,
      padding: hasNext
          ? const EdgeInsets.fromLTRB(16, 11, 16, 12)
          : const EdgeInsets.fromLTRB(16, 9, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.clay, tokens.clayD],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HeroTexture()),
            ),
          ),
          if (hasNext)
            _HeroHasNext(
              dayLabel: dayLabel,
              date: date,
              next: next,
              state: state,
              tokens: tokens,
            )
          else
            _HeroNoNext(
              dayLabel: dayLabel,
              state: state,
              tokens: tokens,
            ),
        ],
      ),
    );
  }
}

class _HeroHasNext extends StatelessWidget {
  final String dayLabel;
  final String date;
  final Booking next;
  final BookingState state;
  final BgTokens tokens;
  const _HeroHasNext({
    required this.dayLabel,
    required this.date,
    required this.next,
    required this.state,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final partnerName = state.myUserName == next.userName
        ? next.partner
        : next.userName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                dayLabel,
                style: GoogleFonts.heebo(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.48,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  date,
                  style: GoogleFonts.heebo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.44,
                    color: Colors.white.withOpacity(0.78),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: 'הבא ',
                    style: GoogleFonts.heebo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                  TextSpan(
                    text: '${next.hour}:00',
                    style: GoogleFonts.heebo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.96),
                    ),
                  ),
                  TextSpan(
                    text: ' עם ',
                    style: GoogleFonts.heebo(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.96),
                    ),
                  ),
                  TextSpan(
                    text: partnerName,
                    style: GoogleFonts.heebo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.96),
                    ),
                  ),
                  TextSpan(
                    text: ' · מגרש ${next.court}',
                    style: GoogleFonts.heebo(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.96),
                    ),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _DayToggle(state: state),
          ],
        ),
      ],
    );
  }
}

class _HeroNoNext extends StatelessWidget {
  final String dayLabel;
  final BookingState state;
  final BgTokens tokens;
  const _HeroNoNext({
    required this.dayLabel,
    required this.state,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          dayLabel,
          style: GoogleFonts.heebo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· אין הזמנה',
          style: GoogleFonts.heebo(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.78),
          ),
        ),
        const Spacer(),
        _DayToggle(state: state),
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  final BookingState state;
  const _DayToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    final t = BgTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(BgRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('היום', BookingDay.today, t),
          _segment('מחר', BookingDay.tomorrow, t),
        ],
      ),
    );
  }

  Widget _segment(String label, BookingDay d, BgTokens t) {
    final active = state.day == d;
    return GestureDetector(
      onTap: () => state.setDay(d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(BgRadii.chip),
        ),
        child: Text(
          label,
          style: GoogleFonts.heebo(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? t.clayD : Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

class _HeroTexture extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.06);
    const stripe = 22.0;
    for (double y = 0; y < size.height; y += stripe + 1) {
      canvas.drawRect(Rect.fromLTWH(0, y + stripe, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_HeroTexture old) => false;
}

// ============================================================
// PARTNER BAR
// ============================================================

class _PartnerBar extends StatelessWidget {
  final BookingState state;
  final BgTokens tokens;
  const _PartnerBar({required this.state, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final me = state.myUserName ?? '';
    final initial = me.isNotEmpty ? me.characters.first : '?';
    final cap = state.eveningCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.clayTint,
              borderRadius: BorderRadius.circular(BgRadii.avatar),
            ),
            child: Text(
              initial,
              style: GoogleFonts.heebo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tokens.clayInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              me.isEmpty ? 'התחבר.י' : me,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.heebo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'ערב ',
                style: GoogleFonts.heebo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink2,
                ),
              ),
              TextSpan(
                text: '$cap',
                style: GoogleFonts.heebo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              TextSpan(
                text: '/${BookingState.eveningCap}',
                style: GoogleFonts.heebo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink2,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(BookingState.eveningCap, (i) {
              final filled = i < cap;
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: filled ? tokens.clay : tokens.line,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          _IconBtn(
            tokens: tokens,
            glyph: '↻',
            tooltip: 'כמו בשבוע שעבר',
            onTap: () {},
          ),
          const SizedBox(width: 6),
          _IconBtn(
            tokens: tokens,
            glyph: '↔',
            tooltip: 'החלף שותפ.ה',
            onTap: state.cyclePartner,
          ),
          const SizedBox(width: 6),
          _ThemeBtn(tokens: tokens),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final BgTokens tokens;
  final String glyph;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.tokens,
    required this.glyph,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BgRadii.iconBtn),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.clayTint,
            borderRadius: BorderRadius.circular(BgRadii.iconBtn),
          ),
          child: Text(
            glyph,
            style: GoogleFonts.heebo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tokens.clayInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeBtn extends StatelessWidget {
  final BgTokens tokens;
  const _ThemeBtn({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    return Tooltip(
      message: isDark ? 'מצב יום' : 'מצב לילה',
      child: InkWell(
        onTap: () => ThemeController.instance.toggle(),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isDark ? '☀' : '☾',
            style: TextStyle(fontSize: 12, color: tokens.ink2),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RECENTS STRIP
// ============================================================

class _RecentsStrip extends StatelessWidget {
  final BookingState state;
  final BgTokens tokens;
  const _RecentsStrip({required this.state, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final names = <String>{
      ...state.recents,
      ...state.partners.take(8).map((p) => p.name),
    }.where((n) => n.isNotEmpty && n != state.myUserName).toList();

    if (names.isEmpty) {
      return Container(
        height: 36,
        color: tokens.surface,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(bottom: BorderSide(color: tokens.line)),
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, i) {
          final name = names[i];
          final active = state.partnerName == name;
          final available = !_partnerBusyOnSelectedDay(state, name);
          return GestureDetector(
            onTap: () => state.setPartner(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? tokens.ink : tokens.clayTint,
                borderRadius: BorderRadius.circular(BgRadii.chip),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (available)
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: tokens.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Text(
                    name,
                    style: GoogleFonts.heebo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? tokens.bg : tokens.clayInk,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _partnerBusyOnSelectedDay(BookingState s, String name) {
    for (final b in s.bookingsOn(s.day)) {
      if (b.userName == name || b.partner == name) return true;
    }
    return false;
  }
}

// ============================================================
// COURT HEADER
// ============================================================

class _CourtHeader extends StatelessWidget {
  final BgTokens tokens;
  const _CourtHeader({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.heebo(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: tokens.ink,
    );
    return Container(
      color: tokens.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const SizedBox(width: 36),
          // RTL: court 2 visually on the right (first in row), court 1 on the left.
          Expanded(child: Center(child: Text('מגרש 2', style: style))),
          const SizedBox(width: 5),
          Expanded(child: Center(child: Text('מגרש 1', style: style))),
        ],
      ),
    );
  }
}

// ============================================================
// TIME GRID
// ============================================================

class _TimeGrid extends StatelessWidget {
  final BookingState state;
  final BgTokens tokens;
  final SlotState Function(int court, int hour) resolveState;
  final void Function(int court, int hour) onTap;
  const _TimeGrid({
    required this.state,
    required this.tokens,
    required this.resolveState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hours = BookingState.hours;
    final nowH = DateTime.now().hour;
    final showNowLine = state.day == BookingDay.today;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: hours.length,
      itemBuilder: (context, idx) {
        final hour = hours[idx];
        final isBusy = BookingState.busyHours.contains(hour);
        final showNowBefore = showNowLine && idx > 0 &&
            nowH >= hours[idx - 1] && nowH < hour;
        final isBusyBg = isBusy
            ? LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  tokens.clay.withOpacity(0.05),
                  tokens.clay.withOpacity(0.10),
                ],
              )
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showNowBefore) _NowDivider(tokens: tokens),
            Container(
              decoration: BoxDecoration(
                gradient: isBusyBg,
                borderRadius: BorderRadius.circular(BgRadii.slot),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$hour',
                          style: GoogleFonts.heebo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink2,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isBusy) ...[
                          const SizedBox(width: 3),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: tokens.clay,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // RTL: court 2 first → visually right.
                  Expanded(
                    child: SlotCell(
                      state: resolveState(2, hour),
                      label: _slotLabel(state, 2, hour),
                      onTap: () => onTap(2, hour),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SlotCell(
                      state: resolveState(1, hour),
                      label: _slotLabel(state, 1, hour),
                      onTap: () => onTap(1, hour),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String? _slotLabel(BookingState s, int court, int hour) {
    final b = s.slotAt(court, hour);
    if (b == null) return null;
    if (s.isMine(b)) return null; // mine appends ·שלי / ·נעול internally
    // Show partner name on .taken slots so users know who's playing.
    final other = b.userName;
    return other.length > 10 ? '${other.substring(0, 10)}…' : other;
  }
}

class _NowDivider extends StatelessWidget {
  final BgTokens tokens;
  const _NowDivider({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              color: tokens.clay.withOpacity(0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'עכשיו',
              style: GoogleFonts.heebo(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: tokens.clay,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: tokens.clay.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTTOM SHEET CARD
// ============================================================

class _SheetCard extends StatelessWidget {
  final String title;
  final String sub;
  final List<_SheetOption> options;
  final BgTokens tokens;
  const _SheetCard({
    required this.title,
    required this.sub,
    required this.options,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(BgRadii.sheetTop),
            topRight: Radius.circular(BgRadii.sheetTop),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.heebo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: GoogleFonts.heebo(
                fontSize: 12,
                color: tokens.ink2,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < options.length; i++)
              _SheetOptionRow(
                option: options[i],
                tokens: tokens,
                showTopBorder: i > 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption {
  final String iconText;
  final String title;
  final String sub;
  final VoidCallback onTap;
  _SheetOption({
    required this.iconText,
    required this.title,
    required this.sub,
    required this.onTap,
  });
}

class _SheetOptionRow extends StatelessWidget {
  final _SheetOption option;
  final BgTokens tokens;
  final bool showTopBorder;
  const _SheetOptionRow({
    required this.option,
    required this.tokens,
    required this.showTopBorder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: option.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(top: BorderSide(color: tokens.line))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.clayTint,
                borderRadius: BorderRadius.circular(BgRadii.sheetIcon),
              ),
              child: Text(
                option.iconText,
                style: GoogleFonts.heebo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.clayInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.title,
                    style: GoogleFonts.heebo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  if (option.sub.isNotEmpty)
                    Text(
                      option.sub,
                      style: GoogleFonts.heebo(
                        fontSize: 11,
                        color: tokens.ink2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TOAST
// ============================================================

enum _ToastKind { good, warn, info }

class _ToastData {
  final String msg;
  final _ToastKind kind;
  _ToastData(this.msg, this.kind);
}

class _Toast extends StatelessWidget {
  final _ToastData data;
  final BgTokens tokens;
  const _Toast({required this.data, required this.tokens});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (data.kind) {
      case _ToastKind.good:
        bg = tokens.green;
        fg = Colors.white;
        break;
      case _ToastKind.warn:
        bg = tokens.clay;
        fg = Colors.white;
        break;
      case _ToastKind.info:
        bg = tokens.ink;
        fg = tokens.bg;
        break;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: BgDurations.toastIn,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 8),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(BgRadii.toast),
        ),
        child: Center(
          child: Text(
            data.msg,
            style: GoogleFonts.heebo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// Avoids "unused import" warning if you trim animations.
// ignore: unused_element
final _kPi = math.pi;
