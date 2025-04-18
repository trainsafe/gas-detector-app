import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class TraineeSimulatorScreen extends StatefulWidget {
  final String sessionCode;

  const TraineeSimulatorScreen({Key? key, required this.sessionCode}) : super(key: key);

  @override
  State<TraineeSimulatorScreen> createState() => _TraineeSimulatorScreenState();
}

class _TraineeSimulatorScreenState extends State<TraineeSimulatorScreen> {
  late String sessionCode;
  late StreamSubscription _gasValuesSubscription;
  late StreamSubscription _alarmStatesSubscription;
  bool pumpFault = false;
  bool lowBattery = false;

  Map<String, double> gasValues = {
    'H2S': 0.0,
    'CO': 0.0,
    'O2': 20.9,
    'LEL': 0.0,
  };

  Map<String, String> gasUnits = {
    'H2S': 'ppm',
    'CO': 'ppm',
    'O2': '%',
    'LEL': '%',
  };

  Map<String, String> gasAlarmStates = {
    'H2S': 'normal',
    'CO': 'normal',
    'O2': 'normal',
    'LEL': 'normal',
  };

  @override
  void initState() {
    super.initState();
    sessionCode = widget.sessionCode; // Get the session code from widget
    _fetchSessionData();
    _initializeSubscriptions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // sessionCode should already be initialized via widget.sessionCode, no need to set it again.
    // This is usually used if you need to fetch arguments via the route.
  }

  Future<void> _fetchSessionData() async {
    if (sessionCode.isEmpty) {
      print('Session code is missing or invalid');
      return; // Handle the case when sessionCode is empty or invalid.
    }

    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionCode);
    final sessionSnapshot = await sessionRef.get();
    if (!sessionSnapshot.exists) {
      print('Session not found');
      return;
    }
    final sessionData = sessionSnapshot.data()!;

    setState(() {
      pumpFault = sessionData['session_state']['pump_fault'] ?? false;
      lowBattery = sessionData['session_state']['low_battery'] ?? false;
    });
  }

  void _initializeSubscriptions() {
    _gasValuesSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionCode)
        .collection('simulated_values')
        .snapshots()
        .listen((snapshot) {
      snapshot.docs.forEach((doc) {
        final gas = doc['gas'];
        final value = doc['value'].toDouble();
        final unit = doc['unit'];
        final alarmState = doc['alarm_state'];

        setState(() {
          gasValues[gas] = value;
          gasUnits[gas] = unit;
          gasAlarmStates[gas] = alarmState;
        });
      });
    });

    _alarmStatesSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionCode)
        .collection('session_state')
        .snapshots()
        .listen((snapshot) {
      snapshot.docs.forEach((doc) {
        setState(() {
          pumpFault = doc['pump_fault'];
          lowBattery = doc['low_battery'];
        });
      });
    });
  }

  @override
  void dispose() {
    _gasValuesSubscription.cancel();
    _alarmStatesSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trainee Simulator')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gas Data', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            Column(
              children: gasValues.keys.map((gas) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$gas: ${gasValues[gas]?.toStringAsFixed(1)} ${gasUnits[gas]}'),
                        Text('Alarm state: ${gasAlarmStates[gas]}'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Pump Fault:'),
                Switch(
                  value: pumpFault,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance
                        .collection('sessions')
                        .doc(sessionCode)
                        .collection('session_state')
                        .doc('alarms')
                        .update({'pump_fault': value});
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Low Battery:'),
                Switch(
                  value: lowBattery,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance
                        .collection('sessions')
                        .doc(sessionCode)
                        .collection('session_state')
                        .doc('alarms')
                        .update({'low_battery': value});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
