import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // Initialize local notifications (call once, e.g., from main)
  static Future<void> initLocalNotifications() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'General Notifications',
      description: 'General purpose notifications',
      importance: Importance.high,
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      channelDescription: 'General purpose notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _local.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  // Create notification in Firestore
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String bookingId,
    bool showPopup = true,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'bookingId': bookingId,
        'isRead': false,
        'showPopup': showPopup,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Also show local (system) notification for emulator/device
      await _showLocalNotification(title: title, body: message);

      print('Notification created: $title');
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Send payment success notification
  static Future<void> sendPaymentSuccessNotification({
    required String userId,
    required String bookingId,
    required String serviceName,
    required String amount,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Payment Successful',
      message: 'Payment of RM $amount for $serviceName was successful.',
      type: 'payment_success',
      bookingId: bookingId,
      data: {
        'serviceName': serviceName,
        'amount': amount,
      },
    );
  }

  // Send upcoming service notification
  static Future<void> sendUpcomingServiceNotification({
    required String userId,
    required String bookingId,
    required String serviceName,
    required String serviceDate,
    required String timeSlot,
  }) async {
    // Create in-app notification
    await createNotification(
      userId: userId,
      title: 'Upcoming Service Today',
      message: 'Your $serviceName is scheduled today at $timeSlot',
      type: 'upcoming_service',
      bookingId: bookingId,
      data: {
        'serviceName': serviceName,
        'serviceDate': serviceDate,
        'timeSlot': timeSlot,
      },
    );
  }

  // Send status change notification
  static Future<void> sendStatusChangeNotification({
    required String userId,
    required String bookingId,
    required String serviceName,
    required String newStatus,
    required String oldStatus,
  }) async {
    String message;
    switch (newStatus) {
      case 'Installation':
        message = 'Your $serviceName installation has started!';
        break;
      case 'Final Inspection':
        message = 'Your $serviceName is undergoing final inspection';
        break;
      case 'Ready for Pick Up':
        message = 'Your $serviceName is ready for pickup!';
        break;
      case 'Picked Up':
        message = 'Your $serviceName has been completed. Please rate your experience!';
        break;
      default:
        message = 'Your $serviceName status has been updated to $newStatus';
    }

    // Create in-app notification
    await createNotification(
      userId: userId,
      title: 'Service Status Updated',
      message: message,
      type: 'status_change',
      bookingId: bookingId,
      data: {
        'serviceName': serviceName,
        'newStatus': newStatus,
        'oldStatus': oldStatus,
      },
    );
  }

  static Future<void> sendNextServiceReminderNotification({
    required String userId,
    required String bookingId,
    required String serviceName,
    required String carModel,
    required String carPlate,
    required String serviceTypeId,
  }) async {
    // Calculate next service date based on service type
    int daysToAdd;
    String serviceInterval;

    switch (serviceTypeId) {
      case 'Basic Service':
        daysToAdd = 90; // 3 months
        serviceInterval = '3 months';
        break;
      case 'Standard Service':
        daysToAdd = 180; // 6 months
        serviceInterval = '6 months';
        break;
      case 'Comprehensive Service':
        daysToAdd = 365; // 1 year
        serviceInterval = '1 year';
        break;
      default:
        daysToAdd = 90; // Default to 3 months
        serviceInterval = '3 months';
    }

    final nextServiceDate = DateTime.now().add(Duration(days: daysToAdd));
    final formattedDate = '${nextServiceDate.day.toString().padLeft(2, '0')}/${nextServiceDate.month.toString().padLeft(2, '0')}/${nextServiceDate.year}';

    await createNotification(
      userId: userId,
      title: 'Next Service Reminder',
      message: 'Thanks for having the $serviceName with CarBuddy. Your $carModel ($carPlate) next service date will be on $formattedDate (after $serviceInterval).',
      type: 'next_service_reminder',
      bookingId: bookingId,
      data: {
        'serviceName': serviceName,
        'carModel': carModel,
        'carPlate': carPlate,
        'nextServiceDate': formattedDate,
        'reminderDate': nextServiceDate.toIso8601String(),
        'serviceTypeId': serviceTypeId,
        'serviceInterval': serviceInterval,
      },
    );

    // Schedule 1-day advance notification
    await _scheduleAdvanceReminder(
      userId: userId,
      bookingId: bookingId,
      serviceName: serviceName,
      carModel: carModel,
      carPlate: carPlate,
      nextServiceDate: nextServiceDate,
      serviceInterval: serviceInterval,
    );
  }

  static Future<void> _scheduleAdvanceReminder({
    required String userId,
    required String bookingId,
    required String serviceName,
    required String carModel,
    required String carPlate,
    required DateTime nextServiceDate,
    required String serviceInterval,
  }) async {
    // Calculate 1 day before the next service date
    final advanceReminderDate = nextServiceDate.subtract(const Duration(days: 1));
    final now = DateTime.now();

    // Only schedule if the advance reminder date is in the future
    if (advanceReminderDate.isAfter(now)) {
      final formattedDate = '${nextServiceDate.day.toString().padLeft(2, '0')}/${nextServiceDate.month.toString().padLeft(2, '0')}/${nextServiceDate.year}';

      // Store the scheduled reminder in Firestore instead of sending immediately
      await _firestore.collection('scheduled_reminders').add({
        'userId': userId,
        'bookingId': bookingId,
        'serviceName': serviceName,
        'carModel': carModel,
        'carPlate': carPlate,
        'nextServiceDate': formattedDate,
        'scheduledDate': advanceReminderDate,
        'serviceInterval': serviceInterval,
        'type': 'advance_service_reminder',
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Method to check and send scheduled reminders (call this periodically)
  static Future<void> checkAndSendScheduledReminders() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // Get all unsent reminders scheduled for today or earlier
      final querySnapshot = await _firestore
          .collection('scheduled_reminders')
          .where('sent', isEqualTo: false)
          .where('scheduledDate', isLessThanOrEqualTo: today)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        final bookingId = data['bookingId'] as String;
        final serviceName = data['serviceName'] as String;
        final carModel = data['carModel'] as String;
        final carPlate = data['carPlate'] as String;
        final nextServiceDate = data['nextServiceDate'] as String;

        // Send the advance reminder notification
        await createNotification(
          userId: userId,
          title: 'Service Reminder - Tomorrow!',
          message: 'Your $carModel ($carPlate) $serviceName is scheduled for tomorrow ($nextServiceDate). Don\'t forget to bring your car in!',
          type: 'advance_service_reminder',
          bookingId: bookingId,
          data: {
            'serviceName': serviceName,
            'carModel': carModel,
            'carPlate': carPlate,
            'nextServiceDate': nextServiceDate,
            'reminderDate': now.toIso8601String(),
          },
        );

        // Mark as sent
        await doc.reference.update({'sent': true});
      }
    } catch (e) {
      print('Error checking scheduled reminders: $e');
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for current user
  static Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get user notifications (without orderBy to avoid index issues)
  static Stream<QuerySnapshot> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  // Show popup notification
  static void showPopupNotification(
      BuildContext context, {
        required String title,
        required String message,
        required VoidCallback onTap,
      }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              overlayEntry.remove();
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}