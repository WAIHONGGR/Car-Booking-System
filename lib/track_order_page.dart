import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feedback_form_page.dart';

class TrackOrderPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;

  const TrackOrderPage({
    Key? key,
    required this.bookingId,
    this.bookingData,
  }) : super(key: key);

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  bool _feedbackSubmitted = false;
  bool _isCheckingFeedback = true;
  
  // Define the complete status sequence
  final List<String> _statusSequence = [
    'Booking Successfully',
    'New Parts Arrived',
    'Installation',
    'Final Inspection',
    'Ready for Pick Up',
    'Picked Up',
  ];

  @override
  void initState() {
    super.initState();
    _checkIfFeedbackSubmitted();
  }

  Future<void> _checkIfFeedbackSubmitted() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isCheckingFeedback = false;
        });
        return;
      }

      print('Checking if feedback submitted for booking: ${widget.bookingId}');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .where('bookingId', isEqualTo: widget.bookingId)
          .where('customerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      setState(() {
        _feedbackSubmitted = querySnapshot.docs.isNotEmpty;
        _isCheckingFeedback = false;
      });
      
      print('Feedback already submitted: $_feedbackSubmitted');
    } catch (e) {
      print('Error checking feedback status: $e');
      setState(() {
        _isCheckingFeedback = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Track Order',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Error loading booking data',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade600,
                ),
              ),
            );
          }
          
          final bookingData = snapshot.data!.data() as Map<String, dynamic>?;
          if (bookingData == null) {
            return const Center(
              child: Text(
                'Booking not found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          
          final currentStatus = bookingData['status'] ?? 'Booking Successfully';
          final serviceDate = bookingData['serviceDate'] ?? '';
          final timeSlotId = bookingData['timeSlotId'] ?? '';
          final serviceTypeId = bookingData['serviceTypeId'] ?? '';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Header Card
                _buildServiceHeader(serviceTypeId, serviceDate, timeSlotId),
                
                const SizedBox(height: 24),
                
                // Tracking Steps
                _buildTrackingSection(currentStatus),
                
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          final bookingData = snapshot.data?.data() as Map<String, dynamic>?;
          final currentStatus = bookingData?['status'] ?? 'Booking Successfully';
          
          // Only show rating button when status is "Picked Up"
          if (currentStatus != 'Picked Up') {
            return const SizedBox.shrink();
          }
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: _isCheckingFeedback
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _feedbackSubmitted
                          ? null
                          : () {
                              // Navigate to feedback form
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => FeedbackFormPage(
                                    bookingId: widget.bookingId,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              ).then((_) {
                                // Refresh feedback status when returning from feedback form
                                _checkIfFeedbackSubmitted();
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _feedbackSubmitted
                            ? Colors.grey.shade400
                            : const Color(0xFF2196F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_feedbackSubmitted) ...[
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _feedbackSubmitted ? 'FEEDBACK SUBMITTED' : 'RATING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceHeader(String serviceTypeId, String serviceDate, String timeSlotId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Name
                    if (serviceTypeId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('serviceTypes')
                            .doc(serviceTypeId)
                            .get(),
                        builder: (context, serviceSnapshot) {
                          final serviceData = serviceSnapshot.data?.data() as Map<String, dynamic>?;
                          final serviceName = serviceData?['name'] ?? 'Basic Service';
                          return Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          );
                        },
                      )
                    else
                      const Text(
                        'Basic Service',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Booking ID: ${widget.bookingId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'General Motors',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (index) {
                        return const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/myvi.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.car_rental, color: Colors.grey);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATE',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(serviceDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICK-UP TIME',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (timeSlotId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('timeSlots')
                            .doc(timeSlotId)
                            .get(),
                        builder: (context, timeSnapshot) {
                          final timeData = timeSnapshot.data?.data() as Map<String, dynamic>?;
                          final timeSlot = timeData != null
                              ? '${timeData['slotStart']}-${timeData['slotEnd']}'
                              : '9:00-9:30';
                          return Text(
                            timeSlot,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          );
                        },
                      )
                    else
                      const Text(
                        '9:00-9:30',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection(String currentStatus) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _statusSequence.length; i++)
            _buildTrackingStep(
              _statusSequence[i],
              currentStatus,
              i == _statusSequence.length - 1, // isLast
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Not set';
      final date = DateTime.parse(dateString);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      return '${date.day}${_getOrdinalSuffix(date.day)} ${months[date.month - 1]} ${date.year}, ${weekdays[date.weekday - 1]}';
    } catch (e) {
      return dateString;
    }
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd'; 
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildTrackingStep(String stepTitle, String currentStatus, bool isLast) {
    // Find the index of current status and this step
    final currentIndex = _statusSequence.indexOf(currentStatus);
    final stepIndex = _statusSequence.indexOf(stepTitle);
    
    // Determine if this step is completed, active, or pending
    final isCompleted = stepIndex <= currentIndex;
    final isActive = stepIndex == currentIndex;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.blue : Colors.grey.shade300,
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? Colors.blue : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Step content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black : Colors.grey.shade600,
                  ),
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'In Progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (isCompleted && !isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}