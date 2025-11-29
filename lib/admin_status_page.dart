import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class AdminStatusPage extends StatefulWidget {
  const AdminStatusPage({super.key});

  @override
  State<AdminStatusPage> createState() => _AdminStatusPageState();
}

class _AdminStatusPageState extends State<AdminStatusPage> {
  final List<String> _statusOptions = [
    "Booking Successfully",
    "New Parts Arrived",
    "Installation", 
    "Final Inspection",
    "Ready for Pick Up",
    "Picked Up"
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'Admin - Booking Status Manager',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null 
        ? const Center(
            child: Text(
              'Please login to access admin features',
              style: TextStyle(fontSize: 16),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User ID: ${user.uid}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Available Statuses: ${_statusOptions.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Bookings List
                Text(
                  'Your Bookings:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('customerId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    
                    final bookings = snapshot.data?.docs ?? [];
                    
                    if (bookings.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No bookings found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      children: bookings.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildBookingCard(doc.id, data);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildBookingCard(String bookingId, Map<String, dynamic> data) {
    final currentStatus = data['status'] ?? 'Booking Successfully';
    final serviceDate = data['serviceDate'] ?? '';
    final serviceTypeId = data['serviceTypeId'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking ID: $bookingId',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (serviceTypeId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('serviceTypes')
                            .doc(serviceTypeId)
                            .get(),
                        builder: (context, serviceSnapshot) {
                          final serviceData = serviceSnapshot.data?.data() as Map<String, dynamic>?;
                          final serviceName = serviceData?['name'] ?? 'Unknown Service';
                          return Text(
                            'Service: $serviceName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      )
                    else
                      Text(
                        'Service: Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    Text(
                      'Date: $serviceDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Current Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(currentStatus),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status Dropdown
          Row(
            children: [
              Text(
                'Change Status:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentStatus,
                      isExpanded: true,
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newStatus) {
                        if (newStatus != null && newStatus != currentStatus) {
                          _updateBookingStatus(bookingId, newStatus);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Booking Successfully':
        return Colors.blue;
      case 'New Parts Arrived':
        return Colors.indigo;
      case 'Installation':
        return Colors.orange;
      case 'Final Inspection':
        return Colors.purple;
      case 'Ready for Pick Up':
        return Colors.green;
      case 'Picked Up':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      // Get current booking data first
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
          
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }
      
      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final oldStatus = bookingData['status'] ?? 'Booking Successfully';
      final customerId = bookingData['customerId'] ?? '';
      final serviceTypeId = bookingData['serviceTypeId'] ?? '';
      
      // Don't send notification if status hasn't changed
      if (oldStatus == newStatus) return;
      
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updating status to "$newStatus"...'),
          duration: const Duration(seconds: 1),
        ),
      );

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Get service name for notification
      String serviceName = 'Service';
      if (serviceTypeId.isNotEmpty) {
        try {
          final serviceDoc = await FirebaseFirestore.instance
              .collection('serviceTypes')
              .doc(serviceTypeId)
              .get();
          serviceName = serviceDoc.data()?['name'] ?? 'Service';
          print('Service name retrieved: $serviceName'); // Debug log
        } catch (e) {
          print('Error getting service name: $e');
        }
      }
      
      // Send status change notification
      if (customerId.isNotEmpty) {
        await NotificationService.sendStatusChangeNotification(
          userId: customerId,
          bookingId: bookingId,
          serviceName: serviceName,
          newStatus: newStatus,
          oldStatus: oldStatus,
        );

        // Send next service reminder notification when status becomes "Picked Up"
        // This reminds users that their next service is due in 3 months
        if (newStatus == 'Picked Up') {
          final carId = bookingData['carId'] ?? '';
          if (carId.isNotEmpty) {
            try {
              // Get car information
              final carDoc = await FirebaseFirestore.instance
                  .collection('car')
                  .doc(carId)
                  .get();
              if (carDoc.exists) {
                final carData = carDoc.data() as Map<String, dynamic>?;
                final carModel = carData?['model'] ?? 'Your Vehicle';
                final carPlate = carData?['plate'] ?? 'Unknown Plate';
                
                // Send next service reminder notification
                await NotificationService.sendNextServiceReminderNotification(
                  userId: customerId,
                  bookingId: bookingId,
                  serviceName: serviceName,
                  carModel: carModel,
                  carPlate: carPlate,
                  serviceTypeId: serviceName, // Pass service name instead of ID
                );
              }
            } catch (e) {
              print('Error getting car information for next service reminder: $e');
            }
          }
        }
      }

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to "$newStatus" successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating booking status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}