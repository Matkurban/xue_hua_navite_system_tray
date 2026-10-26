import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('asset and bytes icons apply without throwing', (tester) async {
    final tray = XueHuaNaviteSystemTray.instance;
    final ok = await tray.initSystemTray(TrayConfig(
      icon: const TrayIconSource.system('applications-system'),
      title: 'IconTest',
      toolTip: 'IconTest',
      menuItems: [
        TrayMenuItem.action(
          id: 'with_asset',
          label: 'With Asset Icon',
          icon: const TrayIconSource.asset('assets/icons/menu_star.png', iconSize: 16),
          onTap: () {},
        ),
      ],
    ));
    expect(ok, isTrue);

    await tray.setIcon(const TrayIconSource.asset(
      'assets/icons/tray_logo.png',
      iconSize: 18,
    ));

    // Generate tiny PNG bytes
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 16, 16), ui.Paint()..color = const ui.Color(0xFF00FF00));
    final img = await recorder.endRecording().toImage(16, 16);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = bd!.buffer.asUint8List();
    await tray.setIcon(TrayIconSource.bytes(Uint8List.fromList(bytes), iconSize: 16));

    await tray.setIcon(const TrayIconSource.system('dialog-warning'));
    await tray.destroy();
  });
}
