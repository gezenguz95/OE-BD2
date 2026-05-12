import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDisconnectFlag = 'obd_disconnect_requested';
const _kNotifId        = 1;
const _kChannelId      = 'obd_connection';
const _kAlertChannelId = 'obd_alerts';
const _kAlertIds = <String, int>{'soc': 2, 'temp': 3, 'cell': 4};

@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) async {
  if (response.actionId == 'disconnect') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisconnectFlag, true);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String _currentDevice = 'OBD-II';
  String _lastDisconnectLabel = 'Disconnect';

  final _disconnectCtrl = StreamController<void>.broadcast();
  Stream<void> get onDisconnectRequested => _disconnectCtrl.stream;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
    _initialized = true;
  }

  void _onForegroundAction(NotificationResponse response) {
    if (response.actionId == 'disconnect') {
      _disconnectCtrl.add(null);
    }
  }

  Future<void> show({
    required String deviceName,
    double soc = 0,
    String status = 'Connected',
    String disconnectLabel = 'Disconnect',
  }) async {
    await init();
    _currentDevice = deviceName;
    _lastDisconnectLabel = disconnectLabel;

    final body = soc > 0
        ? '$status  •  SOC: ${soc.toStringAsFixed(0)}%'
        : status;

    final details = AndroidNotificationDetails(
      _kChannelId,
      'OBD connection',
      channelDescription: 'Active OBD-II connection status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      color: const Color(0xFF42A5F5),
      actions: [
        AndroidNotificationAction(
          'disconnect',
          disconnectLabel,
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    );

    await _plugin.show(
      _kNotifId,
      deviceName,
      body,
      NotificationDetails(android: details),
    );
  }

  Future<void> update({double soc = 0, String status = 'Connected'}) =>
      show(deviceName: _currentDevice, soc: soc, status: status,
           disconnectLabel: _lastDisconnectLabel);

  Future<void> dismiss() async {
    await init();
    await _plugin.cancel(_kNotifId);
  }

  Future<void> showAlert({
    required String type,
    required String title,
    required String body,
  }) async {
    await init();
    final id = _kAlertIds[type] ?? 9;
    final details = AndroidNotificationDetails(
      _kAlertChannelId,
      'OBD riasztások',
      channelDescription: 'Akkumulátor és szenzor küszöb-riasztások',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: false,
      showWhen: true,
      color: const Color(0xFFEF5350),
    );
    await _plugin.show(id, title, body, NotificationDetails(android: details));
  }

  Future<void> dismissAlert(String type) async {
    await init();
    await _plugin.cancel(_kAlertIds[type] ?? 9);
  }

  Future<bool> checkAndClearDisconnectFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(_kDisconnectFlag) ?? false;
    if (flag) await prefs.remove(_kDisconnectFlag);
    return flag;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  void dispose() => _disconnectCtrl.close();
}
