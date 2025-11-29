import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'branch_detail_page.dart';

class SelectBranchPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final Map<String, dynamic> car;
  final String serviceId;
  final String carId;

  const SelectBranchPage({
    super.key,
    required this.service,
    required this.car,
    required this.serviceId,
    required this.carId,
  });

  @override
  State<SelectBranchPage> createState() => _SelectBranchPageState();
}

class _SelectBranchPageState extends State<SelectBranchPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Branch')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Enter branch name or location...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('branches').snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final loc = (data['location'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || loc.contains(_search);
                }).toList();
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final data = filtered[i].data();
                    final branchId = filtered[i].id;
                    return Card(
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
                                  Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(data['location'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(data['info'] ?? '', style: const TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(data['phone'] ?? '', style: const TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.star, size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('feedback')
                                              .where('branchId', isEqualTo: branchId)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError || !snapshot.hasData) {
                                              return const Text('No Reviews Yet', style: TextStyle(fontSize: 13));
                                            }
                                            
                                            final reviews = snapshot.data!.docs;
                                            if (reviews.isEmpty) {
                                              return const Text('No Reviews Yet', style: TextStyle(fontSize: 13));
                                            }
                                            
                                            // Calculate average rating
                                            double totalRating = 0;
                                            for (var doc in reviews) {
                                              final data = doc.data() as Map<String, dynamic>;
                                              totalRating += (data['rating'] ?? 0).toDouble();
                                            }
                                            double avgRating = totalRating / reviews.length;
                                            
                                            return Text(
                                              '${avgRating.toStringAsFixed(1)}/5 (${reviews.length} Reviews)',
                                              style: const TextStyle(fontSize: 13),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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
                                    data['image'] ?? 'assets/images/banner1.png',
                                    width: 80,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 60,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 70,
                                  height: 32,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) => BranchDetailPage(
                                            branch: {
                                              ...data,
                                              'id': branchId,
                                            },
                                            service: widget.service,
                                            car: widget.car,
                                            serviceId: widget.serviceId,
                                            carId: widget.carId,
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
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(color: Colors.blue),
                                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text('SELECT'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
