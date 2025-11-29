import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_view_page.dart';
import 'vehicles.dart';
import 'records.dart';
import 'custom_bottom_nav_bar.dart';
import 'image_storage_service.dart';
import 'track_order_page.dart';
import 'admin_status_page.dart';
import 'notifications_page.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Service App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _hasCheckedTodayNotifications = false;

  @override
  void initState() {
    super.initState();
    _checkAndSendTodayNotifications();
  }

  Future<void> _checkAndSendTodayNotifications() async {
    if (_hasCheckedTodayNotifications) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final todayFormatted = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      // Get today's bookings that are not picked up
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: user.uid)
          .where('serviceDate', isEqualTo: todayFormatted)
          .get();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'Booking Successfully';

        if (status != 'Picked Up') {
          // Check if notification already exists for this booking today
          final existingNotification = await FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .where('bookingId', isEqualTo: doc.id)
              .where('type', isEqualTo: 'upcoming_service')
              .get();

          if (existingNotification.docs.isEmpty) {
            // Get service name and time slot
            String serviceName = 'Service';
            String timeSlot = 'scheduled time';

            if (data['serviceTypeId'] != null) {
              final serviceDoc = await FirebaseFirestore.instance
                  .collection('serviceTypes')
                  .doc(data['serviceTypeId'])
                  .get();
              serviceName = serviceDoc.data()?['name'] ?? 'Service';
            }

            if (data['timeSlotId'] != null) {
              final timeDoc = await FirebaseFirestore.instance
                  .collection('timeSlots')
                  .doc(data['timeSlotId'])
                  .get();
              final timeData = timeDoc.data();
              if (timeData != null) {
                timeSlot = '${timeData['slotStart']}-${timeData['slotEnd']}';
              }
            }

            // Send notification
            await NotificationService.sendUpcomingServiceNotification(
              userId: user.uid,
              bookingId: doc.id,
              serviceName: serviceName,
              serviceDate: todayFormatted,
              timeSlot: timeSlot,
            );

            // Show popup notification if context is available
            if (mounted) {
              NotificationService.showPopupNotification(
                context,
                title: 'Upcoming Service Today',
                message: 'Your $serviceName is scheduled today at $timeSlot',
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TrackOrderPage(bookingId: doc.id),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
              );
            }
          }
        }
      }

      // Check for scheduled reminders
      await NotificationService.checkAndSendScheduledReminders();
      
      _hasCheckedTodayNotifications = true;
    } catch (e) {
      print('Error checking today notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(elevation: 0, backgroundColor: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Greeting, Location, Avatar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user != null)
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                              builder: (context, snapshot) {
                                final data = snapshot.data?.data();
                                final username = (data != null && data['username'] != null && (data['username'] as String).trim().isNotEmpty)
                                    ? data['username'] as String
                                    : 'User';
                                return Text(
                                  'Hello $username',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                );
                              },
                            )
                          else
                            const Text(
                              'Hello User',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          Row(
                            children: const [
                              Text(
                                'KUALA LUMPUR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 15,
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Notification bell with badge and navigation
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const NotificationsPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: StreamBuilder<int>(
                        stream: NotificationService.getUnreadCount(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.notifications_none, size: 28, color: Colors.grey[800]),
                              if (unreadCount > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Admin Button
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const AdminStatusPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          size: 24,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const ProfileViewPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.ease;
                              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                        builder: (context, snapshot) {
                          final data = snapshot.data?.data();
                          final String? profileImage = data?['profileImage'] as String?;

                          return CircleAvatar(
                            radius: 24,
                            backgroundImage: profileImage != null
                                ? ImageStorageService.getImageProvider(profileImage)
                                : const AssetImage('assets/images/avatar.jpg'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search for a car service',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 20),

                // Banner Carousel
                SizedBox(
                  width: double.infinity,
                  height: 140,
                  child: _BannerCarousel(),
                ),
                const SizedBox(height: 8),

                // Carousel Dots (moved into _BannerCarousel)


                const SizedBox(height: 20),

                // Select Service Title
                const Text(
                  'Select Service',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                // Service Grid
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
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
                      },
                      child: _serviceTile(Icons.build, "Car Service"),
                    ),
                    _serviceTile(Icons.tire_repair, "Tyres &\nWheel Care"),
                    _serviceTile(Icons.format_paint, "Denting &\nPainting"),
                    _serviceTile(Icons.ac_unit, "AC Service &\nRepair"),
                    _serviceTile(Icons.local_car_wash, "Car Spa &\nCleaning"),
                    _serviceTile(Icons.battery_charging_full, "Batteries"),
                    _serviceTile(Icons.assignment, "Insurance\nClaims"),
                    _serviceTile(Icons.lightbulb, "Windshield &\nLights"),
                  ],
                ),
                const SizedBox(height: 20),
                // Upcoming Service Section (with debugging)
                _buildUpcomingService(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            Navigator.of(context).push(
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
            Navigator.of(context).push(
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

  static Widget _serviceTile(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingService() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final today = DateTime.now();
    final todayFormatted = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';



    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(), // Get all user bookings first
      builder: (context, snapshot) {


        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allBookings = snapshot.data!.docs;

        // Debug: Print all bookings
        for (var doc in allBookings) {
          final data = doc.data() as Map<String, dynamic>;
        }

        // Filter for today's bookings (exclude 'Picked Up' status)
        final todaysBookings = allBookings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final serviceDate = data['serviceDate'] as String?;
          final status = data['status'] as String?;
          return serviceDate == todayFormatted && status != 'Picked Up';
        }).toList();

        if (todaysBookings.isEmpty) {
          return const SizedBox.shrink();
        }


        // Show all today's bookings
        return Column(
          children: todaysBookings.map((bookingDoc) {
            final bookingData = bookingDoc.data() as Map<String, dynamic>;
            final bookingId = bookingDoc.id;
            final serviceTypeId = bookingData['serviceTypeId'] ?? '';
            final timeSlotId = bookingData['timeSlotId'] ?? '';
            final status = bookingData['status'] ?? 'Booking Successfully';
            final normalizedStatus = (status is String) ? status.trim() : 'Booking Successfully';

            // Determine if it's upcoming or ongoing based on status
            final isUpcoming = normalizedStatus == 'Booking Successfully';
            // Show TRACK for all non-upcoming statuses, including 'Picked Up'
            final isOngoing = !isUpcoming;
            final displayLabel = isUpcoming ? 'UPCOMING:' : 'ONGOING:';
            final labelColor = isUpcoming ? Colors.blue.shade700 : Colors.orange.shade700;
            final containerColor = isUpcoming ? Colors.blue.shade50 : Colors.orange.shade50;
            final borderColor = isUpcoming ? Colors.blue.shade200 : Colors.orange.shade200;

            return _buildServicePanel(
              bookingId: bookingId,
              bookingData: bookingData,
              serviceTypeId: serviceTypeId,
              timeSlotId: timeSlotId,
              status: status,
              isOngoing: isOngoing,
              displayLabel: displayLabel,
              labelColor: labelColor,
              containerColor: containerColor,
              borderColor: borderColor,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildServicePanel({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String serviceTypeId,
    required String timeSlotId,
    required String status,
    required bool isOngoing,
    required String displayLabel,
    required Color labelColor,
    required Color containerColor,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
                const SizedBox(width: 4),
                // Service name
                Flexible(
                  child: (serviceTypeId.isNotEmpty)
                      ? FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('serviceTypes')
                              .doc(serviceTypeId)
                              .get(),
                          builder: (context, serviceSnapshot) {
                            final serviceData = serviceSnapshot.data?.data() as Map<String, dynamic>?;
                            final serviceName = serviceData?['name'] ?? 'Basic Service';
                            return Text(
                              serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            );
                          },
                        )
                      : const Text(
                          'Basic Service',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Time slot
          if (timeSlotId.isNotEmpty)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('timeSlots')
                  .doc(timeSlotId)
                  .get(),
              builder: (context, timeSnapshot) {
                final timeData = timeSnapshot.data?.data() as Map<String, dynamic>?;
                final slot = timeData != null ? '${timeData['slotStart']}-${timeData['slotEnd']}' : '';
                return Row(
                  children: [
                    if (slot.isNotEmpty)
                      Text(
                        '(Today,$slot)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    if (isOngoing) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  TrackOrderPage(
                                    bookingId: bookingId,
                                    bookingData: bookingData,
                                  ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: Text(
                          'TRACK',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            )
          else
            Row(
              children: [
                Text(
                  '(Today,9:00-9:30)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (isOngoing) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              TrackOrderPage(
                                bookingId: bookingId,
                                bookingData: bookingData,
                              ),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: Text(
                      'TRACK',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  final List<String> _images = [
    'assets/images/banner1.png',
    'assets/images/banner2.png',
    'assets/images/banner3.png',
    'assets/images/banner4.png',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 120,
            child: PageView.builder(
              controller: _controller,
              itemCount: _images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.asset(
                  _images[index],
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _images.length,
                (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: index == _currentPage ? 10 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == _currentPage ? Colors.black : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
