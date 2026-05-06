import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'ble/ble_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterBluePlus.setLogLevel(LogLevel.none);

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
  int lastSentSteer = 0;
  int speed = 0;
  int steer = 0;

  double sliderValueSpeed = 0;
  double sliderValueSteer = 0;

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

    // ==============================
    // 🔥 BINARY PROTOCOL SEND
    // ==============================
    _sendTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!ble.isConnected) return;

      final int v = isBackward ? -speed : speed;
      final int s = steer;

      if (v == lastSentSpeed && s == lastSentSteer) return;

      debugPrint("Sending V$v S$s");

      ble.sendPacket(v, s);
      lastSentSpeed = v;
      lastSentSteer = s;
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
                      value: sliderValueSteer,
                      min: -100,
                      max: 100,
                      divisions: 200,
                      onChanged: (value) {
                        setState(() {
                          sliderValueSteer = value;
                          steer = value.toInt();
                        });
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          sliderValueSteer = 0; // 🔥 WRACA DO ŚRODKA
                          steer = 0;
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
                      value: sliderValueSpeed,
                      min: 0,
                      max: 100,
                      onChanged: (value) {
                        setState(() {
                          sliderValueSpeed = value;
                          speed = value.toInt();
                        });
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          sliderValueSpeed = 0;
                          speed = 0;
                          lastSentSpeed = 0;
                        });
                        debugPrint("STOP - sending V0 S$steer");
                        ble.sendPacket(isBackward ? 0 : 0, steer); // albo sam STOP
                        lastSentSpeed = 0;
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