import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'records.dart';
import 'custom_bottom_nav_bar.dart';
import 'service_booking_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  int _currentIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Search and filter variables
  String _searchQuery = '';
  String? _selectedModelFilter;
  final List<String> _availableModels = ['MYVI', 'PERODUA', 'BMW', 'TOYOTA', 'HONDA', 'PROTON'];

  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 3; // Reduced from 5 to 3 for better UX

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Widget page;
    if (index == 0) {
      page = const HomeScreen();
    } else if (index == 2) {
      page = const RecordsPage();
    } else {
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _currentPage = 1; // Reset to first page when searching
    });
  }

  void _onModelFilterChanged(String? model) {
    setState(() {
      _selectedModelFilter = model;
      _currentPage = 1; // Reset to first page when filtering
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedModelFilter = null;
      _searchController.clear();
      _currentPage = 1;
    });
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<String> _generateNextRegId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'REG001';

    try {
      // Get all cars for this user to find the highest regId
      final snapshot = await _firestore
          .collection('car')
          .where('uid', isEqualTo: user.uid)
          .get();

      int maxRegNumber = 0;
      for (var doc in snapshot.docs) {
        final regId = doc.data()['regId']?.toString() ?? '';
        // Extract number from regId (e.g., "REG001" -> 1)
        if (regId.startsWith('REG')) {
          final numberStr = regId.substring(3);
          final number = int.tryParse(numberStr) ?? 0;
          if (number > maxRegNumber) {
            maxRegNumber = number;
          }
        }
      }

      // Generate next regId
      final nextNumber = maxRegNumber + 1;
      return 'REG${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating regId: $e');
      return 'REG001';
    }
  }

  void _showAddCarDetails() async {
    final regId = await _generateNextRegId();
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AddCarDetailsPage(regId: regId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    setState(() {}); // Refresh after returning
  }

  Future<void> _deleteCar(String docId) async {
    await _firestore.collection('car').doc(docId).delete();
  }

  Future<void> _confirmAndDeleteCar(BuildContext context, String docId, Map<String, dynamic> carData) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Car'),
        content: const Text('Are you sure you want to delete this car? This will hide it from your active cars but preserve booking history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      // Update status to inactive instead of deleting
      await _firestore.collection('car').doc(docId).update({
        'status': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        automaticallyImplyLeading: false,
      ),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('car').where('uid', isEqualTo: user.uid).snapshots(),
        builder: (context, snapshot) {
          final allCars = snapshot.data?.docs ?? [];
          // Filter out inactive cars (only show active cars or cars without status field)
          final activeCars = allCars.where((doc) {
            final data = doc.data();
            final status = data['status'];
            return status == null || status == 'active';
          }).toList();

          // Apply search and model filter
          final filteredCars = activeCars.where((doc) {
            final data = doc.data();
            final model = data['model']?.toString().toLowerCase() ?? '';
            final plate = data['plate']?.toString().toLowerCase() ?? '';
            final regId = data['regId']?.toString().toLowerCase() ?? '';

            // Search filter
            bool matchesSearch = _searchQuery.isEmpty ||
                model.contains(_searchQuery) ||
                plate.contains(_searchQuery) ||
                regId.contains(_searchQuery);

            // Model filter
            bool matchesModel = _selectedModelFilter == null ||
                data['model'] == _selectedModelFilter;

            return matchesSearch && matchesModel;
          }).toList();

          // Calculate pagination
          final totalPages = (filteredCars.length / _itemsPerPage).ceil();
          final startIndex = (_currentPage - 1) * _itemsPerPage;
          final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredCars.length);
          final cars = filteredCars.sublist(startIndex, endIndex);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add Car Section (Always at top)
                  Text(
                    'Add New Car',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Registration ID will be auto-generated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: _showAddCarDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            ),
                            child: const Text('ADD CAR'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search and Filter Section
                  if (activeCars.isNotEmpty) ...[
                    Text(
                      'Your Cars',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search cars by model, plate, or reg ID...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty || _selectedModelFilter != null
                            ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: _clearFilters,
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade600),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Model Filter Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedModelFilter,
                      onChanged: _onModelFilterChanged,
                      decoration: InputDecoration(
                        labelText: 'Filter by Model',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade600),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Models'),
                        ),
                        ..._availableModels.map((model) => DropdownMenuItem<String>(
                          value: model,
                          child: Text(model),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Results count
                    Text(
                      'Showing ${cars.length} of ${filteredCars.length} cars',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (cars.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cars.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final car = cars[i].data();
                        final carId = cars[i].id;
                        return Card(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            car['model'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            car['plate'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Reg ID: ${car['regId'] ?? ''}',
                                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (car['image'] != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8, top: 2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.asset(
                                            car['image'],
                                            width: 120,
                                            height: 70,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, thickness: 1),
                                SizedBox(
                                  height: 48,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FutureBuilder<Map<String, dynamic>?>(
                                          future: _getLatestBooking(carId),
                                          builder: (context, snapshot) {
                                            final latestBooking = snapshot.data;
                                            final canBook = latestBooking == null ||
                                                (latestBooking['status']?.toString() == 'Picked Up');

                                            return InkWell(
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(16),
                                              ),
                                              onTap: canBook ? () {
                                                Navigator.of(context).push(
                                                  PageRouteBuilder(
                                                    pageBuilder: (context, animation, secondaryAnimation) => ServiceBookingPage(car: car, carId: carId),
                                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                      return FadeTransition(opacity: animation, child: child);
                                                    },
                                                  ),
                                                );
                                              } : () {
                                                _showBookingRestrictedDialog(context, latestBooking!);
                                              },
                                              child: Center(
                                                child: Text(
                                                  canBook ? 'BOOK A SERVICE' : 'ALREADY BOOKED',
                                                  style: TextStyle(
                                                    color: canBook ? Colors.blue.shade700 : Colors.grey.shade600,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 32,
                                        color: Colors.grey.shade300,
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          borderRadius: const BorderRadius.only(
                                            bottomRight: Radius.circular(16),
                                          ),
                                          onTap: () async {
                                            final carData = Map<String, dynamic>.from(cars[i].data());
                                            await _confirmAndDeleteCar(context, cars[i].id, carData);
                                          },
                                          child: Center(
                                            child: Text(
                                              'DELETE',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 16),
                  ],

                  // Enhanced Pagination Controls
                  if (totalPages > 1) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Page $_currentPage of $totalPages',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Previous button
                              ElevatedButton.icon(
                                onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                                icon: const Icon(Icons.chevron_left, size: 18),
                                label: const Text('Previous'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentPage > 1 ? Colors.blue.shade600 : Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Page numbers (horizontally scrollable)
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(
                                      totalPages > 5 ? 5 : totalPages,
                                      (index) {
                                        int pageNumber;
                                        if (totalPages <= 5) {
                                          pageNumber = index + 1;
                                        } else {
                                          int startPage = (_currentPage - 2).clamp(1, totalPages - 4);
                                          pageNumber = startPage + index;
                                        }
                                        final isCurrentPage = pageNumber == _currentPage;
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          child: InkWell(
                                            onTap: () => _goToPage(pageNumber),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              constraints: const BoxConstraints(minWidth: 36),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isCurrentPage ? Colors.blue.shade600 : Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isCurrentPage ? Colors.blue.shade600 : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$pageNumber',
                                                  style: TextStyle(
                                                    color: isCurrentPage ? Colors.white : Colors.black87,
                                                    fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),
                              // Next button
                              ElevatedButton.icon(
                                onPressed: _currentPage < totalPages ? () => _goToPage(_currentPage + 1) : null,
                                icon: const Icon(Icons.chevron_right, size: 18),
                                label: const Text('Next'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentPage < totalPages ? Colors.blue.shade600 : Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  // Check the latest booking for this car to see if it's completed (Picked Up)
  Future<Map<String, dynamic>?> _getLatestBooking(String carId) async {
    try {
      // Get all bookings for this car (without ordering to avoid index requirement)
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('carId', isEqualTo: carId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Find the latest booking by comparing createdAt timestamps
        Map<String, dynamic>? latestBooking;
        DateTime? latestDate;

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final createdAt = data['createdAt'];

          if (createdAt != null) {
            DateTime bookingDate;
            if (createdAt is Timestamp) {
              bookingDate = createdAt.toDate();
            } else if (createdAt is String) {
              bookingDate = DateTime.parse(createdAt);
            } else {
              continue; // Skip invalid dates
            }

            if (latestDate == null || bookingDate.isAfter(latestDate)) {
              latestDate = bookingDate;
              latestBooking = data;
            }
          }
        }

        return latestBooking;
      }
      return null; // No bookings found - allow booking
    } catch (e) {
      print('Error checking latest booking: $e');
      return null; // On error, allow booking to be safe
    }
  }

  // Show dialog explaining why booking is restricted
  void _showBookingRestrictedDialog(BuildContext context, Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'Unknown';
    final serviceDate = booking['serviceDate'] ?? 'Unknown date';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.orange.shade600,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Booking Restricted',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Main message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This car has an active service booking',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Status info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: $status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                Text(
                                  'Date: $serviceDate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Instruction
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You can book again once the service is completed (status: "Picked Up")',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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

class AddCarDetailsPage extends StatefulWidget {
  final String regId;
  const AddCarDetailsPage({super.key, required this.regId});

  @override
  State<AddCarDetailsPage> createState() => _AddCarDetailsPageState();
}

class _AddCarDetailsPageState extends State<AddCarDetailsPage> {
  final List<String> _models = ['MYVI', 'PERODUA', 'BMW', 'TOYOTA', 'HONDA', 'PROTON'];
  String? _selectedModel;
  final TextEditingController _plateController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;


  String _getImageForModel(String model) {
    final lower = model.toLowerCase();
    // Map model to correct extension
    const modelImages = {
      'myvi': 'myvi.png',
      'bmw': 'bmw.png',
      'honda': 'honda.jpg',
      'perodua': 'perodua.jpg',
      'proton': 'proton.jpg',
      'toyota': 'toyota.jpg',
    };
    return 'assets/images/' + (modelImages[lower] ?? 'banner1.png');
  }

  Future<void> _addCar() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (_selectedModel == null || plate.isEmpty) {
      setState(() => _errorText = 'Please select model and enter plate number.');
      return;
    }
    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check for duplicate car with same plate and model (only check active cars)
      final existingActive = await FirebaseFirestore.instance
          .collection('car')
          .where('uid', isEqualTo: user.uid)
          .where('plate', isEqualTo: plate)
          .where('model', isEqualTo: _selectedModel)
          .where('status', isEqualTo: 'active')
          .get();
      if (existingActive.docs.isNotEmpty) {
        setState(() {
          _isSubmitting = false;
          _errorText = 'Car already exists with same model and plate number.';
        });
        return;
      }

      // Check for inactive car with same plate and model
      final existingInactive = await FirebaseFirestore.instance
          .collection('car')
          .where('uid', isEqualTo: user.uid)
          .where('plate', isEqualTo: plate)
          .where('model', isEqualTo: _selectedModel)
          .where('status', isEqualTo: 'inactive')
          .get();

      if (existingInactive.docs.isNotEmpty) {
        // Reactivate the existing inactive car
        final carDoc = existingInactive.docs.first;
        await FirebaseFirestore.instance.collection('car').doc(carDoc.id).update({
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Car reactivated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Create new car if no inactive match found
      await FirebaseFirestore.instance.collection('car').add({
        'uid': user.uid,
        'regId': widget.regId,
        'model': _selectedModel,
        'plate': plate,
        'image': _getImageForModel(_selectedModel!),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    setState(() => _isSubmitting = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Car'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reg ID: ${widget.regId}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Text('Car Model', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _selectedModel = v),
              decoration: const InputDecoration(
                hintText: 'Select Car Model...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Car Plate Number', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _plateController,
              decoration: InputDecoration(
                hintText: 'Car No...',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _addCar,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('ADD'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('CANCEL'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
