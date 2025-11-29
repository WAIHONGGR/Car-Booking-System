import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_branch_page.dart';
import 'payment_page.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final Map<String, dynamic> car;
  final String serviceId;
  final String carId;
  final Map<String, dynamic>? selectedBranch;
  
  const BookingPage({
    super.key, 
    required this.service, 
    required this.car, 
    required this.serviceId,
    required this.carId,
    this.selectedBranch,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime? _selectedDate;
  String? _selectedSlotId;
  Map<String, dynamic>? _selectedBranch;
  Map<String, dynamic>? _selectedTimeSlot;
  final TextEditingController _remarkController = TextEditingController();
  Set<String> _bookedTimeSlots = {}; // Track booked time slots

  @override
  void initState() {
    super.initState();
    // Set the selected branch if provided from BranchDetailPage
    if (widget.selectedBranch != null) {
      _selectedBranch = widget.selectedBranch;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Choose Date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _selectBranch() async {
    final selected = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SelectBranchPage(
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
    if (selected != null && mounted) {
      setState(() => _selectedBranch = selected);
      // Check for existing bookings when branch changes
      if (_selectedDate != null) {
        _checkExistingBookings();
      }
    }
  }

  void _checkExistingBookings() async {
    if (_selectedDate == null || _selectedBranch == null) return;

    try {
      final formattedDate = _formatDateForFirestore(_selectedDate!);
      final branchId = _selectedBranch!['id'];

      // Query existing bookings for the same date and branch
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('serviceDate', isEqualTo: formattedDate)
          .where('branchId', isEqualTo: branchId)
          .get();

      // Extract booked time slot IDs
      final bookedSlots = querySnapshot.docs
          .map((doc) => doc.data()['timeSlotId'] as String?)
          .where((slotId) => slotId != null)
          .cast<String>()
          .toSet();

      if (mounted) {
        setState(() {
          _bookedTimeSlots = bookedSlots;
        });
      }
    } catch (e) {
      print('Error checking existing bookings: $e');
      // On error, allow all slots (fail-safe approach)
      if (mounted) {
        setState(() {
          _bookedTimeSlots = {};
        });
      }
    }
  }

  String _formatDateForFirestore(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _validateAndProceed() {
    final remark = _remarkController.text.trim();
    
    // Check if remark exceeds 1000 characters
    if (remark.length > 1000) {
      _showValidationError('Remark cannot exceed 1000 characters');
      return;
    }

    // Prepare booking data
    final bookingData = {
      'service': widget.service,
      'serviceId': widget.serviceId, // Pass the service document ID
      'car': widget.car, // Pass the car information
      'carId': widget.carId, // Pass the car document ID
      'branch': _selectedBranch,
      'date': _selectedDate,
      'timeSlotId': _selectedSlotId,
      'timeSlot': _selectedTimeSlot, // Pass the actual time slot data
      'remark': remark,
      'timestamp': DateTime.now(),
    };
    
    // Navigate to payment page
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PaymentPage(bookingData: bookingData),
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
    final canProceed = _selectedDate != null && _selectedSlotId != null && _selectedBranch != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch selection
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _selectBranch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectedBranch == null
                            ? Text('Select Branch', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedBranch?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(_selectedBranch?['location'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                ],
                              ),
                      ),
                      if (_selectedBranch != null)
                        TextButton(
                          onPressed: _selectBranch,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: const Text('CHANGE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('When do you want the service?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            const Text('Select Date', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
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
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  // Check for existing bookings when date changes
                  if (_selectedBranch != null) {
                    _checkExistingBookings();
                  }
                }
              },
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        _formatDate(_selectedDate),
                        style: TextStyle(
                          color: _selectedDate == null ? Colors.grey.shade600 : Colors.black, 
                          fontSize: 16,
                          fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Select Pick-up Time Slot', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('timeSlots').snapshots(),
              builder: (context, snapshot) {
                final slots = snapshot.data?.docs ?? [];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final slot = slots[i].data();
                    final slotId = slots[i].id;
                    
                    // Format time slot with proper AM/PM
                    final slotStart = slot['slotStart'] ?? '';
                    final slotEnd = slot['slotEnd'] ?? '';
                    final slotText = _formatTimeSlot(slotStart, slotEnd);
                    final selected = _selectedSlotId == slotId;
                    final disabled = _bookedTimeSlots.contains(slotId); // Check if slot is already booked
                    return GestureDetector(
                      onTap: disabled ? null : () => setState(() {
                        _selectedSlotId = slotId;
                        _selectedTimeSlot = slot;
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: disabled
                              ? Colors.grey.shade100
                              : selected
                                  ? const Color(0xFFE8EDFF) // Light blue background for selected
                                  : Colors.white,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF3F51B5) // Darker blue border for selected
                                : disabled
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade300,
                            width: selected ? 1 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          slotText,
                          style: TextStyle(
                            color: disabled
                                ? Colors.grey.shade400
                                : selected
                                    ? const Color(0xFF3F51B5) // Darker blue text for selected
                                    : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Remark', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${_remarkController.text.length}/1000',
                  style: TextStyle(
                    fontSize: 12,
                    color: _remarkController.text.length > 1000 ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remarkController,
              maxLines: 3,
              maxLength: 1000,
              onChanged: (value) {
                setState(() {}); // Update character count
              },
              decoration: InputDecoration(
                hintText: 'Enter your remarks...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                counterText: '', // Hide default counter
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.service['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(widget.service['price'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            SizedBox(
              height: 40,
               child: ElevatedButton(
                 onPressed: canProceed ? _validateAndProceed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canProceed ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  foregroundColor: Colors.white,
                ),
                child: const Text('PROCEED', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeSlot(String slotStart, String slotEnd) {
    // Parse the start time to determine if it's AM or PM
    final startHour = int.tryParse(slotStart.split(':')[0]) ?? 0;
    final period = startHour >= 12 ? 'PM' : 'AM';
    
    return '$slotStart - $slotEnd$period';
  }
}
