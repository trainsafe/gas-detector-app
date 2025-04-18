import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstructorLoginScreen extends StatefulWidget {
  const InstructorLoginScreen({Key? key}) : super(key: key);

  @override
  State<InstructorLoginScreen> createState() => _InstructorLoginScreenState();
}

class _InstructorLoginScreenState extends State<InstructorLoginScreen> {
  // TODO: Replace with Firestore query for dynamic instructor list
  final List<String> instructors = [
    'Ted S',
    'Jessica M',
    'Marc M',
  ];

  String? selectedInstructor;
  final TextEditingController pinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instructor Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Your Instructor Name',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedInstructor,
              hint: const Text('Choose Instructor'),
              isExpanded: true,
              items: instructors.map((String name) {
                return DropdownMenuItem<String>(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedInstructor = value;
                  pinController.clear();
                });
              },
            ),
            if (selectedInstructor != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: selectedInstructor != null
                  ? () async {
                      final instructorId = _sanitizeInstructorId(selectedInstructor!);
                      if (pinController.text.trim().isEmpty) {
                        _showError('Please enter a PIN');
                        return;
                      }

                      final instructorDoc = await FirebaseFirestore.instance
                          .collection('instructors')
                          .doc(instructorId)
                          .get();

                      if (!instructorDoc.exists) {
                        _showError('Instructor not found');
                        return;
                      }

                      final data = instructorDoc.data()!;
                      final enteredPin = pinController.text.trim();
                      // print('Firestore PIN: \${data['pin']}');
                      // print('Entered PIN: \$enteredPin');
                      print('is_active: ${data['is_active']}');

                      if (data['is_active'] == true && data['pin'] == enteredPin) {
                        Navigator.pushNamed(
                          context,
                          '/instructor-dashboard',
                          arguments: {'instructor': selectedInstructor},
                        );
                      } else {
                        _showError('Invalid PIN or inactive instructor');
                      }
                    }
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  String _sanitizeInstructorId(String name) {
    return name.toLowerCase().replaceAll(' ', '_');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
