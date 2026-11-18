import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_work_flow_demo2/main.dart';
import 'package:ai_work_flow_demo2/features/workshops/presentation/pages.dart';

// Android 真机的帧与 HTTP 响应可能在不同时间到达。
Future<void> waitForText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('A1 A2 A4 real service browse detail and missing ID', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkshopApp());
    await waitForText(tester, '纸上造景');
    await tester.pumpAndSettle();
    debugPrint('CAPTURE_P1_READY');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(find.text('手捏陶杯'), findsOneWidget);
    expect(find.text('手工装帧'), findsOneWidget);
    if (find.text('加载更多').evaluate().isNotEmpty) {
      await tester.tap(find.text('加载更多'));
    } else {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('木匙打磨'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final row = find.ancestor(
      of: find.text('木匙打磨'),
      matching: find.byType(WorkshopRow),
    );
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = position.pixels;
    await tester.tap(row);
    await waitForText(tester, '山间木舍');
    await tester.pumpAndSettle();
    debugPrint('CAPTURE_P2_READY');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(find.text('从木料开始，打磨自己的第一把小匙。'), findsOneWidget);
    expect(find.text('我的预约'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(position.pixels, offset);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await refresh;
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(find.byType(WorkshopRow), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const WorkshopApp(initialLocation: '/workshops/missing'),
    );
    await waitForText(tester, '活动不存在');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('周末工坊'), findsOneWidget);
  });
}
