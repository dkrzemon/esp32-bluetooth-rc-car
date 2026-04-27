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

  @override
  void initState() {
    super.initState();

    ble.init(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    ble.dispose();
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
              ble.isConnected ? "Connected" : "Not connected",
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: ble.scanAndConnect,
              child: const Text("Scan & Connect"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => ble.sendCommand("F"),
              child: const Text("Forward"),
            ),
            ElevatedButton(
              onPressed: () => ble.sendCommand("B"),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => ble.sendCommand("L"),
              child: const Text("Left"),
            ),
            ElevatedButton(
              onPressed: () => ble.sendCommand("R"),
              child: const Text("Right"),
            ),
            ElevatedButton(
              onPressed: () => ble.sendCommand("S"),
              child: const Text("Stop"),
            ),
          ],
        ),
      ),
    );
  }
}