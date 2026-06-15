import 'package:flutter_test/flutter_test.dart';

import 'package:localfind/main.dart';

void main() {
  testWidgets('LocalFind app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const LocalFindApp());
    expect(find.text('LocalFind'), findsOneWidget);
  });
}
