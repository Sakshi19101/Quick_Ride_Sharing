import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart'; // Make sure this import is correct
import 'driver_ride_simulation_screen.dart';

class MyRides extends StatefulWidget {
  const MyRides({super.key});

  @override
  State<MyRides> createState() => _MyRidesState();
}

class _MyRidesState extends State<MyRides> {
  Future<void> _completeRide(String rideId) async {
    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(rideRef, {'status': 'completed'});

    for (var doc in bookingsSnapshot.docs) {
      batch.update(doc.reference, {'status': 'completed'});
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ride marked as completed!'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _cancelRide(DocumentReference rideRef) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text(
            'Are you sure you want to cancel this ride? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (confirm == true) {
      await rideRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ride cancelled.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }
  
  void _showOtpDialog(BuildContext context, String rideId, String bookingId, String correctOtp, Map<String, dynamic> rideData) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Rider\'s OTP'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'OTP'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (otpController.text == correctOtp) {
                await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'status': 'started'});
                Navigator.of(context).pop(); // Close the dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverRideSimulationScreen(
                      rideId: rideId, 
                      from: rideData['from'], 
                      to: rideData['to'], 
                      driverId: FirebaseAuth.instance.currentUser!.uid, 
                      bookingId: bookingId
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect OTP. Please try again.')),
                );
              }
            },
            child: const Text('Verify & Start'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Rides")),
        body: const Center(child: Text("Please log in to see your rides.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Posted Rides"), leading: const BackButton()),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("rides")
            .where('driverId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No rides found"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final ride = docs[index];
              final rideData = ride.data() as Map<String, dynamic>;
              final rideId = ride.id;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${rideData['from']} to ${rideData['to']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('On ${rideData['date']} at ${rideData['time']}'),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('bookings').where('rideId', isEqualTo: rideId).snapshots(),
                        builder: (context, bookingSnapshot) {
                          if (!bookingSnapshot.hasData) return const SizedBox.shrink();
                          final bookings = bookingSnapshot.data!.docs;
                          if (bookings.isEmpty) return const Text('No bookings yet.');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Passengers:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...bookings.asMap().entries.map((entry) {
                                final i = entry.key;
                                final booking = entry.value;
                                final bookingData = booking.data() as Map<String, dynamic>;
                                final passengerId = bookingData['passengerId'] ?? bookingData['userId'] ?? '';
                                final riderName = bookingData['riderName'] ?? passengerId;
                                final riderContact = bookingData['riderContact'] ?? '';
                                final bookingStatus = bookingData['status'] ?? 'Unknown';
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text('Rider ${i + 1}: $riderName'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Status: $bookingStatus'),
                                        if (riderContact.isNotEmpty)
                                          Text('Contact: $riderContact'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton(
                                          onPressed: (bookingStatus == 'confirmed' && rideData['status'] != 'completed')
                                              ? () {
                                                  final correctOtp = bookingData['otp'];
                                                  _showOtpDialog(context, rideId, booking.id, correctOtp, rideData);
                                                }
                                              : null,
                                          child: const Text('Start Ride'),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.chat),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatScreen(
                                                  rideId: rideId,
                                                  otherUserId: passengerId,
                                                  otherUserName: riderName,
                                                  otherUserPhone: riderContact,
                                                ),
                                              ),
                                            );
                                          },
                                          tooltip: 'Chat',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (rideData['status'] == 'started')
                            ElevatedButton(
                              onPressed: () => _completeRide(rideId),
                              child: const Text('Complete Ride'),
                            ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _cancelRide(ride.reference),
                            tooltip: 'Cancel Ride',
                          ),
                        ],
                      )
                    ],
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