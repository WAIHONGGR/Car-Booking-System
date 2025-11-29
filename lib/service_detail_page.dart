import 'package:flutter/material.dart';
import 'booking_page.dart';

class ServiceDetailPage extends StatelessWidget {
  final Map<String, dynamic> service;
  final Map<String, dynamic> car;
  final String serviceId;
  final String carId;
  const ServiceDetailPage({super.key, required this.service, required this.car, required this.serviceId, required this.carId});

  @override
  Widget build(BuildContext context) {
    final included = (service['serviceProvideDescription'] as String?)
        ?.split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList() ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(service['name'] ?? ''),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(service['description1'] ?? '', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(service['description2'] ?? '', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.thumb_up, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(service['description3'] ?? '', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_shipping, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(service['description4'] ?? '', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      "What's included?",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...included.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item, style: const TextStyle(fontSize: 15))),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(service['price'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => BookingPage(service: service, car: car, serviceId: serviceId, carId: carId),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('ADD', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
