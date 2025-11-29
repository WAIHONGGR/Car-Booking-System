import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'booking_success_page.dart';
import 'notification_service.dart';
import 'paypal_config.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  const PaymentPage({super.key, required this.bookingData});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedPaymentMethod = 'PayPal'; // Default selection

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'pay_after',
      'name': 'Pay after done service',
      'icon': Icons.account_balance_wallet,
      'iconColor': Colors.brown,
      'imagePath': null,
    },
    {
      'id': 'touch_n_go',
      'name': 'Pay Via Touch \'n Go',
      'icon': Icons.payment,
      'iconColor': Colors.blue,
      'imagePath': 'assets/images/tng.jpg',
    },
    {
      'id': 'paypal',
      'name': 'Pay Via PayPal',
      'icon': Icons.payment,
      'iconColor': Colors.blue,
      'imagePath': 'assets/images/paypal.png',
    },
  ];

  double _getServicePrice() {
    final priceString = widget.bookingData['service']['price'] ?? 'RM 0';
    final price = double.tryParse(priceString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    return price;
  }

  String _getCarModel() {
    return widget.bookingData['car']?['model'] ?? 'Not specified';
  }

  String _getCarPlate() {
    return widget.bookingData['car']?['plate'] ?? 'Not specified';
  }

  String _getBranchName() {
    return widget.bookingData['branch']?['name'] ?? 'Not selected';
  }

  String _getSelectedDate() {
    final date = widget.bookingData['date'] as DateTime?;
    if (date == null) return 'Not selected';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getTimeSlot() {
    final timeSlot = widget.bookingData['timeSlot'] as Map<String, dynamic>?;
    if (timeSlot == null) return 'Not selected';

    final slotStart = timeSlot['slotStart'] ?? '';
    final slotEnd = timeSlot['slotEnd'] ?? '';
    return _formatTimeSlot(slotStart, slotEnd);
  }

  String _formatTimeSlot(String slotStart, String slotEnd) {
    // Parse the start time to determine if it's AM or PM
    final startHour = int.tryParse(slotStart.split(':')[0]) ?? 0;
    final period = startHour >= 12 ? 'PM' : 'AM';
    
    return '$slotStart - $slotEnd$period';
  }

  String _getRemark() {
    return widget.bookingData['remark'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final servicePrice = _getServicePrice();
    final sstFee = 0.0; // No SST as shown in the image
    final totalPayment = servicePrice + sstFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Summary Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBookingDetailRow('Car Model', _getCarModel()),
                  const SizedBox(height: 12),
                  _buildBookingDetailRow('Car Plate', _getCarPlate()),
                  const SizedBox(height: 12),
                  _buildBookingDetailRow('Branch', _getBranchName()),
                  const SizedBox(height: 12),
                  _buildBookingDetailRow('Date', _getSelectedDate()),
                  const SizedBox(height: 12),
                  _buildBookingDetailRow('Time Slot', _getTimeSlot()),
                  if (_getRemark().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildBookingDetailRow('Remark', _getRemark()),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Summary Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Service Type', widget.bookingData['service']['name'] ?? ''),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Service Total', 'RM ${servicePrice.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Charges Fee SST', 'RM ${sstFee.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Total Payment', 'RM ${totalPayment.toStringAsFixed(2)}', isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Section
            const Text(
              'Payment Method',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method Options
            ..._paymentMethods.map((method) => _buildPaymentMethodCard(method)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.bookingData['service']['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RM ${totalPayment.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    _startPayPalPayment(totalPayment: totalPayment, servicePrice: servicePrice);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                  child: const Text(
                    'PAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedPaymentMethod = method['id'];
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Radio Button
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 16),

              // Payment Method Icon/Image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: method['imagePath'] != null ? Colors.white : method['iconColor'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: method['imagePath'] != null ? Border.all(color: Colors.grey.shade200) : null,
                ),
                child: method['imagePath'] != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    method['imagePath'],
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        method['icon'],
                        color: method['iconColor'],
                        size: 24,
                      );
                    },
                  ),
                )
                    : Icon(
                  method['icon'],
                  color: method['iconColor'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Payment Method Name
              Expanded(
                child: Text(
                  method['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPayPalPayment({required double totalPayment, required double servicePrice}) {
    final amountStr = totalPayment.toStringAsFixed(2);
    final parentContext = context;

    Navigator.of(parentContext).push(
      MaterialPageRoute(
        builder: (context) => PaypalCheckoutView(
          sandboxMode: PaypalConfig.sandbox,
          clientId: PaypalConfig.clientId,
          secretKey: PaypalConfig.secret,
          transactions: [
            {
              "amount": {
                "total": amountStr,
                "currency": PaypalConfig.currency,
                "details": {
                  "subtotal": amountStr,
                  "shipping": "0",
                  "shipping_discount": 0
                }
              },
              "description": widget.bookingData['service']?['name'] ?? 'Car Service Payment',
              "item_list": {
                "items": [
                  {
                    "name": widget.bookingData['service']?['name'] ?? 'Service',
                    "quantity": 1,
                    "price": servicePrice.toStringAsFixed(2),
                    "currency": PaypalConfig.currency
                  }
                ]
              }
            }
          ],
          note: "Thank you for your purchase!",
          onSuccess: (Map params) async {
            // Close the PayPal webview first
            if (Navigator.of(parentContext).canPop()) {
              Navigator.of(parentContext).pop();
            }
            await _saveBookingAfterPayment(paidAmount: amountStr);
          },
          onError: (error) {
            if (Navigator.of(parentContext).canPop()) {
              Navigator.of(parentContext).pop();
            }
            _showError('PayPal error. Please try again.');
          },
          onCancel: () {
            if (Navigator.of(parentContext).canPop()) {
              Navigator.of(parentContext).pop();
            }
            _showError('Payment cancelled.');
          },
        ),
      ),
    );
  }

  Future<void> _saveBookingAfterPayment({required String paidAmount}) async {
    // Show loading while saving
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pop();
        _showError('User not authenticated');
        return;
      }

      final bookingData = {
        'customerId': user.uid,
        'branchId': widget.bookingData['branch']?['id'] ?? '',
        'serviceTypeId': widget.bookingData['serviceId'] ?? '',
        'carId': widget.bookingData['carId'] ?? '',
        'serviceDate': _formatDateForFirestore(widget.bookingData['date']),
        'timeSlotId': widget.bookingData['timeSlotId'] ?? '',
        'remark': widget.bookingData['remark'] ?? '',
        'paid_amount': paidAmount,
        'payment_method': _selectedPaymentMethod,
        'status': 'Booking Successfully',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance.collection('bookings').add(bookingData);

      // Create in-app notification for successful payment / booking created
      await NotificationService.sendPaymentSuccessNotification(
        userId: user.uid,
        bookingId: docRef.id,
        serviceName: widget.bookingData['service']?['name'] ?? 'Service',
        amount: paidAmount,
      );

      Navigator.of(context).pop();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const BookingSuccessPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Failed to save booking.');
    }
  }

  String _formatDateForFirestore(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
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
}
