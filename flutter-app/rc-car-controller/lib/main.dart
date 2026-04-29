import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'ble/ble_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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

  int lastSentSpeed = 0;

  double speed = 0;
  double steer = 0;

  Timer? _sendTimer;

  bool isBackward = false;

  @override
  void initState() {
    super.initState();

    ble.init(() {
      setState(() {});
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      ble.scanAndConnect();
    });

    // 🔥 STABILNY STREAM KOMEND (bez lagów)
    _sendTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!ble.isConnected) return;

      final int v = speed.toInt();
      final int output = isBackward ? -v : v;
      if (output != lastSentSpeed) {
        debugPrint("Sending command: V$output");
        ble.sendCommand("V$output");
        lastSentSpeed = output;
      }
    });
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        title: const Text("RC Car Controller"),
      ),
      body: Row(
        children: [
          // 🔹 1. STEERING (left column)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[850],
              child: Center(
                child: RotatedBox(
                  quarterTurns: 0,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 18,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 23,
                      ),
                      activeTrackColor: Colors.blueAccent,
                    ),
                    child: Slider(
                      value: steer,
                      min: 0,
                      max: 100,
                      onChanged: (value) {
                        setState(() {
                          steer = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
  
          // 🔹 2. VELOCITY (mid column)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[900],
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 18,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 23,
                      ),
                      activeTrackColor: Colors.blueAccent,
                    ),
                    child: Slider(
                      value: speed,
                      min: 0,
                      max: 100,
                      onChanged: (value) {
                        setState(() {
                          speed = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
  
          // 🔹 3. BUTTONS (right column)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[700],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                      backgroundColor: isBackward ? Colors.orange : Colors.red,
                      foregroundColor: isBackward ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                      fixedSize: const Size(110, 60),
                    ),
                    onPressed: () {
                      setState(() {
                        isBackward = !isBackward;
                      });
                    },
                    child: Text(
                      isBackward ? "REVERSE" : "FORWARD",
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: isBackward ? Colors.orange : Colors.red,
                      // foregroundColor: isBackward ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                      fixedSize: const Size(110, 60),
                    ),
                    onPressed: () {},
                    child: const Text("Button 2"),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Button 3"),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Button 4"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}