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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Choose Your Role',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 50,
                        color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'How will you use Campus Ride?',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select your role to personalize your experience',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Role Selection Cards
              _buildRoleCard(
                title: 'Driver',
                subtitle: 'Offer rides and earn money',
                icon: Icons.drive_eta,
                value: 'driver',
                theme: theme,
              ),
              
              const SizedBox(height: 20),
              
              _buildRoleCard(
                title: 'Rider',
                subtitle: 'Book comfortable rides',
                icon: Icons.directions_car,
                value: 'rider',
                theme: theme,
              ),
              
              const SizedBox(height: 40),
              
              // Name Input
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Name',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameC,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline, color: theme.iconTheme.color),
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
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_role == null) {
                      Fluttertoast.showToast(msg: 'Please select a role');
                      return;
                    }
                    final err = await auth.setRole(
                      _role!,
                      name: nameC.text.trim().isEmpty ? null : nameC.text.trim()
                    );
                    if (err != null) {
                      Fluttertoast.showToast(msg: err);
                    } else {
                      if (!mounted) return;
                      if (_role == 'driver') {
                        Navigator.pushReplacement(
                          context, 
                          MaterialPageRoute(builder: (_) => const DriverHome())
                        );
                      } else {
                        Navigator.pushReplacement(
                          context, 
                          MaterialPageRoute(builder: (_) => const RiderHome())
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required ThemeData theme,
  }) {
    final isSelected = _role == value;
    
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? theme.primaryColor 
                : (theme.dividerTheme.color ?? Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
              blurRadius: isSelected ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected 
                    ? (theme.primaryColor == Colors.black ? Colors.white : Colors.black)
                    : theme.primaryColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                size: 30,
                color: isSelected 
                    ? theme.primaryColor 
                    : (theme.primaryColor == Colors.black ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                          ? (theme.primaryColor == Colors.black ? Colors.white : Colors.black)
                          : theme.textTheme.headlineMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected 
                          ? (theme.primaryColor == Colors.black ? Colors.white70 : Colors.black87)
                          : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? (theme.primaryColor == Colors.black ? Colors.white : Colors.black)
                      : theme.textTheme.bodyMedium?.color?.withOpacity(0.5) ?? Colors.grey,
                  width: 2,
                ),
                color: isSelected 
                    ? (theme.primaryColor == Colors.black ? Colors.white : Colors.black)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: theme.primaryColor,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
