import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SystemTrayExampleApp());
}

/// Comprehensive desktop example application demonstrating all features of
/// `xue_hua_navite_system_tray` across macOS, Windows, and Linux.
class SystemTrayExampleApp extends StatelessWidget {
  const SystemTrayExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XueHua Native System Tray Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SystemTrayDashboardPage(),
    );
  }
}

class SystemTrayDashboardPage extends StatefulWidget {
  const SystemTrayDashboardPage({super.key});

  @override
  State<SystemTrayDashboardPage> createState() =>
      _SystemTrayDashboardPageState();
}

class _SystemTrayDashboardPageState extends State<SystemTrayDashboardPage> {
  final XueHuaNaviteSystemTray _tray = XueHuaNaviteSystemTray.instance;
  StreamSubscription<TrayEvent>? _eventSubscription;
  Timer? _liveMonitorTimer;

  TrayCapabilities? _capabilities;
  TrayBounds? _lastBounds;
  bool _isTrayInitialized = false;
  bool _isTrayVisible = true;
  bool _isDockVisible = true;
  bool _autoSyncEnabled = true;
  bool _liveMetricsEnabled = false;
  String _selectedMode = 'balanced';
  int _syncCounter = 0;

  TrayMenuTrigger _menuTrigger = TrayMenuTrigger.rightClick;
  TrayImagePosition _imagePosition = TrayImagePosition.leading;

  final TextEditingController _titleController = TextEditingController(
    text: 'XueHua',
  );
  final TextEditingController _toolTipController = TextEditingController(
    text: 'XueHua Native System Tray • Ready',
  );
  final TextEditingController _notifTitleController = TextEditingController(
    text: 'XueHua System Tray',
  );
  final TextEditingController _notifBodyController = TextEditingController(
    text: 'Background workspace synchronization finished.',
  );
  TrayNotificationIconType _notifIconType = TrayNotificationIconType.info;

  final List<String> _eventLogs = <String>[];

  @override
  void initState() {
    super.initState();
    _eventSubscription = _tray.events.listen(_onTrayEvent);
    _initializeTrayAndCapabilities();
  }

  @override
  void dispose() {
    _liveMonitorTimer?.cancel();
    _eventSubscription?.cancel();
    _titleController.dispose();
    _toolTipController.dispose();
    _notifTitleController.dispose();
    _notifBodyController.dispose();
    super.dispose();
  }

  void _appendLog(String message) {
    if (!mounted) return;
    final String time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _eventLogs.insert(0, '[$time] $message');
      if (_eventLogs.length > 80) {
        _eventLogs.removeLast();
      }
    });
  }

  void _onTrayEvent(TrayEvent event) {
    _appendLog(
      'Event: ${event.type.name} | button=${event.mouseButton.name} '
      '${event.menuItemId != null ? "| item=${event.menuItemId}" : ""} '
      '${event.checked != null ? "| checked=${event.checked}" : ""}',
    );
    if (event.bounds != null && mounted) {
      setState(() {
        _lastBounds = event.bounds;
      });
    }

    // Automatically toggle or restore window on left double-click.
    if (event.type == TrayEventType.leftDoubleClick) {
      _tray.showMainWindow(focus: true);
    }
  }

  TrayIconSource _defaultPlatformIcon() {
    if (Platform.isMacOS) {
      return const TrayIconSource.system('sparkles', isTemplate: true);
    } else if (Platform.isWindows) {
      return const TrayIconSource.system('application');
    } else {
      return const TrayIconSource.system('applications-system');
    }
  }

  List<TrayMenuItem> _buildDefaultContextMenu() {
    return <TrayMenuItem>[
      const TrayMenuItem.header(
        id: 'header_workspace',
        label: 'XueHua Workspace',
      ),
      TrayMenuItem.action(
        id: 'show_window',
        label: 'Show Main Window',
        toolTip: 'Bring the main application window to front',
        icon: Platform.isMacOS
            ? const TrayIconSource.system('macwindow', isTemplate: true)
            : Platform.isWindows
            ? const TrayIconSource.system('application')
            : null,
        shortcut: const TrayMenuShortcut('o', meta: true),
        onTap: () async {
          await _tray.showMainWindow(focus: true);
          _appendLog('Action callback: Show Main Window');
        },
      ),
      TrayMenuItem.action(
        id: 'hide_window',
        label: 'Minimize to System Tray',
        icon: Platform.isMacOS
            ? const TrayIconSource.system('eye.slash', isTemplate: true)
            : null,
        shortcut: const TrayMenuShortcut('h', meta: true),
        onTap: () async {
          await _tray.hideMainWindow();
          _appendLog('Action callback: Minimize to System Tray');
        },
      ),
      const TrayMenuItem.separator(),
      TrayMenuItem.action(
        id: 'sync_now',
        label: 'Sync Now ($_syncCounter)',
        icon: Platform.isMacOS
            ? const TrayIconSource.system('arrow.clockwise', isTemplate: true)
            : Platform.isWindows
            ? const TrayIconSource.system('info')
            : null,
        shortcut: const TrayMenuShortcut('r', meta: true),
        onTap: _triggerManualSync,
      ),
      TrayMenuItem.checkbox(
        id: 'auto_sync',
        label: 'Auto-Sync in Background',
        checked: _autoSyncEnabled,
        onChanged: (bool checked) {
          setState(() {
            _autoSyncEnabled = checked;
          });
          _appendLog('Checkbox callback: Auto-Sync = $checked');
        },
      ),
      TrayMenuItem.submenu(
        id: 'submenu_mode',
        label: 'Performance Profile',
        icon: Platform.isMacOS
            ? const TrayIconSource.system('speedometer', isTemplate: true)
            : null,
        children: <TrayMenuItem>[
          TrayMenuItem.radio(
            id: 'mode_eco',
            groupId: 'perf_mode',
            label: 'Eco Mode (Low Power)',
            checked: _selectedMode == 'eco',
            onTap: () => _selectPerformanceMode('eco'),
          ),
          TrayMenuItem.radio(
            id: 'mode_balanced',
            groupId: 'perf_mode',
            label: 'Balanced Mode',
            checked: _selectedMode == 'balanced',
            onTap: () => _selectPerformanceMode('balanced'),
          ),
          TrayMenuItem.radio(
            id: 'mode_turbo',
            groupId: 'perf_mode',
            label: 'Turbo Mode (Max Throughput)',
            checked: _selectedMode == 'turbo',
            onTap: () => _selectPerformanceMode('turbo'),
          ),
        ],
      ),
      const TrayMenuItem.separator(),
      TrayMenuItem.action(
        id: 'send_notification',
        label: 'Send Test Notification',
        icon: Platform.isMacOS
            ? const TrayIconSource.system('bell', isTemplate: true)
            : Platform.isWindows
            ? const TrayIconSource.system('warning')
            : null,
        onTap: _sendTrayNotification,
      ),
      const TrayMenuItem.separator(),
      TrayMenuItem.action(
        id: 'destroy_tray',
        label: 'Remove System Tray Icon',
        icon: Platform.isMacOS
            ? const TrayIconSource.system('trash', isTemplate: true)
            : Platform.isWindows
            ? const TrayIconSource.system('error')
            : null,
        shortcut: const TrayMenuShortcut('q', meta: true, shift: true),
        onTap: _destroyTray,
      ),
    ];
  }

  Future<void> _initializeTrayAndCapabilities() async {
    try {
      final TrayCapabilities caps = await _tray.getCapabilities();
      final bool ok = await _tray.initSystemTray(
        TrayConfig(
          icon: _defaultPlatformIcon(),
          title: _titleController.text,
          toolTip: _toolTipController.text,
          visible: _isTrayVisible,
          menuTrigger: _menuTrigger,
          imagePosition: _imagePosition,
          menuItems: _buildDefaultContextMenu(),
        ),
      );
      final TrayBounds? bounds = await _tray.getBounds();

      if (!mounted) return;
      setState(() {
        _capabilities = caps;
        _isTrayInitialized = ok;
        _lastBounds = bounds;
      });
      _appendLog('System tray initialized (backend: ${caps.backendName})');
    } catch (e) {
      _appendLog('Initialization error: $e');
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() {
      _syncCounter++;
    });
    await _tray.updateMenuItem(
      'sync_now',
      label: 'Sync Now ($_syncCounter)',
    );
    _appendLog('Updated menu item "sync_now" in-place (count: $_syncCounter)');
  }

  void _selectPerformanceMode(String mode) {
    setState(() {
      _selectedMode = mode;
    });
    _appendLog('Selected radio performance profile: $mode');
  }

  /// Generates a crisp 36x36 PNG badge icon in memory using `dart:ui` Canvas
  /// and applies it to the system tray via [TrayIconSource.bytes].
  Future<void> _applyGeneratedBadgeIcon(Color color, String badgeText) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double size = 36.0;

    final Paint bgPaint = Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, size - 4, size - 4),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );

    final ui.Image img = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? pngBytes = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (pngBytes != null) {
      final Uint8List uint8List = pngBytes.buffer.asUint8List();
      await _tray.setIcon(
        TrayIconSource.bytes(uint8List, isTemplate: false, iconSize: 18.0),
      );
      _appendLog('Applied in-memory PNG icon ($badgeText)');
    }
  }

  Future<void> _toggleLiveMetrics(bool enabled) async {
    _liveMonitorTimer?.cancel();
    setState(() {
      _liveMetricsEnabled = enabled;
    });
    if (enabled) {
      int tick = 0;
      _liveMonitorTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        tick++;
        final int cpu = 18 + (tick * 7) % 45;
        await _tray.setTitle('CPU $cpu%');
      });
      _appendLog('Started live inline title monitor');
    } else {
      await _tray.setTitle(_titleController.text);
      _appendLog('Stopped live inline title monitor');
    }
  }

  Future<void> _sendTrayNotification() async {
    final bool sent = await _tray.showNotification(
      TrayNotification(
        title: _notifTitleController.text,
        message: _notifBodyController.text,
        iconType: _notifIconType,
      ),
    );
    _appendLog('showNotification result: $sent');
  }

  Future<void> _refreshBounds() async {
    final TrayBounds? bounds = await _tray.getBounds();
    setState(() {
      _lastBounds = bounds;
    });
    _appendLog('Queried tray bounds: $bounds');
  }

  Future<void> _destroyTray() async {
    await _tray.destroy();
    if (!mounted) return;
    setState(() {
      _isTrayInitialized = false;
    });
    _appendLog('System tray destroyed');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('XueHua Native System Tray Workbench'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              avatar: Icon(
                _isTrayInitialized ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: _isTrayInitialized ? Colors.green : Colors.grey,
              ),
              label: Text(
                _isTrayInitialized ? 'Tray Active' : 'Tray Inactive',
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildCapabilitiesCard(colors),
                const SizedBox(height: 16),
                _buildLifecycleAndAppearanceCard(),
                const SizedBox(height: 16),
                _buildTriggerAndMenuCard(),
                const SizedBox(height: 16),
                _buildWindowAndNotificationCard(),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: _buildEventLogPanel(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesCard(ColorScheme colors) {
    final TrayCapabilities? caps = _capabilities;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.layers_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Platform Backend & Runtime Capabilities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _refreshBounds,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Query Bounds'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (caps == null)
              const Text('Loading platform capabilities...')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _capabilityBadge('OS: ${caps.platform}', true),
                  _capabilityBadge('Backend: ${caps.backendName}', true),
                  _capabilityBadge('Inline Title', caps.supportsInlineTitle),
                  _capabilityBadge('Template Icon', caps.supportsTemplateIcon),
                  _capabilityBadge('System Symbol', caps.supportsSystemSymbol),
                  _capabilityBadge('Icon Bounds', caps.supportsIconBounds),
                  _capabilityBadge('Double Click', caps.supportsDoubleClick),
                  _capabilityBadge('Middle Click', caps.supportsMiddleClick),
                  _capabilityBadge('Menu Icons', caps.supportsMenuIcons),
                  _capabilityBadge(
                    'Dock Toggle',
                    caps.supportsDockVisibilityToggle,
                  ),
                  _capabilityBadge(
                    'Notifications',
                    caps.supportsTrayNotification,
                  ),
                ],
              ),
            if (_lastBounds != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Tray Icon Screen Bounds: $_lastBounds',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _capabilityBadge(String label, bool supported) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        supported ? Icons.check : Icons.info_outline,
        size: 15,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildLifecycleAndAppearanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '1. Lifecycle, Icons, Inline Title & Tooltip',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _initializeTrayAndCapabilities,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Init / Reset Tray'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final bool next = !_isTrayVisible;
                    await _tray.setVisible(next);
                    setState(() => _isTrayVisible = next);
                    _appendLog('setVisible($next)');
                  },
                  icon: Icon(
                    _isTrayVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(_isTrayVisible ? 'Hide Tray' : 'Show Tray'),
                ),
                OutlinedButton.icon(
                  onPressed: _destroyTray,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Destroy Tray'),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Switch Icon Source (System Symbol & In-Memory PNG):'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('System Default Icon'),
                  onPressed: () async {
                    await _tray.setIcon(_defaultPlatformIcon());
                    _appendLog('Switched to platform system icon');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.bolt, size: 16),
                  label: const Text('System Alert / Bolt'),
                  onPressed: () async {
                    final TrayIconSource icon = Platform.isMacOS
                        ? const TrayIconSource.system(
                            'bolt.fill',
                            isTemplate: true,
                          )
                        : Platform.isWindows
                        ? const TrayIconSource.system('warning')
                        : const TrayIconSource.system('dialog-warning');
                    await _tray.setIcon(icon);
                    _appendLog('Switched to warning/bolt system icon');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.looks_one, size: 16),
                  label: const Text('In-Memory Badge (XH)'),
                  onPressed: () =>
                      _applyGeneratedBadgeIcon(const Color(0xFF2563EB), 'XH'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.notifications_active, size: 16),
                  label: const Text('In-Memory Badge (9+)'),
                  onPressed: () =>
                      _applyGeneratedBadgeIcon(const Color(0xFFDC2626), '9+'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Inline Title (macOS & Linux AppIndicator)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    await _tray.setTitle(_titleController.text);
                    _appendLog('setTitle("${_titleController.text}")');
                  },
                  child: const Text('Update Title'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live CPU Metric Ticker in Status Bar'),
              subtitle: const Text(
                'Updates inline status bar text every second',
              ),
              value: _liveMetricsEnabled,
              onChanged: _toggleLiveMetrics,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _toolTipController,
                    decoration: const InputDecoration(
                      labelText: 'Hover Tooltip Text',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    await _tray.setToolTip(_toolTipController.text);
                    _appendLog('setToolTip("${_toolTipController.text}")');
                  },
                  child: const Text('Update Tooltip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerAndMenuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '2. Context Menu, Click Trigger & Dynamic Item Updates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<TrayMenuTrigger>(
                    initialValue: _menuTrigger,
                    decoration: const InputDecoration(
                      labelText: 'Menu Click Trigger Mode',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: TrayMenuTrigger.values.map((TrayMenuTrigger t) {
                      return DropdownMenuItem<TrayMenuTrigger>(
                        value: t,
                        child: Text(t.name),
                      );
                    }).toList(),
                    onChanged: (TrayMenuTrigger? next) async {
                      if (next == null) return;
                      setState(() => _menuTrigger = next);
                      await _tray.setMenuTrigger(
                        next,
                        imagePosition: _imagePosition,
                      );
                      _appendLog('setMenuTrigger(${next.name})');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TrayImagePosition>(
                    initialValue: _imagePosition,
                    decoration: const InputDecoration(
                      labelText: 'Icon Position (macOS)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: TrayImagePosition.values.map((TrayImagePosition p) {
                      return DropdownMenuItem<TrayImagePosition>(
                        value: p,
                        child: Text(p.name),
                      );
                    }).toList(),
                    onChanged: (TrayImagePosition? next) async {
                      if (next == null) return;
                      setState(() => _imagePosition = next);
                      await _tray.setMenuTrigger(
                        _menuTrigger,
                        imagePosition: next,
                      );
                      _appendLog('setImagePosition(${next.name})');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await _tray.popUpContextMenu();
                    _appendLog('Called popUpContextMenu()');
                  },
                  icon: const Icon(Icons.menu_open),
                  label: const Text('Pop Up Menu Now'),
                ),
                OutlinedButton.icon(
                  onPressed: _triggerManualSync,
                  icon: const Icon(Icons.sync),
                  label: Text('Increment Sync Item ($_syncCounter)'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _tray.setContextMenu(_buildDefaultContextMenu());
                    _appendLog('Rebuilt full context menu tree');
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rebuild Context Menu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowAndNotificationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '3. Window Control, Dock Visibility & Tray Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    await _tray.hideMainWindow();
                    _appendLog(
                      'Hid main window (use Tray Menu -> Show Main Window to restore)',
                    );
                  },
                  icon: const Icon(Icons.minimize),
                  label: const Text('Minimize Window to Tray'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _tray.showMainWindow(focus: true);
                    _appendLog('Restored and focused main window');
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Show & Focus Main Window'),
                ),
                if (Platform.isMacOS)
                  FilterChip(
                    selected: _isDockVisible,
                    label: const Text('macOS Dock Icon Visible'),
                    onSelected: (bool value) async {
                      await _tray.setDockIconVisible(value);
                      setState(() => _isDockVisible = value);
                      _appendLog('setDockIconVisible($value)');
                    },
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _notifTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<TrayNotificationIconType>(
                  value: _notifIconType,
                  items: TrayNotificationIconType.values.map((
                    TrayNotificationIconType type,
                  ) {
                    return DropdownMenuItem<TrayNotificationIconType>(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (TrayNotificationIconType? val) {
                    if (val != null) {
                      setState(() => _notifIconType = val);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _notifBodyController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Message',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sendTrayNotification,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Notify'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLogPanel(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Row(
            children: <Widget>[
              const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Live Tray Event Stream (${_eventLogs.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(_eventLogs.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _eventLogs.isEmpty
              ? const Center(
                  child: Text(
                    'Click the system tray icon or select menu items\nto inspect real-time native events here.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _eventLogs.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    return Text(
                      _eventLogs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
