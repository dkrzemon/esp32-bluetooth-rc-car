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

  final String deviceName = "RC_CAR";

  final Guid serviceUUID = Guid("12345678-1234-1234-1234-1234567890ab");
  final Guid charUUID = Guid("abcd1234-5678-1234-5678-abcdef123456");

  StreamSubscription<List<ScanResult>>? scanSub;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();

    scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        final name = r.device.platformName;

        print("DEVICE: $name RSSI: ${r.rssi}");

        if (name == deviceName && r.rssi > -90) {
          print("FOUND RC_CAR");

          await FlutterBluePlus.stopScan();

          device = r.device;

          try {
            await device!.connect(timeout: const Duration(seconds: 10));
          } catch (_) {}

          await discoverServices();

          setState(() {});
          return;
        }
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

  List<BluetoothService> services = await device!.discoverServices();

  for (var s in services) {
    print("SERVICE: ${s.uuid}");

    for (var c in s.characteristics) {
      print("  CHAR: ${c.uuid}");

      // 🔥 USUŃ porównanie — bierzemy pierwszą lepszą
      characteristic = c;
    }
  }

  if (characteristic == null) {
    print("❌ NIC NIE ZNALEZIONO");
  } else {
    print("✅ MAM CHARACTERISTIC");
  }
}

  void sendCommand(String cmd) async {
    if (characteristic == null) {
      print("❌ BRAK CHARACTERISTIC");
      return;
    }

    print("📤 WYSYŁAM: $cmd");

    await characteristic!.write(
      cmd.codeUnits,
      withoutResponse: false, // 🔥 PEWNIEJSZE
    );
  }

  @override
  void dispose() {
    scanSub?.cancel();
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
            Text(
              device == null
                  ? "Not connected"
                  : "Connected to RC_CAR",
            ),

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