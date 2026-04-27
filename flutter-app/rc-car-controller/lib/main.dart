import 'package:flutter/material.dart';
import 'ble/ble_service.dart';

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
  final BleService ble = BleService();

  double speed = 0; // 0–100

  @override
  void initState() {
    super.initState();

    ble.init(() {
      setState(() {});
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      ble.scanAndConnect();
    });
  }

  @override
  void dispose() {
    ble.dispose();
    super.dispose();
  }

  void sendSpeed(double value) {
    int v = value.toInt();

    // 🔥 ograniczenie spamowania BLE (wysyła co 5%)
    if (v % 5 == 0) {
      ble.sendCommand("V$v");
    }
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
              ble.isConnected ? "Connected" : "Not connected",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 30),

            Text(
              "Speed: ${speed.toInt()}%",
              style: const TextStyle(fontSize: 20),
            ),

            Slider(
              value: speed,
              min: 0,
              max: 100,
              divisions: 100,

              onChanged: (value) {
                setState(() {
                  speed = value;
                });

                sendSpeed(value);
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                speed = 0;
                setState(() {});
                ble.sendCommand("S");
              },
              child: const Text("STOP"),
            ),
          ],
        ),
      ),
    );
  }
}