import 'package:flutter_test/flutter_test.dart';
import 'package:ai_work_flow_demo2/features/workshops/presentation/pages.dart';

void main() {
  test('workshop display always uses UTC+08:00', () {
    expect(clock(DateTime.parse('2026-11-21T06:00:00Z')), '14:00');
    expect(workshopTime(DateTime.parse('2026-11-20T18:00:00Z')).day, 21);
  });
}
