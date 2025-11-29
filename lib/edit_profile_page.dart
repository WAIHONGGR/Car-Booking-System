import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_view_page.dart';
import 'dart:async';
import 'custom_bottom_nav_bar.dart';
import 'home.dart';
import 'vehicles.dart';
import 'records.dart';
import 'profile_image_selector.dart';
import 'image_storage_service.dart';
// Fallback widget when we cannot pop back (rare). It just shows the profile stream page.
class ProfileViewPageFallback extends StatelessWidget {
  const ProfileViewPageFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileViewPage();
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  TextEditingController? usernameController;
  TextEditingController? emailController;
  TextEditingController? phoneController;
  String selectedBirth = '';
  String selectedGender = '';
  String? profileImage;
  int _currentIndex = 0; // Default to home tab since profile is not in bottom nav

  final List<String> birthOptions = [
    '1990', '1991', '1992', '1993', '1994', '1995', '1996', '1997', '1998', '1999', '2000', '2001', '2002', '2003', '2004', '2005', '2006', '2007'
  ];
  final List<String> genderOptions = ['Male', 'Female'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      setState(() {
        usernameController = TextEditingController(text: (data['username'] as String?) ?? '');
        emailController = TextEditingController(text: (data['email'] as String?) ?? user.email ?? '');
        final loadedPhone = (data['phone'] as String?) ?? '';
        final withoutPrefix = loadedPhone.startsWith('+60') ? loadedPhone.substring(3) : loadedPhone;
        phoneController = TextEditingController(text: withoutPrefix);
        selectedBirth = (data['birth'] as String?) ?? '';
        selectedGender = (data['gender'] as String?) ?? '';
        profileImage = data['profileImage'] as String?;
      });
    } catch (e) {
      // ignore for now
    }
  }

  void _updateProfilePicture(String imagePath) {
    setState(() {
      profileImage = imagePath;
    });
  }

  void saveProfile() async {
    if (usernameController?.text.isEmpty == true ||
        phoneController?.text.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'username': usernameController!.text,
        'phone': '+60${phoneController!.text}',
        'birth': selectedBirth,
        'gender': selectedGender,
        if (profileImage != null) 'profileImage': profileImage,
      }, SetOptions(merge: true));

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (usernameController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
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
                    backgroundImage: profileImage != null 
                        ? ImageStorageService.getImageProvider(profileImage!) 
                        : null,
                    child: profileImage == null 
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
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
            // Display current username and email
            Text(usernameController!.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(emailController!.text, style: const TextStyle(color: Colors.grey)),
            const Divider(height: 40, thickness: 1),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // Email removed from being editable; show as read-only info
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(emailController!.text, style: const TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('+60'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedBirth.isEmpty ? null : selectedBirth,
              items: birthOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedBirth = value ?? '';
                });
              },
              decoration: const InputDecoration(labelText: "Birth", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedGender.isEmpty ? null : selectedGender,
              items: genderOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGender = value ?? '';
                });
              },
              decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Update Profile", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
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
  }
}