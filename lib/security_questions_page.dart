import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';

class SecurityQuestionsPage extends StatefulWidget {
  const SecurityQuestionsPage({super.key});

  @override
  State<SecurityQuestionsPage> createState() => _SecurityQuestionsPageState();
}

class _SecurityQuestionsPageState extends State<SecurityQuestionsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;

  // Predefined security questions
  final List<String> securityQuestions = [
    "What was the name of your first pet?",
    "What is your mother's maiden name?",
    "What was the name of your first school?",
    "What city were you born in?",
    "What is your favorite movie?",
    "What was your childhood nickname?",
    "What is the name of your best friend from childhood?",
    "What was your first car's make and model?",
    "What is your favorite food?",
    "What street did you grow up on?"
  ];

  // Controllers for answers
  final List<TextEditingController> answerControllers = List.generate(5, (index) => TextEditingController());
  
  // Selected questions (will store indices)
  List<int> selectedQuestions = [0, 1, 2, 3, 4];

  @override
  void dispose() {
    for (var controller in answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveSecurityQuestions() async {
    // Validate that all answers are filled
    for (int i = 0; i < 5; i++) {
      if (answerControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please answer all security questions')),
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Prepare security questions data
        List<Map<String, dynamic>> questionsData = [];
        for (int i = 0; i < 5; i++) {
          questionsData.add({
            'question': securityQuestions[selectedQuestions[i]],
            'answer': answerControllers[i].text.trim().toLowerCase(), // Store in lowercase for easier comparison
            'questionIndex': selectedQuestions[i],
          });
        }

        // Save to Firestore
        await _firestore.collection('securityQuestions').doc(user.uid).set({
          'userId': user.uid,
          'questions': questionsData,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security questions saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving security questions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Questions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Up Security Questions',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please answer these 5 security questions. They will be used to verify your identity if you forget your password.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Security Questions
            ...List.generate(5, (index) => _buildQuestionField(index)),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveSecurityQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Continue', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionField(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showQuestionSelector(index),
              tooltip: 'Change question',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            securityQuestions[selectedQuestions[index]],
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: answerControllers[index],
          decoration: const InputDecoration(
            hintText: 'Enter your answer',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showQuestionSelector(int questionIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Question ${questionIndex + 1}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: securityQuestions.length,
            itemBuilder: (context, index) {
              final isSelected = selectedQuestions.contains(index);
              final isCurrentQuestion = selectedQuestions[questionIndex] == index;
              
              return ListTile(
                title: Text(
                  securityQuestions[index],
                  style: TextStyle(
                    color: isSelected && !isCurrentQuestion 
                        ? Colors.grey 
                        : Colors.black,
                  ),
                ),
                trailing: isCurrentQuestion 
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: isSelected && !isCurrentQuestion 
                    ? null 
                    : () {
                        setState(() {
                          selectedQuestions[questionIndex] = index;
                        });
                        Navigator.pop(context);
                      },
                enabled: !isSelected || isCurrentQuestion,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}