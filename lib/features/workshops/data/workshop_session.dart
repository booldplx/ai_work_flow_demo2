import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'workshops.dart';

enum ReservationPhase { idle, submitting, reconciling, unknown }

/// 共享活动快照与在途预约，页面退出后仍能接收服务端结果。
class WorkshopSession extends ChangeNotifier {
  WorkshopSession(this.repository);
  final WorkshopRepository repository;
  final _snapshots = <String, Workshop>{};
  final _versions = <String, int>{};
  final _writes = <String, Future<Reservation>>{};
  final _phases = <String, ReservationPhase>{};
  bool _disposed = false;
  Workshop? snapshot(String id) => _snapshots[id];
  ReservationPhase phase(String id) => _phases[id] ?? ReservationPhase.idle;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _ensureActive(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    if (_disposed) throw const WorkshopFailure();
  }

  void _publish(Workshop workshop) {
    if (_disposed) return;
    _snapshots[workshop.id] = workshop;
    _versions.update(workshop.id, (v) => v + 1, ifAbsent: () => 1);
    _emit();
  }

  Future<WorkshopPage> list(int page, {CancelToken? cancelToken}) async {
    _ensureActive(cancelToken);
    final versions = Map<String, int>.of(_versions);
    final result = await repository.listWorkshops(
      page,
      cancelToken: cancelToken,
    );
    _ensureActive(cancelToken);
    final items = result.items.map((item) {
      final changed = (versions[item.id] ?? 0) != (_versions[item.id] ?? 0);
      if (changed || _writes.containsKey(item.id)) {
        return _snapshots[item.id] ?? item;
      }
      _publish(item);
      return item;
    }).toList();
    return WorkshopPage(items, result.nextPage);
  }

  Future<Workshop> read(String id, {CancelToken? cancelToken}) async {
    final pending = _writes[id];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        /* GET 确认写入的实际结果。 */
      }
    }
    _ensureActive(cancelToken);
    final version = _versions[id] ?? 0;
    final result = await repository.getWorkshop(id, cancelToken: cancelToken);
    _ensureActive(cancelToken);
    if (version != (_versions[id] ?? 0)) return _snapshots[id] ?? result;
    _publish(result);
    // 旧读取不会解除正在执行的创建。
    if (!_writes.containsKey(id)) {
      _phases.remove(id);
      _emit();
    }
    return result;
  }

  Future<Reservation> create(String id) {
    final existing = _writes[id];
    if (existing != null) return existing;
    if (phase(id) != ReservationPhase.idle) {
      return Future.error(const WorkshopFailure());
    }
    // 先登记 Future，再通知，保证重入的同活动提交也共用本次操作。
    final completion = Completer<Reservation>();
    _writes[id] = completion.future;
    _phases[id] = ReservationPhase.submitting;
    _versions.update(id, (v) => v + 1, ifAbsent: () => 1);
    _emit();
    unawaited(_performCreate(id, completion));
    return completion.future;
  }

  Future<void> _performCreate(
    String id,
    Completer<Reservation> completion,
  ) async {
    try {
      final result = await repository.createReservation(id);
      _phases.remove(id);
      _publish(result.workshop);
      completion.complete(result);
    } catch (error, stack) {
      if (error is WorkshopFailure &&
          (error.statusCode == 400 || error.statusCode == 404)) {
        _phases.remove(id);
      } else {
        _phases[id] = ReservationPhase.unknown;
      }
      completion.completeError(error, stack);
    } finally {
      _writes.remove(id);
      _emit();
    }
  }

  void markUnknown(String id) {
    _phases[id] = ReservationPhase.unknown;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
