import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/workshops.dart';

class DiscoverViewModel extends ChangeNotifier {
  DiscoverViewModel(this.repository);
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
      final page = await repository.listWorkshops(1, cancelToken: _firstToken);
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
      final page = await repository.listWorkshops(
        requestedPage,
        cancelToken: _pageToken,
      );
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
    _firstToken?.cancel();
    _pageToken?.cancel();
    super.dispose();
  }
}

class DetailViewModel extends ChangeNotifier {
  DetailViewModel(this.repository, this.id);
  final WorkshopRepository repository;
  final String id;
  Workshop? workshop;
  bool loading = true, failed = false, notFound = false, _disposed = false;
  CancelToken? _token;
  Future<void> load() async {
    _token?.cancel();
    final token = _token = CancelToken();
    loading = true;
    failed = notFound = false;
    notifyListeners();
    try {
      final result = await repository.getWorkshop(id, cancelToken: token);
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

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}
