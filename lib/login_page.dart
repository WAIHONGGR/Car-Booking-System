import 'package:assignment/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';
import 'profile_view_page.dart';
import 'registration_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool keepSignedIn = false;
  bool isPasswordVisible = false;
  bool isLoading = false;
  bool showForgotPassword = false; // Track if forgot password should be shown

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // First, try regular login
      UserCredential? cred;
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
      } on FirebaseAuthException catch (authError) {
        if (authError.code == 'wrong-password') {
          // Check if there's a pending password reset for this email
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: emailController.text.trim())
              .limit(1)
              .get();
              
          if (userQuery.docs.isNotEmpty) {
            final userId = userQuery.docs.first.id;
            final resetDoc = await FirebaseFirestore.instance
                .collection('passwordResets')
                .doc(userId)
                .get();
                
            if (resetDoc.exists) {
              final resetData = resetDoc.data() as Map<String, dynamic>;
              final storedPassword = resetData['newPassword'] as String;
              final isUsed = resetData['used'] as bool? ?? false;
              
              if (!isUsed && passwordController.text == storedPassword) {
                // Password matches the new password, mark as used and send reset email
                await FirebaseFirestore.instance
                    .collection('passwordResets')
                    .doc(userId)
                    .update({'used': true});
                    
                // Send password reset email to complete the process
                await _auth.sendPasswordResetEmail(email: emailController.text.trim());
                
                _showPasswordResetSuccess();
                return;
              }
            }
          }
        }
        // Re-throw the original error if no pending reset found
        throw authError;
      }
      
      // Login successful - continue with normal flow
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', keepSignedIn);

      // Check if username exists in Firestore
      final uid = cred!.user?.uid;
      String? username;
      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          username = (doc.data()?['username'] as String?)?.trim();
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              (username != null && username!.isNotEmpty)
                  ? const HomeScreen()
                  : const WelcomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Show forgot password link after first failed login attempt
      setState(() {
        showForgotPassword = true;
      });
      
      final message = switch (e.code) {
        'invalid-email' => 'Invalid email format.',
        'user-disabled' => 'This user has been disabled.',
        'user-not-found' => 'No user found for that email.',
        'wrong-password' => 'Wrong password provided.',
        _ => 'Login failed: ${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showPasswordResetSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Password Reset Required'),
        content: const Text(
          'Your new password has been verified! A password reset email has been sent to complete the process. Please check your email and follow the instructions to finalize your password change.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear the password field for security
              passwordController.clear();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ForgotPasswordPage(
          initialEmail: emailController.text.trim(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Add some top spacing to center content when keyboard is not visible
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              const Text('Login', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Please enter your email and password', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),

              // Email
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              const Text('Password', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Remember me and Forgot password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: keepSignedIn,
                        onChanged: (value) {
                          setState(() {
                            keepSignedIn = value ?? false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  // Only show forgot password after first failed attempt
                  if (showForgotPassword)
                    TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot Password?'),
                    )
                  else
                    const SizedBox.shrink(), // Empty space when hidden
                ],
              ),
              const SizedBox(height: 32),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),

              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const RegistrationPage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('Register'),
                  ),
                ],
              ),
              // Add bottom spacing to ensure content doesn't get cut off
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}