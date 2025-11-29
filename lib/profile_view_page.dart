import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'feedback_form_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_bottom_nav_bar.dart';
import 'home.dart';
import 'vehicles.dart';
import 'records.dart';
import 'profile_image_selector.dart';
import 'image_storage_service.dart';

class ProfileViewPage extends StatefulWidget {
  const ProfileViewPage({super.key});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0; // Default to home tab since profile is not in bottom nav
  String _imageKey = DateTime.now().millisecondsSinceEpoch.toString(); // Force image refresh

  void _logout() async {
    await _auth.signOut();
    // Clear remember_me so next launch returns to login
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _updateProfilePicture(String imagePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('Updating profile picture with path: $imagePath');
      
      await _firestore.collection('users').doc(user.uid).set({
        'profileImage': imagePath,
      }, SetOptions(merge: true));

      print('Profile picture path saved to Firestore: $imagePath');
      
      // Force UI refresh by updating the image key
      setState(() {
        _imageKey = DateTime.now().millisecondsSinceEpoch.toString();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating profile picture: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() ?? {};
        final String username = (data['username'] as String?) ?? 'User';
        final String email = (data['email'] as String?) ?? 'user@example.com';
        final String? profileImage = data['profileImage'] as String?;
        
        print('Profile data loaded from Firestore:');
        print('Username: $username');
        print('Email: $email');
        print('Profile image path: $profileImage');
        
        // Check if the file exists
        if (profileImage != null) {
          final file = File(profileImage);
          file.exists().then((exists) {
            print('Profile image file exists at $profileImage: $exists');
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("User Profile"),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: Column(
            children: [
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => ProfileImageSelector(
                      currentImagePath: profileImage,
                      onImageSelected: _updateProfilePicture,
                    ),
                  );
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      key: ValueKey('profile_image_$_imageKey'), // Force rebuild with key
                      child: profileImage != null 
                          ? ClipOval(
                              child: Image.file(
                                File(profileImage),
                                key: ValueKey('image_file_$_imageKey'), // Additional key for Image widget
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                cacheWidth: null, // Disable image caching
                                cacheHeight: null,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading profile image: $error');
                                  return const Icon(Icons.person, size: 50, color: Colors.white);
                                },
                              ),
                            )
                          : const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(email, style: const TextStyle(color: Colors.grey)),
              const Divider(height: 40, thickness: 1),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("My Profile"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    PageRouteBuilder<bool>(
                      pageBuilder: (context, animation, secondaryAnimation) => const EditProfilePage(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                    ),
                  );
                  if (updated == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Settings"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text("Notification"),
                trailing: const Text("Allow", style: TextStyle(color: Colors.grey)),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Log Out"),
                onTap: _logout,
              ),
            ],
          ),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (index == 0) {
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
              } else if (index == 1) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const VehiclesPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ),
                );
              } else if (index == 2) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const RecordsPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}