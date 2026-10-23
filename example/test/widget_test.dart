import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_system_tray_example/main.dart';

void main() {
  testWidgets('Verify SystemTrayExampleApp renders workbench UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SystemTrayExampleApp());
    expect(
      find.text('XueHua Native System Tray Workbench'),
      findsOneWidget,
    );
    expect(
      find.text('1. Lifecycle, Icons, Inline Title & Tooltip'),
      findsOneWidget,
    );
  });
}
