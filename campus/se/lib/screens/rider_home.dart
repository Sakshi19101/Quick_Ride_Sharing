import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ride_search_card.dart';
import 'package:campus_ride_sharing_step1/screens/payment_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_ride_sharing_step1/services/ride_service.dart';
import 'package:campus_ride_sharing_step1/screens/my_bookings.dart';
import 'package:campus_ride_sharing_step1/services/api_key.dart';
import 'package:campus_ride_sharing_step1/screens/passenger_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:campus_ride_sharing_step1/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:campus_ride_sharing_step1/screens/emergency_contact_screen.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(22.3072, 73.1812); // Vadodara

  bool _sharingLocation = false;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _toggleLocationSharing(bool share) {
    if (share) {
      _requestLocationPermission();
    }
    setState(() {
      _sharingLocation = share;
    });
    // Logic to start/stop sharing location would go here
  }

  void _showSosOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Send SOS via..."),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sms, color: Colors.blue),
                title: const Text("SMS"),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendSOS('sms');
                },
              ),
              ListTile(
                leading: const Icon(Icons.whatshot, color: Colors.green),
                title: const Text("WhatsApp"),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendSOS('whatsapp');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendSOS(String medium) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to use SOS.')),
      );
      return;
    }

    try {
      // 1. Fetch emergency contact from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final emergencyContact = userDoc.data()?['emergencyContact'] as String?;

      if (emergencyContact == null || emergencyContact.isEmpty) {
        // 2. If no contact, prompt user to set one up
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Emergency Contact'),
            content: const Text('Please set up an emergency contact before using the SOS feature.'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: const Text('Set Contact'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EmergencyContactScreen()));
                },
              ),
            ],
          ),
        );
        return;
      }

      // 3. Get current location
      await _requestLocationPermission();
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      // 4. Create message
      String message = "SOS! I'm in an emergency. My current location is: $googleMapsUrl";

      Uri uri;
      if (medium == 'sms') {
        uri = Uri(
          scheme: 'sms',
          path: emergencyContact,
          queryParameters: {'body': message},
        );
      } else { // whatsapp
        final cleanEmergencyContact = emergencyContact.replaceAll(RegExp(r'[^\d]'), '');
        uri = Uri.parse("https://wa.me/$cleanEmergencyContact?text=${Uri.encodeComponent(message)}");
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${medium == 'sms' ? 'SMS app' : 'WhatsApp'}.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SOS: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Find a Ride",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showSosOptions,
              icon: Icon(
                Icons.emergency,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                "SOS",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          _buildGoogleMap(),
          _buildAvailableRidesSheet(),
        ],
      ),
    );
  }

  void _removeRide(String rideId) {
    FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
  }

  bool _isRideOutdated(Map<String, dynamic> ride) {
    final rideDate = ride['date'] as String?;
    final rideTime = ride['time'] as String?;
    if (rideDate == null || rideTime == null) {
      return false;
    }
    try {
      // Try parsing with 24-hour format first
      final rideDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$rideDate $rideTime');
      return rideDateTime.isBefore(DateTime.now());
    } catch (e) {
      try {
        // If that fails, try parsing with 12-hour AM/PM format
        final rideDateTime = DateFormat('yyyy-MM-dd h:mm a').parse('$rideDate $rideTime');
        return rideDateTime.isBefore(DateTime.now());
      } catch (e) {
        return false;
      }
    }
  }

  Widget _buildGoogleMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("drivers").where("sharingLocation", isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading map data: ${snapshot.error}"));
        }

        final markers = <Marker>{};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['lat'] != null && data['lng'] != null) {
              markers.add(Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(data['lat'], data['lng']),
                infoWindow: InfoWindow(title: data['name'] ?? "Driver"),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ));
            }
          }
        }
        return GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: _center, zoom: 13),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          padding: const EdgeInsets.only(bottom: 200), // Adjust padding for the sheet
        );
      },
    );
  }

  Widget _buildAvailableRidesSheet() {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: theme.dividerTheme.color ?? Colors.transparent,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Available Rides",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Share Location",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: _sharingLocation,
                            onChanged: _toggleLocationSharing,
                            activeColor: theme.primaryColor,
                            activeTrackColor: theme.primaryColor.withOpacity(0.3),
                            inactiveThumbColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            inactiveTrackColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(
                height: 1,
                color: theme.dividerTheme.color,
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              
              // Rides List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("rides")
                      .where('seatsAvailable', isGreaterThan: 0)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Error loading rides: ${snapshot.error}",
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24.0),
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.no_crash,
                                    size: 40,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No rides available",
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Check back later or be the first to offer a ride!",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final ride = docs[index].data() as Map<String, dynamic>;
                        final rideId = docs[index].id;

                        // Skip outdated rides
                        if (_isRideOutdated(ride)) {
                          _removeRide(rideId);
                          return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: RideSearchCard(
                            ride: ride,
                            rideId: rideId,
                            onBook: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PassengerDetailsScreen(
                                    numberOfSeats: ride['availableSeats'] ?? 1,
                                    ride: ride,
                                  ),
                                ),
                              );
                            },
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
      },
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, String rideId) {
    final seatsAvailable = ride['seatsAvailable'] ?? 0;
    final driverId = ride['driverId'] as String?;
    final isOutdated = _isRideOutdated(ride);

    return _SimpleExpandableRideCard(
      ride: ride,
      rideId: rideId,
      seatsAvailable: seatsAvailable,
      driverId: driverId,
      isOutdated: isOutdated,
      onRemoveRide: _removeRide,
      onShowSeatSelector: _showSeatSelector,
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? Colors.grey[700]),
      label: Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700])),
      backgroundColor: (color ?? Colors.grey[700])!.withOpacity(0.1),
    );
  }

  void _showSeatSelector(BuildContext context, Map<String, dynamic> ride, String rideId, int seatsAvailable) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to book a ride.')));
      return;
    }

    int numberOfSeats = 1;
    List<int> seatOptions = List<int>.generate(seatsAvailable, (i) => i + 1);
    if (seatOptions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Select Number of Seats'),
              content: DropdownButton<int>(
                value: numberOfSeats,
                isExpanded: true,
                onChanged: (int? newValue) {
                  if (newValue != null) setState(() => numberOfSeats = newValue);
                },
                items: seatOptions.map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(value: value, child: Text("$value Seat${value > 1 ? 's' : ''}"));
                }).toList(),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final rideWithId = Map<String, dynamic>.from(ride);
                    rideWithId['id'] = rideId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PassengerDetailsScreen(numberOfSeats: numberOfSeats, ride: rideWithId),
                      ),
                    );
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text("No rides available right now.", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("Please check back later.", style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SimpleExpandableRideCard extends StatefulWidget {
  final Map<String, dynamic> ride;
  final String rideId;
  final int seatsAvailable;
  final String? driverId;
  final bool isOutdated;
  final Function(String) onRemoveRide;
  final Function(BuildContext, Map<String, dynamic>, String, int) onShowSeatSelector;

  const _SimpleExpandableRideCard({
    required this.ride,
    required this.rideId,
    required this.seatsAvailable,
    required this.driverId,
    required this.isOutdated,
    required this.onRemoveRide,
    required this.onShowSeatSelector,
  });

  @override
  State<_SimpleExpandableRideCard> createState() => _SimpleExpandableRideCardState();
}

class _SimpleExpandableRideCardState extends State<_SimpleExpandableRideCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic ride info
            ListTile(
              leading: (widget.ride['vehiclePhoto'] != null && widget.ride['vehiclePhoto'].toString().isNotEmpty)
                  ? CircleAvatar(backgroundImage: NetworkImage(widget.ride['vehiclePhoto']))
                  : const CircleAvatar(child: Icon(Icons.directions_car, color: Colors.white)),
              title: Text("${widget.ride['from'] ?? 'Unknown'} → ${widget.ride['to'] ?? 'Unknown'}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: (widget.driverId == null || widget.driverId!.isEmpty)
                  ? const Text("Driver not specified", style: TextStyle(color: Colors.red))
                  : FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Error loading driver', style: TextStyle(color: Colors.red));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Driver: loading...');
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Text('Driver not found', style: TextStyle(color: Colors.red));
                        }
                        final driverData = snapshot.data!.data() as Map<String, dynamic>?;
                        final driverName = driverData?['displayName'] ?? 'Driver';
                        final avgRating = driverData?['averageRating'] as double? ?? 0.0;
                        return Text('$driverName (⭐ ${avgRating.toStringAsFixed(1)})');
                      },
                    ),
            ),
            const Divider(),
            
            // Date, time, and seats info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildInfoChip(Icons.calendar_today, "${widget.ride['date']} at ${widget.ride['time']}"),
                  _buildInfoChip(Icons.airline_seat_recline_normal, '${widget.seatsAvailable} Seats Left', color: Colors.green),
                ],
              ),
            ),
            
            // Price and action buttons (responsive to avoid overflow)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    "₹${widget.ride['fare']}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // View Details button
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                        label: Text(_isExpanded ? 'Hide' : 'View'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                      if (widget.isOutdated) ...[
                        const Chip(
                          label: Text("Expired"),
                          backgroundColor: Colors.grey,
                        ),
                        SizedBox(
                          height: 28,
                          child: TextButton.icon(
                            onPressed: () => widget.onRemoveRide(widget.rideId),
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text("Remove", style: TextStyle(color: Colors.red, fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ] else if (widget.driverId != null && widget.driverId == FirebaseAuth.instance.currentUser?.uid) ...[
                        const Chip(
                          label: Text("Your Ride"),
                          backgroundColor: Colors.orange,
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => widget.onShowSeatSelector(context, widget.ride, widget.rideId, widget.seatsAvailable),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text("Book Now"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            // Expanded details section - only show actual posted fields
            if (_isExpanded) ...[
              const Divider(height: 20),
              _buildExpandedDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ride Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        // Only show fields that are actually posted in the ride
        _buildDetailRow(Icons.person_outline, 'Driver Contact', widget.ride['driverContact'] ?? 'N/A'),
        _buildDetailRow(Icons.directions_car, 'Vehicle', "${widget.ride['vehicleName'] ?? 'N/A'} (${widget.ride['vehicleType'] ?? 'N/A'})"),
        _buildDetailRow(Icons.confirmation_number, 'Vehicle Number', widget.ride['vehicleRegNo'] ?? 'N/A'),
        _buildDetailRow(Icons.access_time, 'Departure Time', "${widget.ride['date']} at ${widget.ride['time']}"),
        _buildDetailRow(Icons.people, 'Available Seats', '${widget.seatsAvailable}'),
        _buildDetailRow(Icons.attach_money, 'Fare per Person', '₹${widget.ride['fare']}'),
        if (widget.ride['costPerKm'] != null)
          _buildDetailRow(Icons.speed, 'Cost per KM', '₹${widget.ride['costPerKm']}'),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? Colors.grey[700]),
      label: Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700])),
      backgroundColor: (color ?? Colors.grey[700])!.withOpacity(0.1),
    );
  }
}
