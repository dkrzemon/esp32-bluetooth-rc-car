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

  double speed = 0;
  double steer = 0;
  Timer? _sendTimer;

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
      ble.sendCommand("V$v");
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
        title: const Text("RC Car Controller"),
      ),
      body: Row(
        children: [
                    Expanded(
            flex: 1,
            child: Container(
              // color: Colors.grey[000],
              child: Center(
                child: SizedBox(
                  height: 250,
                  width: 250,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 18,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 23),
                        activeTrackColor: Colors.blueAccent,
                        // inactiveTrackColor: Colors.grey.shade700,
                      ),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: steer,
                          min: 0,
                          max: 100,
                          onChanged: (value) {
                            setState(() {
                              steer = value;
                            });
                          }
                        ),
                      ),
                    )
                  )
                )
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[900],
              child: Center(
                child: SizedBox(
                  height: 250,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 18,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 23),
                        activeTrackColor: Colors.blueAccent,
                        // inactiveTrackColor: Colors.grey.shade700,
                      ),
                      child: RotatedBox(
                        quarterTurns: 0,
                        child: Slider(
                          value: speed,
                          min: 0,
                          max: 100,
                          onChanged: (value) {
                            setState(() {
                              speed = value;
                            });
                          }
                        ),
                      ),
                    )
                  )
                )
              ),
            ),
          ),
        ],
      ),
    );
  }
}