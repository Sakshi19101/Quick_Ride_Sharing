import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'post_ride.dart';
import 'my_rides.dart';
import 'rider_home.dart';
import 'my_bookings.dart';
import 'driver_bookings.dart';

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        final user = auth.user;
        if (user == null) {
          return const Scaffold(body: Center(child: Text("Not logged in.")));
        }
        return _DriverHomeView(auth: auth);
      },
    );
  }
}

class _DriverHomeView extends StatefulWidget {
  final AuthService auth;
  const _DriverHomeView({required this.auth});

  @override
  State<_DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<_DriverHomeView> {
  bool _sharingLocation = false;
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _checkInitialLocationSharing();
  }

  void _checkInitialLocationSharing() async {
    if (widget.auth.user == null) return;
    final doc = await FirebaseFirestore.instance.collection("drivers").doc(widget.auth.user!.uid).get();
    if (doc.exists && doc.data()!.containsKey('sharingLocation')) {
      if (mounted) {
        setState(() {
          _sharingLocation = doc.data()!['sharingLocation'] as bool;
        });
      }
    }
  }

  Future<void> _toggleLocationSharing(bool share) async {
    final uid = widget.auth.user!.uid;
    if (share) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied || requestedPermission == LocationPermission.deniedForever) {
          _showPermissionDialog();
          return;
        }
      }
      _startLocationUpdates(uid);
      final driverName = widget.auth.profile?['displayName'] ?? 'Your driver';
      await _notifyRidersAboutLocation(driverName);
    } else {
      _stopLocationUpdates(uid);
    }
    if (mounted) {
      setState(() {
        _sharingLocation = share;
      });
    }
  }

  Future<void> _notifyRidersAboutLocation(String driverName) async {
    final driverId = widget.auth.user!.uid;
    try {
      final bookingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      if (bookingQuery.docs.isEmpty) {
        return;
      }

      for (final bookingDoc in bookingQuery.docs) {
        final booking = bookingDoc.data();
        final riderId = booking['userId'];
        final rideId = booking['rideId'];
        if (riderId != null && rideId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(riderId).get();
          final fcmToken = userDoc.data()?['fcmToken'];
          if (fcmToken != null) {
            await FCMService.sendNotification(
              fcmToken: fcmToken,
              title: 'Driver is on the way!',
              body: '$driverName has started sharing their location for your ride.',
              data: {
                'screen': 'LiveLocation',
                'rideId': rideId,
              },
            );
          }
        }
      }
      Fluttertoast.showToast(msg: 'Riders have been notified.');
    } catch (e) {
      print('Error notifying riders: $e');
      Fluttertoast.showToast(msg: 'Could not notify riders.');
    }
  }

  void _startLocationUpdates(String uid) {
    _location.onLocationChanged.listen((loc) {
      if (_sharingLocation) {
        FirebaseFirestore.instance.collection("drivers").doc(uid).set({
          "sharingLocation": true,
          "lat": loc.latitude,
          "lng": loc.longitude,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  void _stopLocationUpdates(String uid) {
    FirebaseFirestore.instance.collection("drivers").doc(uid).update({
      "sharingLocation": false,
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('To share your live location, please enable location permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Driver Dashboard",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      drawer: _buildDrawer(widget.auth),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(widget.auth, theme),
            const SizedBox(height: 32),
            _buildStatsGrid(user.uid, theme),
            const SizedBox(height: 32),
            _buildActionsGrid(context, theme),
            const SizedBox(height: 32),
            _buildLocationSharingCard(theme),
            const SizedBox(height: 32),
            Text(
              "Recent Feedback",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeedbackList(user.uid, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AuthService auth) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(auth.profile?['displayName'] ?? 'Driver', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(auth.user?.phoneNumber ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(auth.profile?['displayName']?.substring(0, 1).toUpperCase() ?? 'D', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          ListTile(leading: const Icon(Icons.directions_car_outlined), title: const Text("Post a Ride"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRide()))),
          ListTile(leading: const Icon(Icons.list_alt_outlined), title: const Text("My Posted Rides"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRides()))),
          ListTile(leading: const Icon(Icons.people_outline), title: const Text("Passenger Bookings"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverBookings()))),
          const Divider(),
          ListTile(leading: const Icon(Icons.swap_horiz_outlined), title: const Text("Switch to Rider"), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderHome()))),
          ListTile(leading: const Icon(Icons.bookmark_border_outlined), title: const Text("My Bookings (as Rider)"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookings()))),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text("Logout"), onTap: () async {
            await auth.signOut();
            Navigator.popUntil(context, (route) => route.isFirst);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthService auth, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.person,
                  size: 30,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back,",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      auth.profile?['displayName'] ?? 'Driver',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(String uid, ThemeData theme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final totalRides = data?['totalRides'] as int? ?? 0;

        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.transparent,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme: theme,
                  icon: Icons.directions_car,
                  label: 'Total Rides',
                  value: totalRides.toString(),
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _buildActionCard(
                context, 
                "Post a New Ride", 
                Icons.add_road_outlined, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRide())),
                theme,
              ),
              _buildActionCard(
                context, 
                "View My Rides", 
                Icons.list_alt_outlined, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRides())),
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: theme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSharingCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _sharingLocation 
                  ? Colors.green.withOpacity(0.1)
                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              size: 24,
              color: _sharingLocation ? Colors.green : theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Share Live Location",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Allow riders to see your real-time location on the map",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _sharingLocation,
            onChanged: _toggleLocationSharing,
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.3),
            inactiveThumbColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            inactiveTrackColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(String uid, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("drivers").doc(uid).collection("ratings").orderBy("createdAt", descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined, 
                    size: 50, 
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No feedback yet.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (c, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final rating = data['rating'] as num? ?? 0;
            final feedback = data['feedback'] as String? ?? "No comment provided.";
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerTheme.color ?? Colors.transparent,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          rating.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (index) => Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            )),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feedback,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
