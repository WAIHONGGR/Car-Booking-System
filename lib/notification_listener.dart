import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'track_order_page.dart';

class AppNotificationListener extends StatefulWidget {
  final Widget child;
  
  const AppNotificationListener({
    super.key,
    required this.child,
  });

  @override
  State<AppNotificationListener> createState() => _AppNotificationListenerState();
}

class _AppNotificationListenerState extends State<AppNotificationListener> {
  late Stream<QuerySnapshot> _notificationStream;
  bool _isInitialized = false;
  List<String> _processedNotifications = [];

  @override
  void initState() {
    super.initState();
    _initializeNotificationListener();
  }

  void _initializeNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('showPopup', isEqualTo: true)
        .snapshots();

    _notificationStream.listen((snapshot) {
      if (!_isInitialized) {
        // Skip initial load to avoid showing old notifications
        _isInitialized = true;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final notificationId = change.doc.id;
          
          // Check if this notification was already processed
          if (_processedNotifications.contains(notificationId)) {
            continue;
          }
          
          _processedNotifications.add(notificationId);
          
          // Show popup notification
          _showPopupFromData(notificationId, data);
          
          // Update showPopup to false so it doesn't show again
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId)
              .update({'showPopup': false});
        }
      }
    });
  }

  void _showPopupFromData(String notificationId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final bookingId = data['bookingId'] ?? '';

    if (mounted) {
      NotificationService.showPopupNotification(
        context,
        title: title,
        message: message,
        onTap: () {
          // Mark as read when tapped
          NotificationService.markAsRead(notificationId);
          
          // Navigate to track order if booking ID exists
          if (bookingId.isNotEmpty) {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                    TrackOrderPage(bookingId: bookingId),
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}