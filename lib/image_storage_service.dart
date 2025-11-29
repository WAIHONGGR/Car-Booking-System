import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageStorageService {
  static final ImagePicker _picker = ImagePicker();
  
  // Get the user-specific documents directory for storing images
  static Future<Directory> get _documentsDirectory async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final userImagesDir = Directory('${directory.path}/profiles/${user.uid}');
    if (!await userImagesDir.exists()) {
      await userImagesDir.create(recursive: true);
    }
    return userImagesDir;
  }

  // Pick image from gallery/file system
  static Future<File?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) return null;
      
      // Save the image to local storage
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final imagesDir = await _documentsDirectory;
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(image.path).copy('${imagesDir.path}/$fileName');
      
      return savedImage;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Get all uploaded images for the current user
  static Future<List<String>> getUserImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final imagesDir = await _documentsDirectory;
      final files = await imagesDir.list().toList();
      
      return files
          .where((file) => file.path.contains(user.uid))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('Error getting user images: $e');
      return [];
    }
  }

  // Check if an image path is an asset or local file
  static bool isAssetImage(String imagePath) {
    return imagePath.startsWith('assets/');
  }

  // Get image provider for both asset and local images
  static dynamic getImageProvider(String imagePath) {
    if (isAssetImage(imagePath)) {
      return AssetImage(imagePath);
    } else {
      return FileImage(File(imagePath));
    }
  }

  // Delete a local image file
  static Future<bool> deleteImage(String imagePath) async {
    try {
      if (isAssetImage(imagePath)) return false; // Can't delete assets
      
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }


}
