import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'driver_home.dart';
import 'rider_home.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});
  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  String? _role;
  final nameC = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.profile?['displayName'] != null) {
        nameC.text = auth.profile!['displayName'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Choose your role to continue', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text('Driver'),
            value: 'driver',
            groupValue: _role,
            onChanged: (v) => setState(() => _role = v),
          ),
          RadioListTile<String>(
            title: const Text('Rider'),
            value: 'rider',
            groupValue: _role,
            onChanged: (v) => setState(() => _role = v),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Your name')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (_role == null) {
                Fluttertoast.showToast(msg: 'Pick a role');
                return;
              }
              final err = await auth.setRole(_role!,
                  name: nameC.text.trim().isEmpty ? null : nameC.text.trim());
              if (err != null) {
                Fluttertoast.showToast(msg: err);
              } else {
                if (!mounted) return;
                if (_role == 'driver') {
                  Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => const DriverHome()));
                } else {
                  Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => const RiderHome()));
                }
              }
            },
            child: const Text('Save Role'),
          ),
        ]),
      ),
    );
  }
}
