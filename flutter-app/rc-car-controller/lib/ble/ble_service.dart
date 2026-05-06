import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  bool isConnected = false;
  bool isScanning = false;
  bool isReconnecting = false;
  bool isBusy = false;
  bool isConnecting = false;

  Timer? heartbeatTimer;
  Timer? reconnectTimer;

  final String deviceName = "RC_CAR";

  final Guid charUUID =
      Guid("abcd1234-5678-1234-5678-abcdef123456");

  StreamSubscription<List<ScanResult>>? scanSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;

  late VoidCallback onUpdate;

  String? _lastCmd;
  int _lastSpeed = -999;
  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);

  // ================= INIT =================
  void init(VoidCallback update) {
    onUpdate = update;

    scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (isBusy || isConnecting) return;

      for (var r in results) {
        if (r.device.platformName != deviceName) continue;

        isBusy = true;
        isConnecting = true;

        await FlutterBluePlus.stopScan();
        isScanning = false;

        device = r.device;

        try {
          await device!.connect(timeout: const Duration(seconds: 10));
        } catch (_) {}

        await stateSub?.cancel();

        stateSub = device!.connectionState.listen((state) async {
          if (state == BluetoothConnectionState.connected) {
            if (isConnected) return;

            isConnected = true;
            isConnecting = false;
            onUpdate();

            await Future.delayed(const Duration(milliseconds: 800));

            await _discover();

            startHeartbeat();
            stopReconnect();

            isBusy = false;
          }

          if (state == BluetoothConnectionState.disconnected) {
            if (!isConnected) return;

            isConnected = false;
            isConnecting = false;

            device = null;
            characteristic = null;

            heartbeatTimer?.cancel();

            onUpdate();

            isBusy = false;

            Future.delayed(const Duration(seconds: 2), () {
              startReconnect();
            });
          }
        });

        return;
      }
    });

    startReconnect();
  }

  // ================= DISCOVER =================
  Future<void> _discover() async {
    if (device == null) return;

    final services = await device!.discoverServices();

    for (var s in services) {
      for (var c in s.characteristics) {
        debugPrint("UUID: ${c.uuid}");
        debugPrint("write: ${c.properties.write}");
        debugPrint("writeWithoutResponse: ${c.properties.writeWithoutResponse}");
        
        if (c.uuid == charUUID) {
          characteristic = c;
        }
      }
    }
  }

  // ================= RECONNECT =================
  void startReconnect() {
    if (isReconnecting) return;

    isReconnecting = true;

    reconnectTimer?.cancel();

    reconnectTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        if (isConnected || isBusy || isConnecting) return;

        final state = await FlutterBluePlus.adapterState.first;
        if (state != BluetoothAdapterState.on) return;

        await scanAndConnect();
      },
    );
  }

  void stopReconnect() {
    reconnectTimer?.cancel();
    isReconnecting = false;
  }

  // ================= SCAN =================
  Future<void> scanAndConnect() async {
    if (isScanning) return;

    isScanning = true;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    Future.delayed(const Duration(seconds: 5), () {
      isScanning = false;
    });
  }

  // ================= HEARTBEAT =================
  void startHeartbeat() {
    heartbeatTimer?.cancel();

    heartbeatTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) async {
        if (!isConnected || characteristic == null) return;

        try {
          await characteristic!.write(
            "H".codeUnits,
            withoutResponse: true,
          );
        } catch (_) {}
      },
    );
  }

  // ================= SEND =================
  Future<void> sendCommand(String cmd) async {
    if (characteristic == null) return;

    if(cmd != "V0"){
      final now = DateTime.now();

      // 🔥 limit 25Hz
      if (now.difference(_lastSend).inMilliseconds < 40) return;

      _lastSend = now;
    }

    // ignoruj mikro-zmiany
    if (cmd.startsWith("V")) {
      final value = int.tryParse(cmd.substring(1)) ?? -1;

      if ((value - _lastSpeed).abs() < 2) return;

      _lastSpeed = value;
    }

    if (_lastCmd == cmd) return;
    _lastCmd = cmd;

    try {
      await characteristic!.write(
        cmd.codeUnits, 
        withoutResponse: true
      );
    } catch (_) {}
  }

  // ================= DISPOSE =================
  void dispose() {
    scanSub?.cancel();
    stateSub?.cancel();
    heartbeatTimer?.cancel();
    reconnectTimer?.cancel();
  }
}