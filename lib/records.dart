import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'vehicles.dart';
import 'custom_bottom_nav_bar.dart';
import 'track_order_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  int _currentIndex = 2;
  int _selectedTab = 0; // 0 = Upcoming, 1 = Past
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Filter variables
  String _selectedStatus = 'All';
  String _selectedService = 'All';
  final List<String> _statusOptions = ['All','Booking Successfully','New Parts Arrived', 'Installation', 'Final Inspection', 'Ready for Pick Up'];
  List<String> _serviceOptions = ['All'];
  
  // Date filter variables
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  
  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 3; // Same as vehicles page

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Widget page;
    if (index == 0) {
      page = const HomeScreen();
    } else if (index == 1) {
      page = const VehiclesPage();
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

  void _onStatusFilterChanged(String? value) {
    setState(() {
      _selectedStatus = value ?? 'All';
      _currentPage = 1; // Reset to first page when filtering
    });
  }

  void _onServiceFilterChanged(String? value) {
    setState(() {
      _selectedService = value ?? 'All';
      _currentPage = 1; // Reset to first page when filtering
    });
  }

  void _refreshData() {
    setState(() {
      // This will trigger a rebuild and refetch the data
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Choose Date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
        _currentPage = 1;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: _selectedStartDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
        _currentPage = 1;
      });
    }
  }

  void _clearDateFilters() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
      _currentPage = 1;
    });
  }

  void _onTabChanged(int tabIndex) {
    setState(() {
      _selectedTab = tabIndex;
      _currentPage = 1; // Reset to first page when switching tabs
      
      // Reset status filter when switching to PAST tab
      if (tabIndex == 1) {
        _selectedStatus = 'All';
      }
    });
  }

  Future<QuerySnapshot> _getBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return await _firestore
        .collection('bookings')
        .where('customerId', isEqualTo: user.uid)
        .get();
  }

  Future<List<QueryDocumentSnapshot>> _getFilteredBookings() async {
    // Get all bookings
    final bookingsSnapshot = await _getBookings();
    final bookings = bookingsSnapshot.docs;
    
    // Sort bookings by createdAt (latest first) on client side
    bookings.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aCreatedAt = aData['createdAt'];
      final bCreatedAt = bData['createdAt'];
      
      if (aCreatedAt == null && bCreatedAt == null) return 0;
      if (aCreatedAt == null) return 1;
      if (bCreatedAt == null) return -1;
      
      // Handle different timestamp formats
      DateTime aDate, bDate;
      if (aCreatedAt is Timestamp) {
        aDate = aCreatedAt.toDate();
      } else if (aCreatedAt is String) {
        aDate = DateTime.parse(aCreatedAt);
      } else {
        return 0;
      }
      
      if (bCreatedAt is Timestamp) {
        bDate = bCreatedAt.toDate();
      } else if (bCreatedAt is String) {
        bDate = DateTime.parse(bCreatedAt);
      } else {
        return 0;
      }
      
      return bDate.compareTo(aDate); // Descending order
    });
    
    // Filter bookings based on tab, search, status, and service
    return await _filterBookings(bookings);
  }

  Future<List<QueryDocumentSnapshot>> _filterBookings(List<QueryDocumentSnapshot> bookings) async {
    // First, filter by tab, status, and date (these don't require service lookup)
    final preFilteredBookings = bookings.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      final bookingId = doc.id.toLowerCase();
      final serviceDate = data['serviceDate']?.toString() ?? '';
      
      // Filter by tab (upcoming vs past)
      bool matchesTab = false;
      if (_selectedTab == 0) { // Upcoming
        matchesTab = status.toLowerCase() != 'picked up';
      } else { // Past
        matchesTab = status.toLowerCase() == 'picked up';
      }
      
      // Filter by status (only apply if status filter is visible)
      bool matchesStatus = _selectedTab == 1 || // Past tab - no status filter
          _selectedStatus == 'All' ||
          status.toLowerCase() == _selectedStatus.toLowerCase();
      
      // Filter by date range
      bool matchesDate = true;
      if (_selectedStartDate != null || _selectedEndDate != null) {
        try {
          DateTime? bookingDate;
          if (serviceDate.isNotEmpty) {
            bookingDate = DateTime.parse(serviceDate);
          } else {
            // Fallback to createdAt if serviceDate is not available
            final createdAt = data['createdAt'];
            if (createdAt is Timestamp) {
              bookingDate = createdAt.toDate();
            } else if (createdAt is String) {
              bookingDate = DateTime.parse(createdAt);
            } else {
              matchesDate = false;
            }
          }
          
          if (matchesDate && bookingDate != null) {
            if (_selectedStartDate != null && bookingDate.isBefore(_selectedStartDate!)) {
              matchesDate = false;
            }
            if (_selectedEndDate != null && bookingDate.isAfter(_selectedEndDate!.add(const Duration(days: 1)))) {
              matchesDate = false;
            }
          }
        } catch (e) {
          matchesDate = false;
        }
      }
      
      // Basic search filter (booking ID only)
      bool matchesSearch = _searchQuery.isEmpty || bookingId.contains(_searchQuery);
      
      return matchesTab && matchesStatus && matchesDate && matchesSearch;
    }).toList();
    
    // Now filter by service if needed
    final filteredBookings = <QueryDocumentSnapshot>[];
    
    if (_selectedService == 'All' && _searchQuery.isEmpty) {
      // No service filtering needed
      filteredBookings.addAll(preFilteredBookings);
    } else {
      // Need to check service names
      for (final doc in preFilteredBookings) {
        final data = doc.data() as Map<String, dynamic>;
        final serviceTypeId = data['serviceTypeId']?.toString() ?? '';
        final bookingId = doc.id.toLowerCase();
        
        bool matchesService = _selectedService == 'All';
        
        if (serviceTypeId.isNotEmpty) {
          try {
            final serviceDoc = await _firestore.collection('serviceTypes').doc(serviceTypeId).get();
            if (serviceDoc.exists) {
              final serviceData = serviceDoc.data() as Map<String, dynamic>?;
              final serviceName = serviceData?['name']?.toString().toLowerCase() ?? '';
              
              // Filter by service
              matchesService = _selectedService == 'All' ||
                  serviceName == _selectedService.toLowerCase();
            }
          } catch (e) {
            print('Error fetching service: $e');
          }
        }
        
        if (matchesService) {
          filteredBookings.add(doc);
        }
      }
    }
    
    return filteredBookings;
  }

  void _loadServiceOptions() async {
    try {
      final snapshot = await _firestore.collection('serviceTypes').get();
      final services = ['All'];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final serviceName = data['name']?.toString() ?? '';
        if (serviceName.isNotEmpty) {
          services.add(serviceName);
        }
      }
      setState(() {
        _serviceOptions = services;
      });
    } catch (e) {
      print('Error loading service options: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadServiceOptions();
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'new parts arrived':
        return Colors.purple;
      case 'installation':
        return Colors.orange;
      case 'final inspection':
        return Colors.amber;
      case 'ready for pick up':
        return Colors.blue;
      case 'picked up':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatUpdatedAt(dynamic updatedAt) {
    if (updatedAt == null) return 'Unknown';
    
    DateTime dateTime;
    if (updatedAt is Timestamp) {
      dateTime = updatedAt.toDate();
    } else if (updatedAt is String) {
      try {
        dateTime = DateTime.parse(updatedAt);
      } catch (e) {
        return 'Invalid date';
      }
    } else {
      return 'Unknown';
    }
    
    // Format as "13 Sep 2025, 01:53 AM"
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$day $month $year, $displayHour:$minute $period';
  }

  void _makePhoneCall(String phoneNumber) {
    // For now, show a dialog with the phone number
    // In a real app, you would use url_launcher to make the call
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Service Center'),
        content: Text('Call $phoneNumber for assistance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $phoneNumber...')),
              );
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please login to view records'))
          : FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _getFilteredBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final filteredBookings = snapshot.data ?? [];
                
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search by booking ID...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Date Filter Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _selectStartDate,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _formatDate(_selectedStartDate),
                                          style: TextStyle(
                                            color: _selectedStartDate == null ? Colors.grey.shade600 : Colors.black, 
                                            fontSize: 16,
                                            fontWeight: _selectedStartDate == null ? FontWeight.normal : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (_selectedStartDate != null)
                                        GestureDetector(
                                          onTap: () => setState(() => _selectedStartDate = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _selectEndDate,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _formatDate(_selectedEndDate),
                                          style: TextStyle(
                                            color: _selectedEndDate == null ? Colors.grey.shade600 : Colors.black, 
                                            fontSize: 16,
                                            fontWeight: _selectedEndDate == null ? FontWeight.normal : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (_selectedEndDate != null)
                                        GestureDetector(
                                          onTap: () => setState(() => _selectedEndDate = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedStartDate != null || _selectedEndDate != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _clearDateFilters,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Icon(Icons.clear, size: 16, color: Colors.red.shade600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Filter Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            // Filter Labels
                            Row(
                              children: [
                                if (_selectedTab == 0) ...[
                                  Expanded(
                                    child: Text(
                                      'Filter by Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    'Filter by Service',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Filter Dropdowns
                            Row(
                              children: [
                                // Status Filter - Only show for UPCOMING tab
                                if (_selectedTab == 0) ...[
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.white,
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedStatus,
                                          isExpanded: true,
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                          items: _statusOptions.map((String status) {
                                            return DropdownMenuItem<String>(
                                              value: status,
                                              child: Text(
                                                status,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _onStatusFilterChanged,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                // Service Filter - Always show
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedService,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                        items: _serviceOptions.map((String service) {
                                          return DropdownMenuItem<String>(
                                            value: service,
                                            child: Text(
                                              service,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _onServiceFilterChanged,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Tab Selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _onTabChanged(0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0 ? Colors.blue.shade50 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _selectedTab == 0 ? Colors.blue.shade600 : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      'UPCOMING',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 0 ? Colors.blue.shade700 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _onTabChanged(1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1 ? Colors.blue.shade50 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _selectedTab == 1 ? Colors.blue.shade600 : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      'PAST',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 1 ? Colors.blue.shade700 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Results count and pagination
                      Builder(
                        builder: (context) {
                          // Calculate pagination
                          final totalPages = (filteredBookings.length / _itemsPerPage).ceil();
                          final startIndex = (_currentPage - 1) * _itemsPerPage;
                          final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredBookings.length);
                          final paginatedBookings = filteredBookings.sublist(startIndex, endIndex);
                          
                          return Column(
                            children: [
                              // Results count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Showing ${paginatedBookings.length} of ${filteredBookings.length} bookings',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      
                      // Bookings List
                      if (filteredBookings.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedTab == 0 ? Icons.schedule : Icons.history,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedTab == 0 
                                    ? 'No upcoming bookings'
                                    : 'No past bookings',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: paginatedBookings.length + (totalPages > 1 ? 1 : 0), // Add 1 for pagination controls
                          itemBuilder: (context, index) {
                            // Show pagination controls after all booking cards
                            if (index == paginatedBookings.length && totalPages > 1) {
                              return Container(
                                margin: const EdgeInsets.only(top: 16, bottom: 16),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            minimumSize: const Size(0, 36),
                                          ),
                                        ),

                                        // Page numbers (show max 5 pages)
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
                                                        child: Text(
                                                          '$pageNumber',
                                                          style: TextStyle(
                                                            color: isCurrentPage ? Colors.white : Colors.black87,
                                                            fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
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

                                        // Next button
                                        ElevatedButton.icon(
                                          onPressed: _currentPage < totalPages ? () => _goToPage(_currentPage + 1) : null,
                                          icon: const Icon(Icons.chevron_right, size: 18),
                                          label: const Text('Next'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _currentPage < totalPages ? Colors.blue.shade600 : Colors.grey.shade300,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            minimumSize: const Size(0, 36),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            // Show booking cards
                            final doc = paginatedBookings[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildBookingCard(doc.id, data);
                          },
                        ),
                            ],
                          );
                        },
                      ),
                    ],
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

  Widget _buildBookingCard(String bookingId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Unknown';
    final serviceDate = data['serviceDate'] ?? '';
    final timeSlot = data['timeSlot'] ?? '';
    final paidAmount = data['paid_amount'] ?? '0';
    final remark = data['remark'] ?? '';
    final carId = data['carId'] ?? '';
    final branchId = data['branchId'] ?? '';
    final serviceTypeId = data['serviceTypeId'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (serviceTypeId.isNotEmpty)
                        FutureBuilder<DocumentSnapshot>(
                          future: _firestore.collection('serviceTypes').doc(serviceTypeId).get(),
                          builder: (context, serviceSnapshot) {
                            if (serviceSnapshot.connectionState == ConnectionState.waiting) {
                              return const Text(
                                'Loading...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              );
                            }
                            if (serviceSnapshot.hasError || !serviceSnapshot.hasData) {
                              return const Text(
                                'Unknown Service',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              );
                            }
                            final serviceData = serviceSnapshot.data!.data() as Map<String, dynamic>?;
                            final serviceName = serviceData?['name'] ?? 'Unknown Service';
                            return Text(
                              serviceName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            );
                          },
                        )
                      else
                        const Text(
                          'Unknown Service',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Booking ID: $bookingId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusBackgroundColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Service Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Text(
                  'General Motors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            serviceDate,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTab == 0 ? 'UPDATE AT' : 'PICK-UP TIME',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatUpdatedAt(data['updatedAt']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Expandable Details
          ExpansionTile(
            title: const Text(
              'Service Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (branchId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('branches').doc(branchId).get(),
                        builder: (context, branchSnapshot) {
                          if (branchSnapshot.connectionState == ConnectionState.waiting) {
                            return _buildDetailRow('Branch', 'Loading...');
                          }
                          if (branchSnapshot.hasError || !branchSnapshot.hasData) {
                            return _buildDetailRow('Branch', 'Unknown Branch');
                          }
                          final branchData = branchSnapshot.data!.data() as Map<String, dynamic>?;
                          final branchName = branchData?['name'] ?? 'Unknown Branch';
                          return _buildDetailRow('Branch', branchName);
                        },
                      )
                    else
                      _buildDetailRow('Branch', 'Unknown Branch'),
                    _buildDetailRow('Amount Paid', 'RM $paidAmount'),
                    _buildDetailRow('Payment Method', data['payment_method'] ?? 'Unknown'),
                    if (remark.isNotEmpty) _buildDetailRow('Remark', remark),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Car Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (carId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('car').doc(carId).get(),
                        builder: (context, carSnapshot) {
                          if (carSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (carSnapshot.hasError || !carSnapshot.hasData) {
                            return const Text('Car information not available');
                          }
                          final carData = carSnapshot.data!.data() as Map<String, dynamic>?;
                          if (carData == null) {
                            return const Text('Car information not available');
                          }
                          return Column(
                            children: [
                              _buildDetailRow('Car Model', carData['model'] ?? 'Unknown'),
                              _buildDetailRow('Car Plate', carData['plate'] ?? 'Unknown'),
                              _buildDetailRow('Registration ID', carData['regId'] ?? 'Unknown'),
                            ],
                          );
                        },
                      )
                    else
                      const Text('Car information not available'),
                  ],
                ),
              ),
            ],
          ),
          
          // Action Buttons
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          SizedBox(
            height: 48,
            child: _selectedTab == 0 
                ? Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Call functionality
                            _makePhoneCall('01161781003');
                          },
                          child: const Center(
                            child: Text(
                              'CALL',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.grey.shade300,
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Navigate to track order page
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => TrackOrderPage(
                                  bookingId: bookingId,
                                  bookingData: data,
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
                          child: const Center(
                            child: Text(
                              'TRACK',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Call functionality for past bookings
                            _makePhoneCall('01161781003');
                          },
                          child: const Center(
                            child: Text(
                              'CALL',
                              style: TextStyle(
                                color: Colors.blue,
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
