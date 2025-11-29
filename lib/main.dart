//Importing the necessary packages
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'notification_service.dart' as local_notif;
import 'login_page.dart';
import 'feedback_form_page.dart';
import 'rating_page.dart';
import 'welcome_page.dart';
import 'security_questions_page.dart';
import 'profile_view_page.dart';
import 'home.dart';
import 'vehicles.dart';
import 'notification_listener.dart' as app_notifications;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await local_notif.NotificationService.initLocalNotifications();
  
  // Check for scheduled reminders when app starts
  await local_notif.NotificationService.checkAndSendScheduledReminders();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Service App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const _RootDecider(),
      routes: {
        '/login': (context) => LoginPage(),
        '/welcome': (context) => WelcomePage(),
        '/home': (context) => HomeScreen(),
        '/vehicles': (context) => VehiclesPage(),
      },
    );
  }
}

class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  Widget _next = const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final currentUser = auth.currentUser;

    // If not remembering users, ensure signed out for fresh login each launch
    if (!rememberMe && currentUser != null) {
      await auth.signOut();
    }

    final user = auth.currentUser; // re-read after potential signOut
    if (user == null) {
      setState(() => _next = LoginPage());
      return;
    }

    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final username = (data['username'] as String?)?.trim() ?? '';
      
      if (username.isEmpty) {
        setState(() => _next = const WelcomePage());
        return;
      }
      
      // Check if security questions are set up
      final securityDoc = await firestore.collection('securityQuestions').doc(user.uid).get();
      if (!securityDoc.exists) {
        setState(() => _next = const SecurityQuestionsPage());
        return;
      }
      
      setState(() => _next = app_notifications.AppNotificationListener(child: const HomeScreen()));
    } catch (_) {
      setState(() => _next = const WelcomePage());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_next is SizedBox) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _next;
  }
}