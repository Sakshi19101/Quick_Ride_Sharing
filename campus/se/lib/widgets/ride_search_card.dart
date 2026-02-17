import 'package:campus_ride_sharing_step1/screens/passenger_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class _LatLng {
  final double latitude;
  final double longitude;
  _LatLng(this.latitude, this.longitude);
}

class RideSearchCard extends StatefulWidget {
  final Map<String, dynamic>? ride;
  final String? rideId;
  final VoidCallback? onBook;
  
  const RideSearchCard({Key? key, this.ride, this.rideId, this.onBook}) : super(key: key);

  @override
  State<RideSearchCard> createState() => _RideSearchCardState();
}

class _RideSearchCardState extends State<RideSearchCard> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int _passengers = 1;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<_LatLng?> _geocode(String address) async {
    try {
      final places = await geocoding.locationFromAddress(address);
      if (places.isNotEmpty) {
        final p = places.first;
        return _LatLng(p.latitude, p.longitude);
      }
    } catch (_) {}
    return null;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  bool _isNearbyRoute(Map<String, dynamic> ride, double fromLat, double fromLng,
      double toLat, double toLng) {
    // Try ride stored lat/lng fields if available
    final startLat = ride['startLat'] ?? ride['fromLat'] ?? ride['start']?['lat'];
    final startLng = ride['startLng'] ?? ride['fromLng'] ?? ride['start']?['lng'];
    final endLat = ride['endLat'] ?? ride['toLat'] ?? ride['end']?['lat'];
    final endLng = ride['endLng'] ?? ride['toLng'] ?? ride['end']?['lng'];

    if (startLat != null && startLng != null && endLat != null && endLng != null) {
      final sdist = _distanceMeters(startLat.toDouble(), startLng.toDouble(), fromLat, fromLng);
      final edist = _distanceMeters(endLat.toDouble(), endLng.toDouble(), toLat, toLng);
      if (sdist < 25000 && edist < 25000) return true;
      if (sdist < 15000 || edist < 15000) return true;
    }

    // If route points exist (stored as list of maps with lat,lng)
    if (ride['route'] != null && ride['route'] is List) {
      final List route = ride['route'];
      for (final point in route) {
        final plat = point['lat'];
        final plng = point['lng'];
        if (plat == null || plng == null) continue;
        final dFrom = _distanceMeters(plat.toDouble(), plng.toDouble(), fromLat, fromLng);
        final dTo = _distanceMeters(plat.toDouble(), plng.toDouble(), toLat, toLng);
        if (dFrom < 10000 || dTo < 10000) return true;
      }
    }

    return false;
  }

  Future<void> _search() async {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both origin and destination')));
      return;
    }

    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final fromLoc = await _geocode(from);
      final toLoc = await _geocode(to);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Query by date only to avoid requiring a composite index; filter seats locally.
    final qs = await FirebaseFirestore.instance.collection('rides').where('date', isEqualTo: dateStr).get();

      final List<Map<String, dynamic>> matches = [];
      for (final doc in qs.docs) {
        final ride = doc.data() as Map<String, dynamic>;
        ride['id'] = doc.id;

        final rideFrom = (ride['from'] ?? ride['start']?['place'] ?? '').toString().toLowerCase();
        final rideTo = (ride['to'] ?? ride['end']?['place'] ?? '').toString().toLowerCase();

        // Seats check (client-side)
        final seats = (ride['seatsAvailable'] ?? ride['availableSeats'] ?? ride['seats'] ?? 0) as int;
        if (seats < _passengers) continue;

        if (rideFrom.contains(from.toLowerCase()) && rideTo.contains(to.toLowerCase())) {
          matches.add(ride);
          continue;
        }

        if (fromLoc != null && toLoc != null) {
          final nearby = _isNearbyRoute(ride, fromLoc.latitude, fromLoc.longitude, toLoc.latitude, toLoc.longitude);
          if (nearby) matches.add(ride);
        }
      }

      setState(() {
        _results = matches;
      });
    } catch (e) {
      // If Firestore requires a composite index, the exception message usually contains a URL.
      String? openUrl;
      if (e is FirebaseException && e.message != null) {
        final msg = e.message!;
        final urlMatch = RegExp(r'https?://\S+').firstMatch(msg);
        if (urlMatch != null) openUrl = urlMatch.group(0);
      }

      if (openUrl != null) {
        // Show a dialog with the link so user can open/create the index in console.
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Search failed - index required'),
              content: const Text('This query requires a Firestore composite index. Open the Firebase console to create the index.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await launchUrlString(openUrl!);
                    } catch (_) {}
                  },
                  child: const Text('Open Index URL'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(12)));
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // If ride data is provided, show ride card
    if (widget.ride != null && widget.rideId != null) {
      return _buildRideCard(theme);
    }
    
    // Otherwise show search card
    return _buildSearchCard(theme);
  }

  Widget _buildRideCard(ThemeData theme) {
    final ride = widget.ride!;
    final driverName = ride['driverName'] ?? 'Unknown Driver';
    final from = ride['from'] ?? 'Unknown Location';
    final to = ride['to'] ?? 'Unknown Location';
    final date = ride['date'] ?? '';
    final time = ride['time'] ?? '';
    final fare = ride['fare']?.toString() ?? '0';
    final seatsAvailable = ride['seatsAvailable'] ?? 0;
    final carModel = ride['carModel'] ?? 'Standard Car';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with driver info
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 24,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        carModel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$seatsAvailable seats',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Route info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerTheme.color ?? Colors.transparent,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildLocationRow(
                    theme: theme,
                    icon: Icons.circle,
                    label: 'From',
                    location: from,
                    isFirst: true,
                  ),
                  Container(
                    height: 20,
                    child: VerticalDivider(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                      thickness: 2,
                    ),
                  ),
                  _buildLocationRow(
                    theme: theme,
                    icon: Icons.location_on,
                    label: 'To',
                    location: to,
                    isFirst: false,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Date, time, and fare
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    theme: theme,
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: DateFormat('MMM dd').format(DateFormat('yyyy-MM-dd').parse(date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    theme: theme,
                    icon: Icons.access_time,
                    label: 'Time',
                    value: time,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    theme: theme,
                    icon: Icons.currency_rupee,
                    label: 'Fare',
                    value: '₹$fare',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Book button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Book Ride',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String location,
    required bool isFirst,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isFirst 
                ? theme.primaryColor.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isFirst ? theme.primaryColor : Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              Text(
                location,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          // Search header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search for Rides',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Search form
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildSearchField(
                  theme: theme,
                  controller: _fromCtrl,
                  label: 'From',
                  icon: Icons.circle_outlined,
                  hintText: 'Enter pickup location',
                ),
                const SizedBox(height: 16),
                _buildSearchField(
                  theme: theme,
                  controller: _toCtrl,
                  label: 'To',
                  icon: Icons.location_on_outlined,
                  hintText: 'Enter destination',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateSelector(theme),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPassengerSelector(theme),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Search Rides',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
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

  Widget _buildSearchField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: theme.textTheme.bodyLarge,
          maxLines: 1,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: theme.iconTheme.color),
            filled: true,
            fillColor: theme.inputDecorationTheme.fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerTheme.color ?? Colors.transparent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerTheme.color ?? Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: theme.iconTheme.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.iconTheme.color,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passengers',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _passengers > 1 ? () => setState(() => _passengers--) : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _passengers > 1 
                        ? theme.primaryColor 
                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.remove,
                    size: 16,
                    color: _passengers > 1 
                        ? (theme.primaryColor == Colors.black ? Colors.white : Colors.black)
                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                ),
              ),
              Text(
                '$_passengers',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _passengers++),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Simple result card used by RideSearchCard when showing search results.
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final int passengers;

  const _SearchResultCard({Key? key, required this.ride, required this.passengers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fare = ride['fare']?.toString() ?? 'N/A';
    final from = ride['from'] ?? 'Unknown';
    final to = ride['to'] ?? 'Unknown';
    final date = ride['date'] ?? '';
    final time = ride['time'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('$date at $time', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹$fare', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () {
                    final rideWithId = Map<String, dynamic>.from(ride);
                    if (!rideWithId.containsKey('id')) rideWithId['id'] = rideWithId['id'] ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PassengerDetailsScreen(numberOfSeats: passengers, ride: rideWithId),
                      ),
                    );
                  },
                  child: const Text('Book'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}