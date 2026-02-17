import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/passenger_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'ride_simulation_screen.dart';
import 'feedback_page.dart';

class PaymentPage extends StatefulWidget {
  final String? bookingId;
  final String? rideId;
  final String? driverId;
  final double? fare;
  final Map<String, dynamic>? ride;
  final List<Passenger>? passengers;

  const PaymentPage({
    super.key,
    this.bookingId,
    this.rideId,
    this.driverId,
    this.fare,
    this.ride,
    this.passengers,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void _openCheckout() {
    num fareValue;
    if (widget.fare != null) {
      fareValue = widget.fare!;
    } else if (widget.ride != null && widget.ride!['fare'] is String) {
      fareValue = double.tryParse(widget.ride!['fare']) ?? 0;
    } else if (widget.ride != null && widget.ride!['fare'] is num) {
      fareValue = widget.ride!['fare'];
    } else {
      fareValue = 0;
    }

    var options = {
      'key': 'rzp_test_RBcLkRDIOCOnml',
      'amount': (fareValue * 100).toInt(),
      'name': 'Campus Ride',
      'description': 'Booking Ride',
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
      },
      'theme': {"color": "#0D47A1"}
    };
    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    if (widget.bookingId != null) {
      final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId);
      final bookingSnap = await bookingRef.get();
      Map<String, dynamic>? b;
      if (bookingSnap.exists) {
        b = bookingSnap.data() as Map<String, dynamic>;
      }

      await bookingRef.update({
        'status': 'completed',
        'paymentId': response.paymentId,
        'paymentMethod': 'online',
      });

      if (b != null && b['driverId'] != null) {
        final num amount = (b['fare'] is num) ? b['fare'] : (num.tryParse('${b['fare']}') ?? 0);
        await NotificationService.notifyDriverPaymentStatus(
          driverUserId: b['driverId'],
          amount: amount,
          method: 'online',
          rideData: {
            'from': b['from'],
            'to': b['to'],
            'date': b['date'],
            'time': b['time'],
          },
        );
      }

      if (widget.driverId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackPage(
              driverId: widget.driverId!,
              bookingId: widget.bookingId!,
            ),
          ),
        );
      }
    } else {
      final user = FirebaseAuth.instance.currentUser!;
      final auth = Provider.of<AuthService>(context, listen: false);
      final profile = auth.profile;

      try {
        final newBooking = await FirebaseFirestore.instance.collection('bookings').add({
          'rideId': widget.ride!['id'],
          'userId': user.uid,
          'riderName': profile?['displayName'] ?? 'N/A',
          'riderContact': user.phoneNumber ?? 'N/A',
          'driverId': widget.ride!['driverId'],
          'fare': widget.fare,
          'status': 'confirmed',
          'paymentId': response.paymentId,
          'createdAt': FieldValue.serverTimestamp(),
          'from': widget.ride!['from'],
          'to': widget.ride!['to'],
          'date': widget.ride!['date'],
          'time': widget.ride!['time'],
          'costPerKm': widget.ride!['costPerKm'],
          'vehicleRegNo': widget.ride!['vehicleRegNo'],
          'driverContact': widget.ride!['driverContact'],
          'vehiclePhoto': widget.ride!['vehiclePhoto'],
          'passengers': widget.passengers?.map((p) => p.toMap()).toList(),
          'numberOfSeats': widget.passengers?.length,
        });

        NotificationService.sendRideNotification(
          userId: user.uid,
          type: 'ride_booked',
          rideData: {
            'from': widget.ride!['from'],
            'to': widget.ride!['to'],
            'fare': widget.fare,
            'date': widget.ride!['date'],
            'time': widget.ride!['time'],
            'paymentId': response.paymentId,
          },
        );

        await NotificationService.notifyDriverPaymentStatus(
          driverUserId: widget.ride!['driverId'],
          amount: (widget.fare ?? 0),
          method: 'online',
          rideData: {
            'from': widget.ride!['from'],
            'to': widget.ride!['to'],
            'date': widget.ride!['date'],
            'time': widget.ride!['time'],
          },
        );

        await NotificationService.notifyDriverOfBooking(
          driverUserId: widget.ride!['driverId'],
          riderName: profile?['displayName'] ?? 'Rider',
          riderContact: user.phoneNumber ?? '',
          rideData: {
            'from': widget.ride!['from'],
            'to': widget.ride!['to'],
            'fare': widget.fare,
            'date': widget.ride!['date'],
            'time': widget.ride!['time'],
          },
          numberOfSeats: widget.passengers?.length,
        );

        if (mounted) {
          final from = widget.ride!['from']?.toString();
          final to = widget.ride!['to']?.toString();
          final driverId = widget.ride!['driverId']?.toString();

          if (from == null || to == null || driverId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Ride data is incomplete. Cannot start simulation.')),
            );
            Navigator.pop(context);
            return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RideSimulationScreen(
                from: from,
                to: to,
                rideId: widget.ride!['id'],
                driverId: driverId,
                bookingId: newBooking.id,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving booking: $e')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  void _handleError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
    Navigator.pop(context);
  }

  void _handleWallet(ExternalWalletResponse response) {}

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    num fareValue;
    if (widget.fare != null) {
      fareValue = widget.fare!;
    } else if (widget.ride != null && widget.ride!['fare'] is String) {
      fareValue = double.tryParse(widget.ride!['fare']) ?? 0;
    } else if (widget.ride != null && widget.ride!['fare'] is num) {
      fareValue = widget.ride!['fare'];
    } else {
      fareValue = 0;
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Complete Payment',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Amount Due',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${fareValue.toString()}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              Text(
                'Choose Payment Method',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: _openCheckout,
                  icon: Icon(
                    Icons.payment,
                    color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                  ),
                  label: Text(
                    'Pay Online',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.transparent,
                    width: 1,
                  ),
                ),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (widget.bookingId != null) {
                      final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId);
                      final snap = await bookingRef.get();
                      Map<String, dynamic>? b;
                      if (snap.exists) b = snap.data() as Map<String, dynamic>;

                      await bookingRef.update({
                        'status': 'completed',
                        'paymentMethod': 'cash',
                      });

                      if (b != null && b['driverId'] != null) {
                        final num amount = (b['fare'] is num) ? b['fare'] : (num.tryParse('${b['fare']}') ?? 0);
                        await NotificationService.notifyDriverPaymentStatus(
                          driverUserId: b['driverId'],
                          amount: amount,
                          method: 'cash',
                          rideData: {
                            'from': b['from'],
                            'to': b['to'],
                            'date': b['date'],
                            'time': b['time'],
                          },
                        );
                      }

                      if (widget.driverId != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeedbackPage(
                              driverId: widget.driverId!,
                              bookingId: widget.bookingId!,
                            ),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    } else {
                      final user = FirebaseAuth.instance.currentUser!;
                      final auth = Provider.of<AuthService>(context, listen: false);
                      final profile = auth.profile;

                      try {
                        final newBooking = await FirebaseFirestore.instance.collection('bookings').add({
                          'rideId': widget.ride!['id'],
                          'userId': user.uid,
                          'riderName': profile?['displayName'] ?? 'N/A',
                          'riderContact': user.phoneNumber ?? 'N/A',
                          'driverId': widget.ride!['driverId'],
                          'fare': fareValue,
                          'status': 'confirmed',
                          'paymentMethod': 'cash',
                          'createdAt': FieldValue.serverTimestamp(),
                          'from': widget.ride!['from'],
                          'to': widget.ride!['to'],
                          'date': widget.ride!['date'],
                          'time': widget.ride!['time'],
                          'costPerKm': widget.ride!['costPerKm'],
                          'vehicleRegNo': widget.ride!['vehicleRegNo'],
                          'driverContact': widget.ride!['driverContact'],
                          'vehiclePhoto': widget.ride!['vehiclePhoto'],
                          'passengers': widget.passengers?.map((p) => p.toMap()).toList(),
                          'numberOfSeats': widget.passengers?.length,
                        });

                        await NotificationService.notifyDriverOfBooking(
                          driverUserId: widget.ride!['driverId'],
                          riderName: profile?['displayName'] ?? 'Rider',
                          riderContact: user.phoneNumber ?? '',
                          rideData: {
                            'from': widget.ride!['from'],
                            'to': widget.ride!['to'],
                            'fare': fareValue,
                            'date': widget.ride!['date'],
                            'time': widget.ride!['time'],
                          },
                          numberOfSeats: widget.passengers?.length,
                        );

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RideSimulationScreen(
                                from: widget.ride!['from'],
                                to: widget.ride!['to'],
                                rideId: widget.ride!['id'],
                                driverId: widget.ride!['driverId'],
                                bookingId: newBooking.id,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving cash booking: $e')),
                          );
                          Navigator.pop(context);
                        }
                      }
                    }
                  },
                  icon: Icon(Icons.money, color: theme.primaryColor),
                  label: Text(
                    'Pay Cash',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
