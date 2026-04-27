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
      Guid("12345678-1234-1234-1234-123456789abd");

  StreamSubscription<List<ScanResult>>? scanSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;

  late VoidCallback onUpdate;

  // ================= INIT =================
  void init(VoidCallback update) {
    onUpdate = update;

    scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (isBusy || isConnecting) return;

      for (var r in results) {
        if (r.device.platformName != deviceName) continue;

        print("📡 FOUND RC_CAR");

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

            print("🟢 CONNECTED");

            isConnected = true;
            isConnecting = false;
            onUpdate();

            await Future.delayed(const Duration(milliseconds: 1200));

            await _discover();

            startHeartbeat();
            stopReconnect();

            isBusy = false;

            print("✅ READY");
          }

          if (state == BluetoothConnectionState.disconnected) {
            if (!isConnected) return;

            print("🔴 DISCONNECTED");

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

    print("=== DISCOVER ===");

    try {
      final services = await device!.discoverServices();

      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.uuid == charUUID) {
            characteristic = c;
            print("✅ CHARACTERISTIC FOUND");
          }
        }
      }
    } catch (e) {
      print("DISCOVER ERROR: $e");
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

        print("🔁 RECONNECT SCAN...");
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

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      print("SCAN ERROR: $e");
    }

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
          await characteristic!.write("H".codeUnits);
        } catch (e) {
          print("HEARTBEAT ERROR: $e");
        }
      },
    );
  }

  // ================= SEND =================
  Future<void> sendCommand(String cmd) async {
    if (characteristic == null) return;

    try {
      await characteristic!.write(cmd.codeUnits);
    } catch (e) {
      print("SEND ERROR: $e");
    }
  }

  // ================= DISPOSE =================
  void dispose() {
    scanSub?.cancel();
    stateSub?.cancel();
    heartbeatTimer?.cancel();
    reconnectTimer?.cancel();
  }
}