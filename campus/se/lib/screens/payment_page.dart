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
      'key': 'rzp_test_RBcLkRDIOCOnml', // 🔑 Replace with your Razorpay Test Key
      'amount': (fareValue * 100).toInt(), // in paise
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
      // Post-ride payment: read booking for context
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

      // Notify driver payment done (online)
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
      // Pre-ride booking payment
      final user = FirebaseAuth.instance.currentUser!;
      final auth = Provider.of<AuthService>(context, listen: false);
      final profile = auth.profile;

      try {
        // Add all relevant ride info to booking for display in MyBookings
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

        // Send booking notification
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

        // Notify driver payment done (online pre-ride)
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

        // Notify the driver about this booking with rider details
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

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              'Amount due: ₹${fareValue.toString()}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openCheckout,
              icon: const Icon(Icons.payment),
              label: const Text('Pay Online'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                if (widget.bookingId != null) {
                  // Post-ride cash payment: mark as completed and notify driver
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
                    // After cash payment, go to feedback like online
                    // ignore: use_build_context_synchronously
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
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  }
                } else {
                  // Pre-ride cash selection: create booking and proceed
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

                    // Inform driver of booking details
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
              icon: const Icon(Icons.money),
              label: const Text('Pay Cash'),
            ),
          ],
        ),
      ),
    );
  }
}