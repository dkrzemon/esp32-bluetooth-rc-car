import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  bool isScanning = false;
  bool isConnected = false;

  Timer? heartbeatTimer;

  // 🔥 AUTO RECONNECT
  Timer? reconnectTimer;
  bool isReconnecting = false;

  final String deviceName = "RC_CAR";
  final Guid serviceUUID =
      Guid("12345678-1234-1234-1234-123456789abc");

  final Guid charUUID =
      Guid("12345678-1234-1234-1234-123456789abd");

  StreamSubscription<List<ScanResult>>? scanSub;
  StreamSubscription<BluetoothConnectionState>? stateSub;

  @override
  void initState() {
    super.initState();

    scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        final name = r.device.platformName;

        if (name == deviceName && r.rssi > -90) {
          await FlutterBluePlus.stopScan();

          device = r.device;

          try {
            await device!.connect(
              timeout: const Duration(seconds: 10),
            );
          } catch (_) {}

          await stateSub?.cancel();

          stateSub = device!.connectionState.listen((state) {
            if (state == BluetoothConnectionState.connected) {
              setState(() => isConnected = true);
              print("🟢 CONNECTED");
            }

            if (state == BluetoothConnectionState.disconnected) {
              print("🔴 DISCONNECTED");

              setState(() {
                isConnected = false;
                device = null;
                characteristic = null;
              });

              heartbeatTimer?.cancel();

              startReconnect(); // 🔥 AUTO RECONNECT
            }
          });

          await discoverServices();
          startHeartbeat();

          setState(() {});
          return;
        }
      }
    });
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
      } catch (e) {
        print("HEARTBEAT ERROR: $e");
      }
    });
  }

  // 🔥 AUTO RECONNECT
  void startReconnect() {
    if (isReconnecting) return;

    isReconnecting = true;

    reconnectTimer?.cancel();

    reconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      print("🔄 RECONNECT TRY...");

      try {
        await FlutterBluePlus.stopScan();

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 3),
        );

        FlutterBluePlus.scanResults.listen((results) async {
          for (var r in results) {
            if (r.device.platformName == deviceName) {
              print("♻️ FOUND RC_CAR AGAIN");

              await FlutterBluePlus.stopScan();

              reconnectTimer?.cancel();
              isReconnecting = false;

              device = r.device;

              try {
                await device!.connect(
                  timeout: const Duration(seconds: 10),
                );
              } catch (_) {}

              await stateSub?.cancel();

              stateSub = device!.connectionState.listen((state) {
                if (state == BluetoothConnectionState.connected) {
                  setState(() => isConnected = true);
                }

                if (state == BluetoothConnectionState.disconnected) {
                  setState(() {
                    isConnected = false;
                    device = null;
                    characteristic = null;
                  });

                  startReconnect();
                }
              });

              await discoverServices();
              startHeartbeat();

              setState(() {});
              return;
            }
          }
        });
      } catch (e) {
        print("RECONNECT ERROR: $e");
      }
    });
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void scanAndConnect() async {
    await requestPermissions();

    if (isScanning) return;
    isScanning = true;

    await FlutterBluePlus.stopScan();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );

    Future.delayed(const Duration(seconds: 6), () {
      isScanning = false;
    });
  }

  Future<void> discoverServices() async {
    if (device == null) return;

    print("=== SERVICES ===");

    final services = await device!.discoverServices();

    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.uuid == charUUID) {
          characteristic = c;
          print("✅ CHARACTERISTIC FOUND");
        }
      }
    }

    if (characteristic == null) {
      print("❌ CHARACTERISTIC NOT FOUND");
      return;
    }

    setState(() {
      isConnected = true;
    });

    print("🟢 CONNECTED + HEARTBEAT STARTED");
  }

  void sendCommand(String cmd) async {
    if (characteristic == null) return;

    await characteristic!.write(
      cmd.codeUnits,
      withoutResponse: false,
    );
  }

  @override
  void dispose() {
    scanSub?.cancel();
    stateSub?.cancel();
    heartbeatTimer?.cancel();
    reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RC Car Controller")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isConnected ? "Connected" : "Not connected"),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: scanAndConnect,
              child: const Text("Scan & Connect"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => sendCommand("F"),
              child: const Text("Forward"),
            ),
            ElevatedButton(
              onPressed: () => sendCommand("B"),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => sendCommand("L"),
              child: const Text("Left"),
            ),
            ElevatedButton(
              onPressed: () => sendCommand("R"),
              child: const Text("Right"),
            ),
            ElevatedButton(
              onPressed: () => sendCommand("S"),
              child: const Text("Stop"),
            ),
          ],
        ),
      ),
    );
  }
}