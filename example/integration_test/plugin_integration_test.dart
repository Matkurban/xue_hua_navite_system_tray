import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initSystemTray and getCapabilities integration test', (
    WidgetTester tester,
  ) async {
    final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;
    final TrayCapabilities capabilities = await tray.getCapabilities();
    expect(capabilities.platform.isNotEmpty, isTrue);

    final bool initialized = await tray.initSystemTray(
      const TrayConfig(
        icon: TrayIconSource.system('sparkles', isTemplate: true),
        title: 'Test',
        toolTip: 'Integration Test Tray',
      ),
    );
    expect(initialized, isTrue);
    await tray.destroy();
  });
}
