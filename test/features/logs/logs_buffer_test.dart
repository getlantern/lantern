import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/logs/logs.dart';

void main() {
  test('latestLogsForDisplay keeps all lines when under cap', () {
    const logs = <String>['line-1', 'line-2'];

    final visible = latestLogsForDisplay(logs);

    expect(visible, same(logs));
  });

  test('latestLogsForDisplay keeps only most recent lines when over cap', () {
    final logs = List<String>.generate(805, (index) => 'line-$index');

    final visible = latestLogsForDisplay(logs);

    expect(visible.length, 800);
    expect(visible.first, 'line-5');
    expect(visible.last, 'line-804');
  });
}
