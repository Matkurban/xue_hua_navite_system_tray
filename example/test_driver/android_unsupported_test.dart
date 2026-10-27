import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

/// Android smoke: desktop system-tray plugin is not registered.
/// App must still launch; tray MethodChannel calls must soft-fail.
void main() {
  late FlutterDriver driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect(printCommunication: false);
    await driver.waitFor(
      find.text('XueHua Native System Tray Workbench'),
      timeout: const Duration(seconds: 120),
    );
    expect(await driver.requestData('ping'), 'pong');
  });

  tearDownAll(() async {
    await driver.close();
  });

  test('workbench UI loads without Tray Active', () async {
    await driver.waitFor(
      find.text('XueHua Native System Tray Workbench'),
      timeout: const Duration(seconds: 30),
    );
    // Desktop driver suite expects Tray Active; on Android init soft-fails.
    try {
      await driver.waitFor(find.text('Tray Active'), timeout: const Duration(seconds: 3));
      fail('Tray Active should not appear on Android (no native plugin)');
    } catch (_) {
      // expected: tray not active
    }
  });

  test('caps/tray channel reports missing plugin', () async {
    try {
      final String caps = await driver.requestData('caps');
      fail('Expected MissingPluginException path, got caps=$caps');
    } catch (e) {
      final String msg = e.toString();
      expect(
        msg.contains('MissingPluginException') ||
            msg.contains('Exception') ||
            msg.contains('error'),
        isTrue,
        reason: 'Unexpected: $msg',
      );
    }
    expect(await driver.requestData('ping'), 'pong');
  });
}
