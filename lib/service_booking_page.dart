import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_detail_page.dart';

class ServiceBookingPage extends StatelessWidget {
  final Map<String, dynamic> car;
  final String carId;
  const ServiceBookingPage({super.key, required this.car, required this.carId});

  void _showServiceDetail(BuildContext context, Map<String, dynamic> data, String serviceId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ServiceDetailPage(service: data, car: car, serviceId: serviceId, carId: carId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Service'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('serviceTypes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          // Sort by price (extract digits, convert to int)
          docs.sort((a, b) {
            int priceA = int.tryParse((a['price'] ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int priceB = int.tryParse((b['price'] ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return priceA.compareTo(priceB);
          });
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final serviceId = docs[i].id;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showServiceDetail(context, data, serviceId),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              if (data['description1'] != null)
                                Text('• ${data['description1']}', style: const TextStyle(fontSize: 14)),
                              if (data['description2'] != null)
                                Text('• ${data['description2']}', style: const TextStyle(fontSize: 14)),
                              if (data['description3'] != null)
                                Text('• ${data['description3']}', style: const TextStyle(fontSize: 14)),
                              if (data['description4'] != null)
                                Text('• ${data['description4']}', style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                data['price'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                data['image'] ?? 'assets/images/banner2.png',
                                width: 90,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 90,
                                    height: 70,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 60,
                              height: 32,
                              child: OutlinedButton(
                                onPressed: () => _showServiceDetail(context, data, serviceId),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('ADD'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

