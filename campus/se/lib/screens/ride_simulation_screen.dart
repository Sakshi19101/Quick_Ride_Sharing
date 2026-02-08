import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideSimulationScreen extends StatefulWidget {
  final String rideId;
  final String driverId;
  final String from;
  final String to;
  final String bookingId;

  const RideSimulationScreen({
    Key? key,
    required this.rideId,
    required this.driverId,
    required this.from,
    required this.to,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<RideSimulationScreen> createState() => _RideSimulationScreenState();
}

class _RideSimulationScreenState extends State<RideSimulationScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Simulation'),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0), // Default position
          zoom: 15,
        ),
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}