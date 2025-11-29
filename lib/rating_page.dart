import 'package:flutter/material.dart';
import 'feedback_form_page.dart';

class Review {
  final String username;
  final int stars;
  final String comment;
  final String serviceType;
  Review({required this.username, required this.stars, required this.comment, required this.serviceType});
}

class RatingPage extends StatefulWidget {
  final Review? newReview;
  const RatingPage({super.key, this.newReview});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  List<Review> reviews = [
    Review(
      username: 'WH',
      stars: 5,
      serviceType: 'Basic Service',
      comment: 'The Basic Service package in Setapak Branch is a good choice to keep normal things in check.\nHighly recommended!',
    ),
    Review(
      username: 'Darren',
      stars: 4,
      serviceType: 'Standard Service',
      comment: 'The Standard Service is more valuable services than the basic service, because it was checking more details but price just more RM100',
    ),
    Review(
      username: 'OIIA',
      stars: 4,
      serviceType: 'Comprehensive Service',
      comment: 'The Comprehensive Services is the best to whose are going to have a very completely checking on his car, it is very valuable.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.newReview != null) {
      reviews.insert(0, widget.newReview!);
    }
  }

  void _addReview(Review review) {
    setState(() {
      reviews.insert(0, review);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Rating', style: TextStyle(color: Colors.grey)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Branch Info Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Setapak Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        SizedBox(height: 4),
                        Text('123 Jalan ABC,\nSetapak, Kuala Lumpur', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text('Mon–Sat | 9AM – 6PM', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text('03-1234 5557', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=200&q=80',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Customer Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          ...reviews.map((review) => _buildReviewCard(review)).toList(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {}, // Remain blank, no action
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ADD', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(review.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(5, (i) => Icon(
                    Icons.star,
                    size: 20,
                    color: i < review.stars ? Colors.yellow : Colors.grey.shade300,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              review.serviceType,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(review.comment),
          ],
        ),
      ),
    );
  }
}