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

  // ================= INIT =================
  void init(VoidCallback update) {
    FlutterBluePlus.stopScan().catchError((_) {});

    onUpdate = update;

    scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (isBusy || isConnecting) return;

      for (var r in results) {
        if (r.device.platformName != deviceName) continue;

        if (isConnecting || isBusy || isConnected) return;

        isBusy = true;
        isConnecting = true;

        await FlutterBluePlus.stopScan();
        isScanning = false;

        device = r.device;

        try {
          await Future.delayed(const Duration(milliseconds: 200)); // 🔥 stabilizacja
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
        if (c.uuid == charUUID) {
          debugPrint("UUID: ${c.uuid} write: ${c.properties.write} writeWithoutResponse: ${c.properties.writeWithoutResponse}");
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
    if (isScanning || isBusy || isConnecting || isConnected) return;

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
          await characteristic!.write([0x01], withoutResponse: true);
        } catch (_) {}
      },
    );
  }

  Future<void> sendPacket(int speed, int steer) async {
    if (characteristic == null) return;

    final List<int> packet = [
      0xA5,
      speed + 100,
      steer + 100,
      (speed ^ steer) & 0xFF
    ];

    await characteristic!.write(packet, withoutResponse: true);
  }

  // ================= DISPOSE =================
  void dispose() {
    scanSub?.cancel();
    stateSub?.cancel();
    heartbeatTimer?.cancel();
    reconnectTimer?.cancel();
  }
}