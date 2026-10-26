import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_system_tray_example/main.dart';

void main() {
  testWidgets('Verify SystemTrayExampleApp renders workbench UI', (
    WidgetTester tester,
  ) async {
    // Match a typical desktop window; the workbench is a two-pane layout.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SystemTrayExampleApp());
    await tester.pumpAndSettle();
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
