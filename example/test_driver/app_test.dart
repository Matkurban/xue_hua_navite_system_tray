import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

Future<String> treeText(FlutterDriver driver) async {
  final RenderTree rt = await driver.getRenderTree();
  return rt.tree ?? '';
}

Future<void> tapText(
  FlutterDriver driver,
  String text, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final SerializableFinder finder = find.text(text);
  await driver.waitFor(finder, timeout: timeout);
  await driver.tap(finder);
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

Future<void> tapKey(
  FlutterDriver driver,
  String key, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final SerializableFinder finder = find.byValueKey(key);
  await driver.waitFor(finder, timeout: timeout);
  await driver.tap(finder);
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

void main() {
  late FlutterDriver driver;
  final StringBuffer log = StringBuffer();

  setUpAll(() async {
    driver = await FlutterDriver.connect(printCommunication: false);
    await driver.waitFor(
      find.text('XueHua Native System Tray Workbench'),
      timeout: const Duration(seconds: 90),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(await driver.requestData('ping'), 'pong');
    log.writeln('Connected to example workbench.');
  });

  tearDownAll(() async {
    final File out = File('/tmp/tray-flutter-driver-ui-log.txt');
    await out.writeAsString(log.toString());
    await driver.close();
  });

  test('chrome: tray active after auto-init', () async {
    await driver.waitFor(
      find.text('Tray Active'),
      timeout: const Duration(seconds: 30),
    );
    await driver.waitFor(find.text('Platform Backend & Runtime Capabilities'));
    final String caps = await driver.requestData('caps');
    expect(caps.toLowerCase(), contains('linux'));
    expect(caps.toLowerCase(), contains('ayatana'));
    final String tree = await treeText(driver);
    expect(tree.contains('Backend:'), isTrue);
    log.writeln('PASS: chrome + caps via requestData ($caps)');
  });

  test('lifecycle UI: hide/show tray + destroy/reinit', () async {
    await tapKey(driver, 'btn_toggle_tray_visible');
    await driver.waitFor(find.text('Show Tray'));
    await tapKey(driver, 'btn_toggle_tray_visible');
    await driver.waitFor(find.text('Hide Tray'));

    await tapKey(driver, 'btn_destroy_tray');
    await driver.waitFor(
      find.text('Tray Inactive'),
      timeout: const Duration(seconds: 15),
    );
    await tapKey(driver, 'btn_init_tray');
    await driver.waitFor(
      find.text('Tray Active'),
      timeout: const Duration(seconds: 20),
    );
    log.writeln('PASS: UI lifecycle hide/show/destroy/reinit');
  });

  test('icons UI chips + requestData asset/bytes', () async {
    await tapText(driver, 'System Default Icon');
    await tapText(driver, 'Local Asset Icon (tray_logo.png)');
    await tapText(driver, 'System Alert / Bolt');
    await tapText(driver, 'In-Memory Badge (XH)');
    expect(await driver.requestData('setAssetIcon'), 'ok');
    expect(await driver.requestData('setBytesIcon'), 'ok');
    final String tree = await treeText(driver);
    expect(
      tree.contains('Switched to') || tree.contains('Applied in-memory'),
      isTrue,
    );
    log.writeln('PASS: icon chips + requestData icons');
  });

  test('requestData: title tooltip menu popup', () async {
    expect(await driver.requestData('setTitle'), 'ok');
    expect(await driver.requestData('setToolTip'), 'ok');
    expect(await driver.requestData('updateSyncLabel'), 'ok');
    expect(await driver.requestData('rebuildMenu'), 'ok');
    expect(await driver.requestData('popUpMenu'), 'ok');
    log.writeln('PASS: title/tooltip/menu via requestData');
  });

  test('requestData: window hide/show cycle', () async {
    expect(await driver.requestData('isWindowVisible'), 'true');
    expect(await driver.requestData('hideWindow'), 'ok');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await driver.requestData('isWindowVisible'), 'false');
    expect(await driver.requestData('showWindow'), 'ok');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await driver.requestData('isWindowVisible'), 'true');

    // Repeat once more to catch re-entrancy / double-toggle issues.
    expect(await driver.requestData('hideWindow'), 'ok');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(await driver.requestData('isWindowVisible'), 'false');
    expect(await driver.requestData('showWindow'), 'ok');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(await driver.requestData('isWindowVisible'), 'true');
    log.writeln('PASS: window hide/show via requestData (double cycle)');
  });

  test('requestData: notify + bounds', () async {
    final String notified = await driver.requestData('notify');
    expect(notified == 'true' || notified == 'false', isTrue);
    final String bounds = await driver.requestData('queryBounds');
    // AppIndicator often returns null bounds.
    expect(bounds.isNotEmpty, isTrue);
    log.writeln('PASS: notify=$notified bounds=$bounds');
  });
}
