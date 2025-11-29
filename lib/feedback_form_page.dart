import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rating_page.dart';

class FeedbackFormPage extends StatefulWidget {
  final String? bookingId;
  final void Function(String username, int stars, String comment, String serviceType)? onSubmit;
  
  const FeedbackFormPage({
    super.key, 
    this.bookingId,
    this.onSubmit,
  });

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  int selectedStars = 0;
  String selectedServiceType = 'Basic Service';
  final TextEditingController feedbackController = TextEditingController(
      text: ""
  );

  String? currentUsername;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadBookingServiceType();
  }

  void _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('Current user: ${user?.uid}');
      print('Display name: "${user?.displayName}"');
      print('Email: "${user?.email}"');
      
      if (user != null) {
        // Get username from Firestore users collection first
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data() ?? {};
          final firestoreUsername = (data['username'] as String?)?.trim();
          
          print('Firestore username: "$firestoreUsername"');
          
          if (firestoreUsername != null && firestoreUsername.isNotEmpty) {
            setState(() {
              currentUsername = firestoreUsername;
            });
            print('Using Firestore username: "$firestoreUsername"');
          } else {
            // Fallback to display name or email if Firestore username is empty
            setState(() {
              currentUsername = user.displayName?.isNotEmpty == true 
                  ? user.displayName! 
                  : (user.email?.isNotEmpty == true 
                      ? user.email!.split('@')[0] // Use part before @ as username
                      : 'Anonymous');
            });
            print('Using fallback username: "$currentUsername"');
          }
        } catch (e) {
          print('Error fetching Firestore username: $e');
          // Fallback to display name or email if Firestore fetch fails
          setState(() {
            currentUsername = user.displayName?.isNotEmpty == true 
                ? user.displayName! 
                : (user.email?.isNotEmpty == true 
                    ? user.email!.split('@')[0] // Use part before @ as username
                    : 'Anonymous');
          });
          print('Using fallback username due to error: "$currentUsername"');
        }
        print('Final username set to: "$currentUsername"');
      } else {
        setState(() {
          currentUsername = 'Anonymous';
        });
        print('No user logged in, using Anonymous');
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        currentUsername = 'Anonymous';
      });
    }
  }

  void _loadBookingServiceType() async {
    if (widget.bookingId != null) {
      try {
        final bookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId!)
            .get();
            
        if (bookingDoc.exists) {
          final bookingData = bookingDoc.data() as Map<String, dynamic>;
          final serviceTypeId = bookingData['serviceTypeId'] ?? '';
          
          if (serviceTypeId.isNotEmpty) {
            // Get service name from serviceTypes collection
            final serviceDoc = await FirebaseFirestore.instance
                .collection('serviceTypes')
                .doc(serviceTypeId)
                .get();
                
            if (serviceDoc.exists) {
              final serviceData = serviceDoc.data() as Map<String, dynamic>?;
              final serviceName = serviceData?['name'] ?? 'Basic Service';
              
              setState(() {
                selectedServiceType = serviceName;
              });
            }
          }
        }
      } catch (e) {
        print('Error loading service type: $e');
      }
    }
  }

  Future<void> _submitFeedback(String username, int stars, String comment, String serviceType) async {
    try {
      print('Submitting feedback for booking: ${widget.bookingId}');
      
      if (widget.bookingId != null) {
        // Get booking data to extract branch and service information
        final bookingDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId!)
            .get();
            
        if (bookingDoc.exists) {
          final bookingData = bookingDoc.data() as Map<String, dynamic>;
          print('Booking data: $bookingData');
          
          // Create feedback document
          final feedback = {
            'bookingId': widget.bookingId!,
            'branchId': bookingData['branchId'] ?? '',
            'serviceTypeId': bookingData['serviceTypeId'] ?? '',
            'customerId': FirebaseAuth.instance.currentUser?.uid ?? '',
            'username': username.isNotEmpty ? username : 'Anonymous',
            'rating': stars,
            'comment': comment,
            'serviceType': serviceType,
            'createdAt': FieldValue.serverTimestamp(),
          };

          print('Feedback to be saved: $feedback');
          
          // Save to feedback collection
          await FirebaseFirestore.instance.collection('feedback').add(feedback);
          print('Feedback saved successfully!');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for your feedback!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          print('Booking document does not exist');
        }
      } else {
        print('No booking ID provided');
      }
    } catch (e) {
      print('Error submitting feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = currentUsername ?? "Anonymous";

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('User Feedback', style: TextStyle(color: Colors.grey)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Text(
              'How was your workshop experience and services?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Debug info showing current username
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Submitting as: $username',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Service Type Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.build, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Service Type: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    selectedServiceType,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedStars = index + 1;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star,
                      size: 40,
                      color: index < selectedStars ? Colors.yellow : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: feedbackController,
              minLines: 4,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Suggest anything we can improve..',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 120,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      feedbackController.clear();
                      setState(() {
                        selectedStars = 0;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue.shade700, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16, color: Colors.blue)),
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedStars == 0 || feedbackController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a star rating and enter feedback.')),
                        );
                        return;
                      }
                      if (widget.onSubmit != null) {
                        widget.onSubmit!(username, selectedStars, feedbackController.text, selectedServiceType);
                      } else if (widget.bookingId != null) {
                        // Submit feedback to Firestore
                        print('About to submit feedback with username: "$username"');
                        await _submitFeedback(username, selectedStars, feedbackController.text, selectedServiceType);
                      } else {
                        // Navigate to RatingPage with the new review
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => RatingPage(
                              newReview: Review(
                                username: username,
                                stars: selectedStars,
                                comment: feedbackController.text,
                                serviceType: selectedServiceType,
                              ),
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Submit', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}