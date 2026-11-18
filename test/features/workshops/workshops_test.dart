import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_work_flow_demo2/main.dart';
import 'package:ai_work_flow_demo2/features/workshops/data/workshops.dart';
import 'package:ai_work_flow_demo2/features/workshops/presentation/view_models.dart';

Workshop workshop(String id) => Workshop(
  id: id,
  title: id == 'w05' ? '木匙打磨' : '活动$id',
  startsAt: DateTime.parse('2026-12-05T14:00:00+08:00'),
  endsAt: DateTime.parse('2026-12-05T16:00:00+08:00'),
  venue: '工作室',
  description: '活动介绍内容',
  remaining: 3,
  myReservationId: null,
);

class FakeRepository implements WorkshopRepository {
  @override
  Future<Reservation> createReservation(String id) =>
      throw UnimplementedError();
  final pages = <int>[];
  final pending = <Completer<WorkshopPage>>[];
  final detailIds = <String>[];
  final details = <Completer<Workshop>>[];
  @override
  Future<WorkshopPage> listWorkshops(int page, {CancelToken? cancelToken}) {
    pages.add(page);
    final request = Completer<WorkshopPage>();
    pending.add(request);
    return request.future;
  }

  @override
  Future<Workshop> getWorkshop(String id, {CancelToken? cancelToken}) {
    detailIds.add(id);
    final request = Completer<Workshop>();
    details.add(request);
    return request.future;
  }
}

void main() {
  test('A1 pagination deduplicates requests and stops at last page', () async {
    final repo = FakeRepository();
    final vm = DiscoverViewModel(repo);
    final first = vm.load();
    repo.pending[0].complete(WorkshopPage([workshop('w01')], 2));
    await first;
    final next = vm.loadMore();
    await vm.loadMore();
    expect(repo.pages, [1, 2]);
    repo.pending[1].complete(WorkshopPage([workshop('w05')], null));
    await next;
    await vm.loadMore();
    expect(vm.items.map((e) => e.id), ['w01', 'w05']);
    expect(repo.pages, [1, 2]);
    vm.dispose();
  });

  test('A3 initial, refresh and append failure retry original page', () async {
    final repo = FakeRepository();
    final vm = DiscoverViewModel(repo);
    var request = vm.load();
    repo.pending.last.completeError(Exception('offline'));
    await request;
    expect(vm.initialError, true);
    request = vm.load();
    repo.pending.last.complete(WorkshopPage([workshop('w01')], 2));
    await request;
    request = vm.loadMore();
    repo.pending.last.completeError(Exception('offline'));
    await request;
    expect(vm.appendError, true);
    await vm.loadMore();
    expect(repo.pages, [1, 1, 2]);
    request = vm.loadMore(retry: true);
    repo.pending.last.complete(WorkshopPage([workshop('w05')], null));
    await request;
    request = vm.refresh();
    repo.pending.last.completeError(Exception('offline'));
    await request;
    expect(vm.refreshError, true);
    expect(vm.items.length, 2);
    vm.dispose();
  });

  for (final refreshFails in [false, true]) {
    test('A3 ignores old page after refresh, failure=$refreshFails', () async {
      final repo = FakeRepository();
      final vm = DiscoverViewModel(repo);
      final first = vm.load();
      repo.pending[0].complete(WorkshopPage([workshop('w01')], 2));
      await first;
      final old = vm.loadMore();
      final fresh = vm.refresh();
      if (refreshFails) {
        repo.pending[2].completeError(Exception('offline'));
      } else {
        repo.pending[2].complete(WorkshopPage([workshop('new')], null));
      }
      await fresh;
      repo.pending[1].complete(WorkshopPage([workshop('old')], null));
      await old;
      expect(vm.items.single.id, refreshFails ? 'w01' : 'new');
      vm.dispose();
    });
  }

  testWidgets('A1/A2 short list loads more, opens ID and returns to list', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(WorkshopApp(repository: repo));
    await tester.pump();
    repo.pending[0].complete(WorkshopPage([workshop('w01')], 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多'));
    await tester.pump();
    expect(repo.pages, [1, 2]);
    repo.pending[1].complete(WorkshopPage([workshop('w05')], null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('木匙打磨'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.detailIds, ['w05']);
    repo.details[0].complete(workshop('w05'));
    await tester.pumpAndSettle();
    expect(find.text('活动介绍内容'), findsOneWidget);
    expect(find.text('我的预约'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('我的预约'), findsOneWidget);
    expect(find.text('木匙打磨'), findsOneWidget);
    expect(repo.pages, [1, 2]);
  });

  testWidgets('A3 initial error retry and empty result', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(WorkshopApp(repository: repo));
    await tester.pump();
    repo.pending[0].completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    repo.pending[1].complete(WorkshopPage([], null));
    await tester.pumpAndSettle();
    expect(find.text('暂无活动'), findsOneWidget);
  });

  testWidgets('A4 direct ID 404 has fallback return', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(
      WorkshopApp(repository: repo, initialLocation: '/workshops/missing'),
    );
    await tester.pump();
    expect(repo.detailIds, ['missing']);
    repo.details[0].completeError(const WorkshopFailure(notFound: true));
    await tester.pumpAndSettle();
    expect(find.text('活动不存在'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    expect(repo.pages, [1]);
    repo.pending[0].complete(WorkshopPage([], null));
    await tester.pumpAndSettle();
    expect(find.text('暂无活动'), findsOneWidget);
  });
  testWidgets('A2 scroll offset survives detail and refresh replaces pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository();
    await tester.pumpWidget(WorkshopApp(repository: repo));
    await tester.pump();
    repo.pending[0].complete(
      WorkshopPage([workshop('w01'), workshop('w02'), workshop('w03')], 2),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
    expect(repo.pages, [1, 2]);
    repo.pending[1].complete(
      WorkshopPage([workshop('w04'), workshop('w05')], null),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('木匙打磨'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = scroll.pixels;
    await tester.tap(find.text('木匙打磨'));
    await tester.pump();
    repo.details.last.complete(workshop('w05'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(scroll.pixels, offset);
    expect(repo.pages, [1, 2]);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    repo.pending.last.complete(WorkshopPage([workshop('w01')], 2));
    await refresh;
    await tester.pumpAndSettle();
    expect(scroll.pixels, 0);
    expect(find.text('木匙打磨'), findsNothing);
    expect(repo.pages, [1, 2, 1]);
  });

  testWidgets('A4 narrow large text detail retry and return during loading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: WorkshopApp(repository: repo, initialLocation: '/workshops/w05'),
      ),
    );
    await tester.pump();
    repo.details.last.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(repo.detailIds, ['w05', 'w05']);
    repo.details.last.complete(workshop('w05'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    repo.pending.last.complete(WorkshopPage([workshop('w05')], null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('木匙打磨'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    repo.details.last.complete(workshop('w05'));
    await tester.pumpAndSettle();
    expect(find.text('我的预约'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A3 append and refresh errors keep content and retry', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(WorkshopApp(repository: repo));
    await tester.pump();
    repo.pending.last.complete(WorkshopPage([workshop('w01')], 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多'));
    await tester.pump();
    repo.pending.last.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('活动w01'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(repo.pages, [1, 2, 2]);
    repo.pending.last.complete(WorkshopPage([workshop('w05')], null));
    await tester.pumpAndSettle();
    final request = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    repo.pending.last.completeError(Exception('offline'));
    await request;
    await tester.pumpAndSettle();
    expect(find.text('刷新失败'), findsOneWidget);
    expect(find.text('木匙打磨'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    repo.pending.last.complete(WorkshopPage([], null));
    await tester.pumpAndSettle();
    expect(find.text('暂无活动'), findsOneWidget);
    expect(find.text('刷新失败'), findsNothing);
  });
}
