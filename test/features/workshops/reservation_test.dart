import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_work_flow_demo2/main.dart';
import 'package:ai_work_flow_demo2/features/workshops/data/workshops.dart';
import 'package:ai_work_flow_demo2/features/workshops/data/workshop_session.dart';
import 'package:ai_work_flow_demo2/features/workshops/presentation/view_models.dart';
import 'workshops_test.dart' show workshop;

Workshop booked() => Workshop(
  id: 'w01',
  title: '活动w01',
  startsAt: workshop('w01').startsAt,
  endsAt: workshop('w01').endsAt,
  venue: '工作室',
  description: '介绍',
  remaining: 2,
  myReservationId: 1,
);

class ReservationFake implements WorkshopRepository {
  final writes = <Completer<Reservation>>[];
  final reads = <Completer<Workshop>>[];
  final pages = <Completer<WorkshopPage>>[];
  @override
  Future<Reservation> createReservation(String id) {
    final value = Completer<Reservation>();
    writes.add(value);
    return value.future;
  }

  @override
  Future<Workshop> getWorkshop(String id, {CancelToken? cancelToken}) {
    final value = Completer<Workshop>();
    reads.add(value);
    return value.future;
  }

  @override
  Future<WorkshopPage> listWorkshops(int page, {CancelToken? cancelToken}) {
    final value = Completer<WorkshopPage>();
    pages.add(value);
    return value.future;
  }
}

Future<DetailViewModel> ready(
  ReservationFake repo,
  WorkshopSession session,
) async {
  final vm = DetailViewModel(repo, 'w01', session: session);
  final load = vm.load();
  repo.reads.last.complete(workshop('w01'));
  await load;
  return vm;
}

void main() {
  test('B1 B2 one write updates loaded list and rejects stale page', () async {
    final repo = ReservationFake();
    final session = WorkshopSession(repo);
    final discover = DiscoverViewModel(repo, session: session);
    final initial = discover.load();
    repo.pages.last.complete(WorkshopPage([workshop('w01')], 2));
    await initial;
    final detail = await ready(repo, session);
    final oldPage = discover.loadMore();
    final write = detail.reserve();
    await detail.reserve();
    expect(repo.writes.length, 1);
    repo.writes.single.complete(Reservation(1, booked()));
    await write;
    repo.pages.last.complete(
      WorkshopPage([workshop('w01'), workshop('w05')], null),
    );
    await oldPage;
    expect(detail.workshop!.myReservationId, 1);
    expect(discover.items.first.remaining, 2);
    expect(discover.items.length, 2);
    detail.dispose();
    discover.dispose();
    session.dispose();
  });

  for (final code in ['FULL', 'ALREADY_BOOKED']) {
    test('B2 B3 $code queries current state after conflict', () async {
      final repo = ReservationFake();
      final session = WorkshopSession(repo);
      final detail = await ready(repo, session);
      final write = detail.reserve();
      repo.writes.single.completeError(
        WorkshopFailure(statusCode: 409, code: code),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.reads.length, 2);
      repo.reads.last.complete(booked());
      await write;
      expect(detail.workshop!.myReservationId, 1);
      expect(detail.phase, ReservationPhase.idle);
      detail.dispose();
      session.dispose();
    });
  }

  test(
    'B4 leaving mid write shares pending operation and later queries',
    () async {
      final repo = ReservationFake();
      final session = WorkshopSession(repo);
      final first = await ready(repo, session);
      final write = first.reserve();
      first.dispose();
      final second = DetailViewModel(repo, 'w01', session: session);
      final load = second.load();
      expect(session.phase('w01'), ReservationPhase.submitting);
      expect(repo.reads.length, 1);
      repo.writes.single.complete(Reservation(1, booked()));
      await write;
      await Future<void>.delayed(Duration.zero);
      repo.reads.last.complete(booked());
      await load;
      expect(second.workshop!.myReservationId, 1);
      expect(repo.writes.length, 1);
      second.dispose();
      session.dispose();
    },
  );

  test('B4 timeout blocks new writes until query succeeds', () async {
    final repo = ReservationFake();
    final session = WorkshopSession(repo);
    final detail = await ready(repo, session);
    final write = detail.reserve();
    repo.writes.single.completeError(const WorkshopFailure());
    await write;
    expect(detail.phase, ReservationPhase.unknown);
    await detail.reserve();
    expect(repo.writes.length, 1);
    final query = detail.queryResult();
    repo.reads.last.complete(booked());
    await query;
    expect(detail.phase, ReservationPhase.idle);
    expect(detail.workshop!.remaining, 2);
    detail.dispose();
    session.dispose();
  });

  for (final status in [400, 404]) {
    test('B5 B6 maps creation $status', () async {
      final repo = ReservationFake();
      final session = WorkshopSession(repo);
      final detail = await ready(repo, session);
      final write = detail.reserve();
      repo.writes.single.completeError(
        WorkshopFailure(
          statusCode: status,
          code: status == 400 ? 'BAD_REQUEST' : 'NOT_FOUND',
        ),
      );
      await write;
      expect(detail.notFound, status == 404);
      if (status == 400) expect(detail.feedback, '参数错误');
      detail.dispose();
      session.dispose();
    });
  }

  testWidgets('B1 reserve button, success Toast and discovery sync', (
    tester,
  ) async {
    final repo = ReservationFake();
    await tester.pumpWidget(WorkshopApp(repository: repo));
    await tester.pump();
    repo.pages.last.complete(WorkshopPage([workshop('w01')], null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('活动w01'));
    await tester.pump();
    repo.reads.last.complete(workshop('w01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预约活动'));
    await tester.pump();
    expect(find.text('预约中…'), findsOneWidget);
    repo.writes.single.complete(Reservation(1, booked()));
    await tester.pumpAndSettle();
    expect(find.text('已预约'), findsOneWidget);
    expect(find.text('查看我的预约'), findsOneWidget);
    expect(find.text('预约成功'), findsOneWidget);
    expect(
      tester.getRect(find.text('预约成功')).bottom,
      lessThan(tester.getRect(find.text('已预约')).top),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('预约成功'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('已预约'), findsOneWidget);
    expect(find.text('余 2 席'), findsOneWidget);
  });
  test('B3 full detail cannot create, booked status wins full', () async {
    final repo = ReservationFake();
    final session = WorkshopSession(repo);
    final detail = DetailViewModel(repo, 'w02', session: session);
    final request = detail.load();
    repo.reads.last.complete(
      Workshop(
        id: 'w02',
        title: '满额',
        startsAt: workshop('w02').startsAt,
        endsAt: workshop('w02').endsAt,
        venue: '工作室',
        description: '介绍',
        remaining: 0,
        myReservationId: null,
      ),
    );
    await request;
    expect(detail.canReserve, false);
    await detail.reserve();
    expect(repo.writes, isEmpty);
    detail.dispose();
    session.dispose();
  });

  test(
    'B4 failed conflict query keeps recovery and retries GET only',
    () async {
      final repo = ReservationFake();
      final session = WorkshopSession(repo);
      final detail = await ready(repo, session);
      final request = detail.reserve();
      repo.writes.last.completeError(
        const WorkshopFailure(statusCode: 409, code: 'FULL'),
      );
      await Future<void>.delayed(Duration.zero);
      repo.reads.last.completeError(const WorkshopFailure());
      await request;
      expect(detail.phase, ReservationPhase.unknown);
      final query = detail.queryResult();
      await detail.queryResult();
      expect(repo.reads.length, 3);
      repo.reads.last.complete(booked());
      await query;
      expect(repo.writes.length, 1);
      expect(detail.workshop!.remaining, 2);
      detail.dispose();
      session.dispose();
    },
  );

  for (final status in [400, 404]) {
    testWidgets('B5 B6 widget feedback $status and cleanup', (tester) async {
      final repo = ReservationFake();
      await tester.pumpWidget(
        WorkshopApp(repository: repo, initialLocation: '/workshops/w01'),
      );
      await tester.pump();
      repo.reads.last.complete(workshop('w01'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('预约活动'));
      await tester.pump();
      repo.writes.last.completeError(WorkshopFailure(statusCode: status));
      await tester.pumpAndSettle();
      expect(find.text(status == 400 ? '参数错误' : '活动不存在'), findsOneWidget);
      if (status == 400) {
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '预约活动'))
              .onPressed,
          isNotNull,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }

  test('session concurrent create callers share Future and one POST', () async {
    final repo = ReservationFake();
    final session = WorkshopSession(repo);
    final first = session.create('w01');
    final second = session.create('w01');
    expect(identical(first, second), true);
    expect(repo.writes.length, 1);
    repo.writes.single.complete(Reservation(1, booked()));
    await first;
    session.dispose();
  });
  test('cancelled old read cannot publish through shared snapshots', () async {
    final repo = ReservationFake();
    final session = WorkshopSession(repo);
    final detail = await ready(repo, session);
    final token = CancelToken();
    final oldRead = session.read('w01', cancelToken: token);
    final ignoredError = expectLater(oldRead, throwsA(isA<DioException>()));
    token.cancel();
    repo.reads.last.complete(booked());
    await ignoredError;
    expect(detail.workshop!.remaining, 3);
    final discover = DiscoverViewModel(repo, session: session);
    final first = discover.load();
    repo.pages.last.complete(WorkshopPage([workshop('w01')], 2));
    await first;
    final oldPage = discover.loadMore();
    final fresh = discover.refresh();
    final pageCompleters = repo.pages;
    pageCompleters.last.complete(WorkshopPage([workshop('w01')], null));
    await fresh;
    pageCompleters[1].complete(WorkshopPage([booked()], null));
    await oldPage;
    expect(discover.items.single.remaining, 3);
    expect(detail.workshop!.remaining, 3);
    discover.dispose();
    detail.dispose();
    session.dispose();
  });
  test(
    'B4 cached detail read cancellation cannot hide a successful write',
    () async {
      final repo = ReservationFake();
      final session = WorkshopSession(repo);
      final first = await ready(repo, session);
      first.dispose();
      final detail = DetailViewModel(repo, 'w01', session: session);
      final load = detail.load();
      expect(detail.canReserve, true);
      final write = detail.reserve();
      repo.reads.last.completeError(const WorkshopFailure());
      await load;
      repo.writes.last.complete(Reservation(1, booked()));
      await write;
      expect(detail.failed, false);
      expect(detail.workshop!.remaining, 2);
      detail.dispose();
      session.dispose();
    },
  );
}
