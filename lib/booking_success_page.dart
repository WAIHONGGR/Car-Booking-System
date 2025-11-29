import 'package:flutter/material.dart';

class BookingSuccessPage extends StatelessWidget {
  const BookingSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Image
              Container(
                height: 200,
                child: Center(
                  child: Image.asset(
                    'assets/images/success.png',
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        child: const Icon(
                          Icons.check_circle,
                          size: 100,
                          color: Colors.green,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Success Title
              const Text(
                'Service was Booked Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Description
              Text(
                "We've received your booking and our\nteam is working to get it to you as soon\nas possible.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              
              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Go back to booking (vehicles page)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    // Navigate to vehicles page
                    Navigator.of(context).pushNamed('/vehicles');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'GO BACK TO BOOKING',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Go to Home Link
              TextButton(
                onPressed: () {
                  // Go to home page
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'GO TO HOME',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

