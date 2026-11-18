import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_work_flow_demo2/main.dart';
import 'package:ai_work_flow_demo2/features/workshops/data/workshops.dart';
import 'package:ai_work_flow_demo2/features/workshops/presentation/pages.dart';

Future<void> waitFor(WidgetTester tester, String text) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (find.text(text).evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text(text), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('B1 B2 B3 real creation, shared discovery and full workshop', (
    tester,
  ) async {
    const id = String.fromEnvironment('TEST_WORKSHOP_ID', defaultValue: 'w01');
    const address = String.fromEnvironment('API_BASE_URL');
    final client = Dio(BaseOptions(baseUrl: '$address/'));
    addTearDown(() => client.close(force: true));
    final repository = HttpWorkshopRepository(WorkshopService(client));
    final before = await repository.getWorkshop(id);
    expect(before.myReservationId, isNull);
    await tester.pumpWidget(const WorkshopApp());
    await waitFor(tester, before.title);
    await tester.tap(find.text(before.title));
    await waitFor(tester, '预约活动');
    await tester.pumpAndSettle();
    debugPrint('CARD2_BEFORE');
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.tap(find.text('预约活动'));
    await waitFor(tester, '已预约');
    await tester.pumpAndSettle();
    await waitFor(tester, '余 ${before.remaining - 1} 席');
    expect(find.text('余 ${before.remaining - 1} 席'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '查看我的预约'))
          .onPressed,
      isNull,
    );
    debugPrint('CARD2_SUCCESS');
    await Future<void>.delayed(const Duration(seconds: 2));
    final after = await repository.getWorkshop(id);
    expect(after.myReservationId, isNotNull);
    await expectLater(
      repository.createReservation(id),
      throwsA(
        isA<WorkshopFailure>().having(
          (e) => e.code,
          'conflict',
          'ALREADY_BOOKED',
        ),
      ),
    );
    expect((await repository.getWorkshop(id)).remaining, after.remaining);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text(before.title),
      matching: find.byType(WorkshopRow),
    );
    expect(
      find.descendant(of: row, matching: find.text('已预约')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('余 ${after.remaining} 席')),
      findsOneWidget,
    );
    debugPrint('CARD2_DISCOVERY');
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.tap(find.text('手捏陶杯'));
    await tester.pumpAndSettle();
    await waitFor(tester, '已满额');
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '已满额'))
          .onPressed,
      isNull,
    );
  });
}
