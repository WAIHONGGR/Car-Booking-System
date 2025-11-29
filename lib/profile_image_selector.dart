import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileImageSelector extends StatefulWidget {
  final String? currentImagePath;
  final Function(String) onImageSelected;

  const ProfileImageSelector({
    Key? key,
    this.currentImagePath,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  State<ProfileImageSelector> createState() => _ProfileImageSelectorState();
}

class _ProfileImageSelectorState extends State<ProfileImageSelector> {
  File? _image;
  final picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    if (widget.currentImagePath != null) {
      loadCurrentProfileImage();
    } else {
      // Load user-specific profile image if no current path is provided
      loadProfileImage();
    }
  }

  Future getImageFromGallery() async {
    try {
      print('Starting image picker...');
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      print('Image picker result: ${pickedFile?.path}');
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        print('Image selected successfully: ${pickedFile.path}');
      } else {
        print('No image was selected by user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image selected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> savePicture() async {
    if (_image != null) {
      try {
        print('Starting to save image...');
        
        // Get current user ID
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        
        final userId = user.uid;
        print('Saving image for user: $userId');
        
        // Create user-specific directory
        final appDocDir = await getApplicationDocumentsDirectory();
        final userProfileDir = Directory('${appDocDir.path}/profiles/$userId');
        if (!await userProfileDir.exists()) {
          await userProfileDir.create(recursive: true);
          print('Created user profile directory: ${userProfileDir.path}');
        }
        
        // Save with user-specific filename including timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newImagePath = '${userProfileDir.path}/profile_$timestamp.png';
        print('Saving image to: $newImagePath');
        
        await _image!.copy(newImagePath);
        print('File image copied successfully to $newImagePath');
        
        // Call the callback with the saved image path
        widget.onImageSelected(newImagePath);
        
        // Clean up old profile images for this user only (delayed cleanup)
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            final files = await userProfileDir.list().toList();
            for (var file in files) {
              if (file.path.contains('profile_') && 
                  file.path.endsWith('.png') && 
                  file.path != newImagePath) {
                await file.delete();
                print('Deleted old profile image: ${file.path}');
              }
            }
          } catch (e) {
            print('Error cleaning old profile images: $e');
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('File error copying image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('No image selected to save');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('No Image Selected'),
            content: const Text('Please select an image first before saving.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> loadCurrentProfileImage() async {
    try {
      if (widget.currentImagePath != null) {
        final file = File(widget.currentImagePath!);
        print('Loading current profile image from: ${widget.currentImagePath}');
        
        if (await file.exists()) {
          setState(() {
            _image = file;
          });
          print('Current profile image loaded successfully: ${widget.currentImagePath}');
        } else {
          print('Current profile image file does not exist: ${widget.currentImagePath}');
        }
      }
    } catch (e) {
      print('Error loading current profile image: $e');
    }
  }

  Future<void> loadProfileImage() async {
    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return;
      }
      
      final userId = user.uid;
      print('Loading profile image for user: $userId');
      
      // Get user-specific profile directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final userProfileDir = Directory('${appDocDir.path}/profiles/$userId');
      
      if (!await userProfileDir.exists()) {
        print('No profile directory found for user: $userId');
        return;
      }
      
      // Look for the most recent profile image
      final files = await userProfileDir.list().toList();
      File? latestProfileImage;
      int latestTimestamp = 0;
      
      for (var file in files) {
        if (file.path.contains('profile_') && file.path.endsWith('.png')) {
          // Extract timestamp from filename
          final fileName = file.path.split('/').last;
          final timestampStr = fileName.replaceAll('profile_', '').replaceAll('.png', '');
          try {
            final timestamp = int.parse(timestampStr);
            if (timestamp > latestTimestamp) {
              latestTimestamp = timestamp;
              latestProfileImage = File(file.path);
            }
          } catch (e) {
            print('Error parsing timestamp from filename: $fileName');
          }
        }
      }
      
      if (latestProfileImage != null && await latestProfileImage.exists()) {
        setState(() {
          _image = latestProfileImage;
        });
        print('Latest profile image loaded: ${latestProfileImage.path}');
      } else {
        print('No existing profile image found for user: $userId');
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Select Profile Picture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Display current image if available
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _image != null
                    ? Image.file(
                        _image!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, size: 50, color: Colors.grey),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Upload button
            ElevatedButton.icon(
              onPressed: getImageFromGallery,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            
            // Save button
            ElevatedButton.icon(
              onPressed: _image != null ? savePicture : null,
              icon: const Icon(Icons.save),
              label: const Text('Save Picture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
