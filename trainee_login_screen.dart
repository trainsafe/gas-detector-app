import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:gas_detector_training_app/ui/trainee/trainee_simulator_screen.dart';

class TraineeLoginScreen extends StatefulWidget {
  const TraineeLoginScreen({Key? key}) : super(key: key);

  @override
  State<TraineeLoginScreen> createState() => _TraineeLoginScreenState();
}

class _TraineeLoginScreenState extends State<TraineeLoginScreen> {
  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;
  late String sessionCode;

  @override
  void initState() {
    super.initState();
    sessionCode = ''; // Default initialization.
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String> getDeviceId() async {
    var uuid = Uuid();
    return uuid.v4();  // Returns a unique device ID
  }

  Future<void> _joinSession() async {
    final code = codeController.text.trim().toLowerCase();

    // Validate session code length
    if (code.length != 6) {
      _showError('Session code must be 6 characters');
      return;
    }

    setState(() => isLoading = true);

    // Check if session exists and is active
    final doc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(code)
        .get();

    setState(() => isLoading = false);

    // Handle invalid or expired session
    if (!doc.exists || doc.data()?['is_active'] != true) {
      _showError('Invalid or expired session');
      return;
    }

    // Navigate to TraineeSimulatorScreen and pass the session code
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraineeSimulatorScreen(sessionCode: code),
      ),
    );

    final deviceId = await getDeviceId();  // Get a unique device ID

    // Save the trainee info to Firestore under the current session
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(code)
        .collection('connected_trainees')
        .doc(deviceId)
        .set({
      'joined_at': FieldValue.serverTimestamp(),
      'device_id': deviceId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Training Session')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter Session Code',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              maxLength: 6,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Session Code',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _joinSession,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Join Session'),
            )
          ],
        ),
      ),
    );
  }
}
