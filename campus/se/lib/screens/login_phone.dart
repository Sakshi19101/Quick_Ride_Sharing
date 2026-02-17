import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'otp_verify.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});
  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> {
  final phoneC = TextEditingController(text: '+91');
  final aadhaarC = TextEditingController();
  final nameC = TextEditingController();
  final ageC = TextEditingController();
  String? gender;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              
              // Logo and Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.directions_car,
                        size: 40,
                        color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Campus Ride',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your premium campus travel companion',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Login Form Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
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
                      'Welcome Back',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your journey',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    _buildTextField(
                      controller: phoneC,
                      labelText: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: nameC,
                      labelText: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: ageC,
                      labelText: 'Age',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: aadhaarC,
                      labelText: 'Aadhaar Number',
                      icon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildGenderDropdown(),
                    const SizedBox(height: 32),
                    
                    _buildSendOtpButton(auth),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Footer
              Center(
                child: Text(
                  'By continuing, you agree to our Terms & Conditions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Enter your $labelText',
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

  Widget _buildGenderDropdown() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.transparent,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: gender,
            hint: Text('Select Gender', style: theme.textTheme.bodyMedium),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.people_outline, color: theme.iconTheme.color),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            dropdownColor: theme.cardTheme.color,
            onChanged: (String? newValue) {
              setState(() {
                gender = newValue;
              });
            },
            items: <String>['Male', 'Female', 'Other']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: theme.textTheme.bodyMedium),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSendOtpButton(AuthService auth) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () async {
          if (!mounted) return;
          if (phoneC.text.isEmpty ||
              aadhaarC.text.isEmpty ||
              nameC.text.isEmpty ||
              ageC.text.isEmpty ||
              gender == null) {
            Fluttertoast.showToast(msg: 'Please fill all fields');
            return;
          }
          setState(() => loading = true);
          final err = await auth.signInWithPhone(
            phoneC.text.trim(),
            aadhaarC.text.trim(),
            nameC.text.trim(),
            int.parse(ageC.text.trim()),
            gender!,
          );
          if (!mounted) return;
          setState(() => loading = false);
          if (err != null) {
            Fluttertoast.showToast(msg: err);
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OtpVerifyScreen()));
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
        child: loading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                ),
              )
            : Text(
                'Send OTP',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.primaryColor == Colors.black ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    phoneC.dispose();
    aadhaarC.dispose();
    nameC.dispose();
    ageC.dispose();
    super.dispose();
  }
}
