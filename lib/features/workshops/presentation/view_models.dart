import 'dart:async';
import 'package:dio/dio.dart';
import '../data/workshop_session.dart';
import 'package:flutter/foundation.dart';
import '../data/workshops.dart';

class DiscoverViewModel extends ChangeNotifier {
  DiscoverViewModel(this.repository, {WorkshopSession? session})
    : session = session ?? WorkshopSession(repository),
      _ownsSession = session == null {
    this.session.addListener(_sync);
  }
  final WorkshopSession session;
  final bool _ownsSession;
  void _sync() {
    items = List.unmodifiable(
      items.map((item) => session.snapshot(item.id) ?? item),
    );
    if (!_disposed) notifyListeners();
  }

  final WorkshopRepository repository;
  List<Workshop> items = const [];
  int? nextPage;
  bool loaded = false, loading = false, refreshing = false, appending = false;
  bool initialError = false, refreshError = false, appendError = false;
  int _generation = 0;
  bool _disposed = false;
  CancelToken? _firstToken, _pageToken;

  Future<void> load() => _loadFirst();
  Future<void> refresh() => _loadFirst();
  Future<void> _loadFirst() async {
    if (loading || refreshing) return;
    final generation = ++_generation;
    _pageToken?.cancel();
    appending = false;
    final previousAppendError = appendError;
    appendError = false;
    initialError = refreshError = false;
    loading = !loaded;
    refreshing = loaded;
    _firstToken = CancelToken();
    notifyListeners();
    try {
      final page = await session.list(1, cancelToken: _firstToken);
      if (_disposed || generation != _generation) return;
      items = page.items;
      nextPage = page.nextPage;
      loaded = true;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      initialError = !loaded;
      refreshError = loaded;
      appendError = previousAppendError;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    if (!loaded ||
        loading ||
        refreshing ||
        appending ||
        nextPage == null ||
        (appendError && !retry)) {
      return;
    }
    final generation = _generation;
    final requestedPage = nextPage!;
    _pageToken = CancelToken();
    appending = true;
    appendError = false;
    notifyListeners();
    try {
      final page = await session.list(requestedPage, cancelToken: _pageToken);
      if (_disposed || generation != _generation) return;
      final merged = {for (final item in items) item.id: item};
      for (final item in page.items) {
        merged[item.id] = item;
      }
      items = List.unmodifiable(merged.values);
      nextPage = page.nextPage;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      appendError = true;
    } finally {
      if (!_disposed && generation == _generation) {
        appending = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_sync);
    if (_ownsSession) session.dispose();
    _firstToken?.cancel();
    _pageToken?.cancel();
    super.dispose();
  }
}

class DetailViewModel extends ChangeNotifier {
  DetailViewModel(this.repository, this.id, {WorkshopSession? session})
    : session = session ?? WorkshopSession(repository),
      _ownsSession = session == null {
    workshop = this.session.snapshot(id);
    this.session.addListener(_sync);
  }
  final WorkshopRepository repository;
  final WorkshopSession session;
  final bool _ownsSession;
  final String id;
  Workshop? workshop;
  bool loading = true, failed = false, notFound = false, _disposed = false;
  bool _querying = false;
  int feedbackSerial = 0;
  String? feedback;
  CancelToken? _token;
  ReservationPhase get phase =>
      _querying ? ReservationPhase.reconciling : session.phase(id);
  bool get canReserve =>
      !loading &&
      !failed &&
      phase == ReservationPhase.idle &&
      workshop != null &&
      workshop!.myReservationId == null &&
      workshop!.remaining > 0;
  void _sync() {
    if (_disposed) return;
    workshop = session.snapshot(id) ?? workshop;
    notifyListeners();
  }

  void _feedback(String message) {
    if (_disposed) return;
    feedback = message;
    feedbackSerial++;
    notifyListeners();
  }

  Future<void> load() async {
    _token?.cancel();
    final token = _token = CancelToken();
    loading = workshop == null;
    failed = notFound = false;
    notifyListeners();
    try {
      final result = await session.read(id, cancelToken: token);
      if (!_disposed && identical(token, _token)) workshop = result;
    } catch (error) {
      if (_disposed || !identical(token, _token)) return;
      failed = true;
      notFound = error is WorkshopFailure && error.notFound;
    } finally {
      if (!_disposed && identical(token, _token)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> reserve() async {
    if (!canReserve) return;
    _token?.cancel();
    _token = null;
    try {
      await session.create(id);
      _feedback('预约成功');
    } catch (error) {
      if (error is WorkshopFailure && error.statusCode == 404) {
        if (_disposed) return;
        failed = notFound = true;
      } else if (error is WorkshopFailure && error.statusCode == 400) {
        _feedback('参数错误');
      } else if (error is WorkshopFailure &&
          error.statusCode == 409 &&
          (error.code == 'FULL' || error.code == 'ALREADY_BOOKED')) {
        _feedback(error.code == 'FULL' ? '名额已满' : '你已预约此活动');
        if (!_disposed) await queryResult();
      }
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> queryResult() async {
    if (_disposed || _querying || phase == ReservationPhase.submitting) return;
    _querying = true;
    final token = _token = CancelToken();
    notifyListeners();
    try {
      final result = await session.read(id, cancelToken: token);
      if (!_disposed && identical(token, _token)) {
        workshop = result;
        failed = notFound = false;
      }
    } catch (error) {
      if (!_disposed && identical(token, _token)) {
        if (error is WorkshopFailure && error.notFound) {
          failed = notFound = true;
        } else {
          session.markUnknown(id);
        }
      }
    } finally {
      if (!_disposed && identical(token, _token)) {
        _querying = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    session.removeListener(_sync);
    if (_ownsSession) session.dispose();
    super.dispose();
  }
}
