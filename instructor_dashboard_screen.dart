import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<InstructorDashboardScreen> createState() => _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  late String instructorName;
  String? sessionCode;
  bool sessionActive = false;

  final List<String> gasTypes = ['H2S', 'CO', 'O2', 'LEL'];
  final Map<String, double> gasValues = {
    'H2S': 0,
    'CO': 0,
    'O2': 20.9,
    'LEL': 0,
  };

  final Map<String, double> alarmHigh = {
    'H2S': 20,
    'CO': 35,
    'O2': 23.5,
    'LEL': 10,
  };

  final Map<String, double> alarmLow = {
    'H2S': 10,
    'CO': 25,
    'O2': 19.5,
    'LEL': 5,
  };

  bool pumpFault = false;
  bool lowBattery = false;
  int traineeCount = 0;
  StreamSubscription? _traineeSub;

  void _resetGasValue(String gas) {
    setState(() {
      gasValues[gas] = defaultGasValues[gas] ?? 0.0;
    });
  }

  void _resetAlarms() {
    pumpFault = false;
    lowBattery = false;
  }

 @override
void didChangeDependencies() {
  super.didChangeDependencies();
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is Map<String, dynamic> && args.containsKey('instructor')) {
    instructorName = args['instructor'] as String;
  } else {
    print('❌ Route arguments invalid or missing. args = $args');
    instructorName = 'Unknown';
  }
}

  @override
  void dispose() {
    _traineeSub?.cancel();
    super.dispose();
  }

  Future<void> createSession() async {
    final code = _generateSessionCode();
    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(now.toDate().add(const Duration(hours: 24)));

    final db = FirebaseFirestore.instance;
    final sessionRef = db.collection('sessions').doc(code);
    await sessionRef.set({
      'instructor_id': instructorName,
      'created_at': now,
      'expires_at': expiresAt,
      'is_active': true,
      'model_id': 'ventis_pro',
    });

    for (final gas in gasTypes) {
      final value = gas == 'O2' ? 20.9 : 0.0;
      final unit = gas == 'O2' || gas == 'LEL' ? '%' : 'ppm';

      await sessionRef.collection('simulated_values').doc(gas).set({
        'gas': gas,
        'value': value,
        'unit': unit,
        'alarm_state': 'normal',
      });
    }

    await sessionRef.collection('session_state').doc('alarms').set({
      'pump_fault': false,
      'low_battery': false,
    });

    setState(() {
      sessionCode = code;
      sessionActive = true;
    });

    _traineeSub = sessionRef.collection('connected_trainees').snapshots().listen((snapshot) {
      setState(() {
        traineeCount = snapshot.docs.length;
      });
    });
  }

  String _generateSessionCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> updateGasValue(String gas, double value) async {
    if (sessionCode == null) return;
    gasValues[gas] = value;

    final high = alarmHigh[gas]!;
    final low = alarmLow[gas]!;

    String alarm;
    if (gas == 'O2') {
      alarm = (value >= high || value <= low) ? 'alarm' : 'normal';
    } else if (value >= high) {
      alarm = 'alarm_high';
    } else if (value >= low) {
      alarm = 'alarm_low';
    } else {
      alarm = 'normal';
    }

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionCode)
        .collection('simulated_values')
        .doc(gas)
        .set({
      'gas': gas,
      'value': value,
      'unit': gas == 'O2' || gas == 'LEL' ? '%' : 'ppm',
      'alarm_state': alarm,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructor Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $instructorName', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (!sessionActive) ...[
              ElevatedButton(
                onPressed: createSession,
                child: const Text('Create New Session'),
              ),
            ] else ...[
              Text('Session Code: $sessionCode', style: const TextStyle(fontSize: 18)),
              Text('Live trainee count: $traineeCount'),
              const SizedBox(height: 16),
              Column(
                children: gasTypes.map((gas) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$gas: ${gasValues[gas]?.toStringAsFixed(1)}'),
                          Slider(
                            min: 0,
                            max: gas == 'O2' ? 25 : 100,
                            divisions: 100,
                            label: gasValues[gas]?.toStringAsFixed(1),
                            value: gasValues[gas] ?? 0,
                            onChanged: (value) => setState(() => gasValues[gas] = value),
                            onChangeEnd: (value) => updateGasValue(gas, value),
                          ),
                          ElevatedButton(
                             onPressed: () => _resetGasValue(gas),
                            child: const Text('Zero'),
                          ),
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
                      setState(() => pumpFault = value);
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
                      setState(() => lowBattery = value);
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
          ],
        ),
      ),
    );
  }
}
