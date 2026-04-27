import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  bool isConnected = false;

  final String deviceName = "RC_CAR";

  final Guid serviceUUID =
    Guid("12345678-1234-1234-1234-123456789abc");

  final Guid charUUID =
    Guid("12345678-1234-1234-1234-123456789abd");

  StreamSubscription<List<ScanResult>>? scanSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;

  Timer? heartbeatTimer;

  // 🔥 INIT (start listener)
  void init(VoidCallback onUpdate) {
  scanSub = FlutterBluePlus.scanResults.listen((results) async {
    for (var r in results) {
      final name = r.device.platformName;

      if (name == deviceName && r.rssi > -90) {
        await FlutterBluePlus.stopScan();

        device = r.device;

        try {
          await device!.connect(timeout: const Duration(seconds: 10));
        } catch (_) {}

        await stateSub?.cancel();

        stateSub = device!.connectionState.listen((state) async {
          if (state == BluetoothConnectionState.connected) {
            print("🟢 CONNECTED");

            await discoverServices();

            if (characteristic != null) {
              isConnected = true;
              startHeartbeat();

              print("✅ READY (CHAR + HEARTBEAT)");
            } else {
              print("❌ NO CHARACTERISTIC");
            }

            onUpdate();
          }

          if (state == BluetoothConnectionState.disconnected) {
            print("🔴 DISCONNECTED");

            isConnected = false;
            device = null;
            characteristic = null;

            heartbeatTimer?.cancel();

            onUpdate();
          }
        });

        return;
      }
    }
  });
}

  // 🔥 PERMISSIONS
  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // 🔥 SCAN
  Future<void> scanAndConnect() async {
    await requestPermissions();

    await FlutterBluePlus.stopScan();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );
  }

  // 🔥 DISCOVER
  Future<void> discoverServices() async {
    if (device == null) return;

    final services = await device!.discoverServices();

    for (var s in services) {
    if (s.uuid == serviceUUID) {
        for (var c in s.characteristics) {
        if (c.uuid == charUUID) {
            characteristic = c;
        }
        }
    }
    }

    if (characteristic != null) {
    print("✅ CHARACTERISTIC FOUND");
    } else {
    print("❌ CHARACTERISTIC NOT FOUND");
    }
  }

  // 🔥 HEARTBEAT
  void startHeartbeat() {
    heartbeatTimer?.cancel();

    heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (characteristic == null) return;
      if (!isConnected) return;

      try {
        await characteristic!.write(
          "H".codeUnits,
          withoutResponse: false,
        );
      } catch (_) {}
    });
  }

  // 🔥 COMMAND
  Future<void> sendCommand(String cmd) async {
    if (characteristic == null) return;

    await characteristic!.write(
      cmd.codeUnits,
      withoutResponse: false,
    );
  }

  // 🔥 CLEANUP
  void dispose() {
    scanSub?.cancel();
    stateSub?.cancel();
    heartbeatTimer?.cancel();
  }
}