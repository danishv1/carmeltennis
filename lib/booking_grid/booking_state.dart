import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum BookingDay { today, tomorrow }

@immutable
class Booking {
  final String userName;
  final String partner;
  final int court;
  final int hour;
  final String date;
  final String docId;

  const Booking({
    required this.userName,
    required this.partner,
    required this.court,
    required this.hour,
    required this.date,
    required this.docId,
  });

  factory Booking.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      userName: (data['userName'] ?? '') as String,
      partner: (data['partner'] ?? '') as String,
      court: (data['courtNumber'] ?? 1) as int,
      hour: (data['hour'] ?? 0) as int,
      date: (data['date'] ?? '') as String,
      docId: doc.id,
    );
  }
}

@immutable
class Partner {
  final String id;
  final String name;
  Partner({required this.id, required this.name});

  String get initial => name.isNotEmpty ? name.characters.first : '?';
  String get shortName {
    final parts = name.split(' ');
    if (parts.length < 2) return name;
    final last = parts.last;
    return '${parts.first} ${last.characters.isNotEmpty ? '${last.characters.first}.' : ''}';
  }
}

/// Mirrors `useBookingState()` from the design handoff (data.jsx).
class BookingState extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const List<int> hours = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
  static const int courtCount = 2;

  /// Hours considered "busy" — get the clay heat overlay + flame.
  static const Set<int> busyHours = {13, 18, 19};

  BookingState() {
    _resolveMe();
    _subscribeBookings();
    _loadPartners();
  }

  // ---------- identity ----------
  String? _myUserName;
  String? _myEmail;
  String? get myUserName => _myUserName;

  void _resolveMe() {
    final user = FirebaseAuth.instance.currentUser;
    _myUserName = user?.displayName;
    _myEmail = user?.email;
  }

  // ---------- selection ----------
  BookingDay _day = BookingDay.today;
  BookingDay get day => _day;
  void setDay(BookingDay d) {
    if (d == _day) return;
    _day = d;
    notifyListeners();
  }

  String? _partnerName;
  String? get partnerName => _partnerName;
  void setPartner(String name) {
    _partnerName = name;
    notifyListeners();
  }

  void cyclePartner() {
    if (_partners.isEmpty) return;
    final idx = _partnerName == null
        ? -1
        : _partners.indexWhere((p) => p.name == _partnerName);
    final next = _partners[(idx + 1) % _partners.length];
    setPartner(next.name);
  }

  // ---------- partners ----------
  List<Partner> _partners = [];
  List<Partner> get partners => _partners;

  List<String> _recents = [];
  List<String> get recents => _recents;

  Future<void> _loadPartners() async {
    try {
      final snap = await _firestore.collection('users_2024').get();
      _partners = snap.docs
          .map((d) {
            final data = d.data();
            final first = (data['שם פרטי'] ?? '').toString().trim();
            final last = (data['שם משפחה'] ?? '').toString().trim();
            final name = '$first $last'.trim();
            return Partner(id: d.id, name: name);
          })
          .where((p) => p.name.isNotEmpty)
          .toList();
      // Pull recents off my user doc.
      if (_myEmail != null) {
        final mine = await _firestore
            .collection('users_2024')
            .where('מייל', isEqualTo: _myEmail)
            .limit(1)
            .get();
        if (mine.docs.isNotEmpty) {
          final raw = mine.docs.first.data()['lastFivePartners'];
          if (raw is List) {
            _recents = raw.map((e) => e.toString()).toList().reversed.toList();
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // network/permission errors leave the lists empty; UI degrades gracefully.
    }
  }

  // ---------- bookings stream ----------
  StreamSubscription<QuerySnapshot>? _todaySub;
  StreamSubscription<QuerySnapshot>? _tomorrowSub;
  final Map<String, List<Booking>> _bookingsByDate = {};

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _effectiveToday() {
    final now = DateTime.now();
    final base = _midnight(now);
    return now.hour >= 22 ? base.add(const Duration(days: 1)) : base;
  }

  DateTime get todayDate => _effectiveToday();
  DateTime get tomorrowDate => todayDate.add(const Duration(days: 1));
  DateTime get selectedDate =>
      _day == BookingDay.today ? todayDate : tomorrowDate;

  void _subscribeBookings() {
    _todaySub?.cancel();
    _tomorrowSub?.cancel();
    final t = _fmt(todayDate);
    final tm = _fmt(tomorrowDate);
    _todaySub = _firestore
        .collection('reservations')
        .where('date', isEqualTo: t)
        .snapshots()
        .listen((snap) {
      _bookingsByDate[t] = snap.docs.map(Booking.fromDoc).toList();
      notifyListeners();
    });
    _tomorrowSub = _firestore
        .collection('reservations')
        .where('date', isEqualTo: tm)
        .snapshots()
        .listen((snap) {
      _bookingsByDate[tm] = snap.docs.map(Booking.fromDoc).toList();
      notifyListeners();
    });
  }

  List<Booking> bookingsOn(BookingDay d) {
    final key = _fmt(d == BookingDay.today ? todayDate : tomorrowDate);
    return _bookingsByDate[key] ?? const [];
  }

  Booking? slotAt(int court, int hour) {
    for (final b in bookingsOn(_day)) {
      if (b.court == court && b.hour == hour) return b;
    }
    return null;
  }

  bool isMine(Booking? b) {
    if (b == null || _myUserName == null) return false;
    return b.userName == _myUserName || b.partner == _myUserName;
  }

  bool isPast(int hour) {
    if (_day != BookingDay.today) return false;
    return hour < DateTime.now().hour;
  }

  /// `now < hour <= now + 3` on today.
  bool isLocked(int hour) {
    if (_day != BookingDay.today) return false;
    final nowH = DateTime.now().hour;
    return hour > nowH && hour <= nowH + 3;
  }

  /// Find the user's next upcoming booking on the selected day, sorted by hour.
  Booking? get myNext {
    final now = DateTime.now().hour;
    final list = bookingsOn(_day).where(isMine).toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
    for (final b in list) {
      if (_day == BookingDay.tomorrow || b.hour > now) return b;
    }
    return null;
  }

  /// Count user's evening (18-20h) bookings across today + tomorrow.
  int get eveningCount {
    int n = 0;
    for (final d in BookingDay.values) {
      for (final b in bookingsOn(d)) {
        if (isMine(b) && b.hour >= 18 && b.hour <= 20) n++;
      }
    }
    return n;
  }

  static const int eveningCap = 3;

  // ---------- mutation ----------
  /// Create a reservation for me + selected partner on (court, hour) for the
  /// selected day. Returns the new doc id on success, or null on failure.
  Future<String?> book(int court, int hour) async {
    if (_myUserName == null) return null;
    if (_partnerName == null || _partnerName!.isEmpty) return null;
    final date = _fmt(selectedDate);
    try {
      final ref = await _firestore.collection('reservations').add({
        'date': date,
        'hour': hour,
        'courtNumber': court,
        'userName': _myUserName,
        'partner': _partnerName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (_) {
      return null;
    }
  }

  Future<bool> cancel(Booking b) async {
    try {
      await _firestore.collection('reservations').doc(b.docId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _todaySub?.cancel();
    _tomorrowSub?.cancel();
    super.dispose();
  }
}
