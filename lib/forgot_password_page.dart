import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordPage({super.key, this.initialEmail});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;
  
  // State management
  int currentStep = 0; // 0: security questions, 1: new password
  List<Map<String, dynamic>> allSecurityQuestions = [];
  List<Map<String, dynamic>> selectedQuestions = [];
  List<TextEditingController> answerControllers = [];
  String? verifiedUserUid;
  String? loginAttemptEmail; // Email from initial login attempt

  @override
  void initState() {
    super.initState();
    loginAttemptEmail = widget.initialEmail;
    _loadRandomSecurityQuestions();
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    for (var controller in answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Load security questions for the specific user based on login email
  void _loadRandomSecurityQuestions() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (loginAttemptEmail == null || loginAttemptEmail!.isEmpty) {
        _showError('No login email found. Please try again from the login page.');
        return;
      }

      // First, find the user ID based on the login email
      final userQuery = await _firestore.collection('users')
          .where('email', isEqualTo: loginAttemptEmail!)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showError('No account found with this email address.');
        return;
      }

      final userId = userQuery.docs.first.id;
      print('Found user ID for email $loginAttemptEmail: $userId');

      // Get security questions for this specific user only
      final securityDoc = await _firestore.collection('securityQuestions').doc(userId).get();
      
      if (!securityDoc.exists) {
        _showError('No security questions found for this account. Please contact support.');
        return;
      }

      final data = securityDoc.data() as Map<String, dynamic>;
      final userQuestions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
      
      if (userQuestions.length < 3) {
        _showError('Insufficient security questions for this account. Please contact support.');
        return;
      }

      // Store the user ID for verification later
      verifiedUserUid = userId;

      // Randomly select 3 questions from this user's questions
      userQuestions.shuffle();
      selectedQuestions = userQuestions.take(3).map((q) => {
        'question': q['question'],
        'answer': q['answer'],
        'questionIndex': q['questionIndex'],
        'userId': userId,
      }).toList();

      print('Selected ${selectedQuestions.length} questions for user $userId');

      // Create controllers for the selected questions
      answerControllers = List.generate(3, (index) => TextEditingController());

    } catch (e) {
      print('Error loading security questions: $e');
      _showError('Error loading security questions: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Verify security question answers for the specific user
  void _verifySecurityAnswers() async {
    // Check if all answers are provided
    for (int i = 0; i < 3; i++) {
      if (answerControllers[i].text.trim().isEmpty) {
        _showError('Please answer all security questions');
        return;
      }
    }

    if (verifiedUserUid == null) {
      _showError('User verification failed. Please try again.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('Verifying answers for user: $verifiedUserUid');
      
      // Verify all answers against the specific user's questions
      int correctAnswers = 0;
      
      for (int i = 0; i < 3; i++) {
        final userAnswer = answerControllers[i].text.trim().toLowerCase();
        final correctAnswer = selectedQuestions[i]['answer'].toString().toLowerCase();
        final questionText = selectedQuestions[i]['question'];
        
        print('Question $i: $questionText');
        print('User answer: "$userAnswer"');
        print('Correct answer: "$correctAnswer"');
        
        if (userAnswer == correctAnswer) {
          correctAnswers++;
          print('Answer $i is correct');
        } else {
          print('Answer $i is incorrect');
        }
      }
      
      print('User has $correctAnswers out of 3 correct answers');
      
      // Require ALL 3 answers to be correct for this specific user
      if (correctAnswers == 3) {
        print('All answers correct for user $verifiedUserUid - proceeding to password reset');
        
        // Verify this user still exists in Firebase Auth users collection
        final userDoc = await _firestore.collection('users').doc(verifiedUserUid!).get();
        if (!userDoc.exists) {
          _showError('User account not found. Please contact support.');
          return;
        }
        
        // All answers are correct, proceed to password reset
        setState(() {
          currentStep = 1;
        });
      } else {
        print('Security answers are incorrect for user $verifiedUserUid');
        _showError('Security answers are incorrect. Please try again.');
      }

    } catch (e) {
      print('Error verifying answers: $e');
      _showError('Error verifying answers: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Reset password by sending Firebase reset email
  void _resetPassword() async {
    if (verifiedUserUid == null) {
      _showError('User verification failed. Please try again.');
      return;
    }

    if (loginAttemptEmail == null || loginAttemptEmail!.isEmpty) {
      _showError('No login email found. Please try again from the login page.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Add debugging information
      print('Attempting to send password reset email to: ${loginAttemptEmail!}');
      
      // Validate email format before sending
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(loginAttemptEmail!)) {
        _showError('Invalid email format: ${loginAttemptEmail!}');
        return;
      }
      
      // Use the email from the initial login attempt
      // This ensures only someone who knows the original login email can reset the password
      await _auth.sendPasswordResetEmail(email: loginAttemptEmail!);
      
      print('Password reset email sent successfully to: ${loginAttemptEmail!}');
      _showPasswordResetEmailSent(loginAttemptEmail!);

    } catch (e) {
      print('Error sending password reset email: $e');
      
      // Provide more specific error messages
      String errorMessage = 'Error sending password reset email: ';
      if (e.toString().contains('user-not-found')) {
        errorMessage += 'No account found with this email address.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage += 'Invalid email address format.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage += 'Too many requests. Please wait before trying again.';
      } else {
        errorMessage += e.toString();
      }
      
      _showError(errorMessage);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPasswordResetEmailSent(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Password Reset Email Sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A password reset email has been sent to your email address.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email: $email',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your email and follow the instructions to reset your password.',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'If you don\'t receive the email:',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Check your spam/junk folder\n• Wait a few minutes for delivery\n• Ensure the email address is correct\n• Try again after a few minutes',
                    style: TextStyle(
                      color: Colors.orange.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to login page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            const SizedBox(height: 32),
            
            // Content based on current step
            if (currentStep == 0) _buildSecurityQuestionsStep(),
            if (currentStep == 1) _buildPasswordResetStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildStepIndicator(0, 'Security'),
        Expanded(child: Container(height: 2, color: currentStep > 0 ? Colors.blue : Colors.grey.shade300)),
        _buildStepIndicator(1, 'Reset'),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = currentStep >= step;
    final isCompleted = currentStep > step;
    
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityQuestionsStep() {
    if (isLoading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading security questions...'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Answer Security Questions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please answer these 3 security questions to verify your identity',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        
        ...List.generate(3, (index) => _buildSecurityQuestionField(index)),
        
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _verifySecurityAnswers,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Verify Answers', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityQuestionField(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            selectedQuestions[index]['question'],
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

  Widget _buildPasswordResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password Reset',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          loginAttemptEmail != null 
              ? 'Your identity has been verified. We will send a password reset email to: ${loginAttemptEmail!}'
              : 'Your identity has been verified. We will send you a password reset email.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Security questions verified successfully!',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account verified successfully',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loginAttemptEmail != null
                    ? 'A password reset email will be sent to: ${loginAttemptEmail!}'
                    : 'A password reset email will be sent to your email address.',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Send Reset Email', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}