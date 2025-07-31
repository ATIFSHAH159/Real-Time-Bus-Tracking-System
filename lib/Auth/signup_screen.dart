import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _registrationNoController = TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  String _selectedRole = 'student';
  String _whoAreYou = 'Student';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  File? _imageFile;
  File? _receiptImageFile; // New: for receipt image
  final ImagePicker _picker = ImagePicker();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late AnimationController _questionMarkController;
  Animation<double>? _questionMarkScale;

  // Per-field error and valid state
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _registrationNoError;
  String? _phoneNoError;
  bool _nameValid = false;
  bool _emailValid = false;
  bool _passwordValid = false;
  bool _registrationNoValid = false;
  bool _phoneNoValid = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    // Add listeners for real-time validation
    _nameController.addListener(_validateName);
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _registrationNoController.addListener(_validateRegistrationNo);
    _phoneNoController.addListener(_validatePhoneNo);

    // Animation for question mark
    _questionMarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _questionMarkScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _questionMarkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _registrationNoController.dispose();
    _phoneNoController.dispose();
    _questionMarkController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image: $e";
      });
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _receiptImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick receipt image: $e";
      });
    }
  }

  void _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Name is required';
        _nameValid = false;
      });
    } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      setState(() {
        _nameError = 'Name should contain only letters and spaces!';
        _nameValid = false;
      });
    } else {
      setState(() {
        _nameError = null;
        _nameValid = true;
      });
    }
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
        _emailValid = false;
      });
    } else if (!emailRegex.hasMatch(email)) {
      setState(() {
        _emailError = 'Please enter a valid email address!';
        _emailValid = false;
      });
    } else {
      setState(() {
        _emailError = null;
        _emailValid = true;
      });
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Password is required';
        _passwordValid = false;
      });
    } else if (password.length < 6) {
      setState(() {
        _passwordError = 'Password should be at least 6 characters!';
        _passwordValid = false;
      });
    } else if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{6,}').hasMatch(password)) {
      setState(() {
        _passwordError = 'Password must contain at least one uppercase letter, one lowercase letter, and one number!';
        _passwordValid = false;
      });
    } else {
      setState(() {
        _passwordError = null;
        _passwordValid = true;
      });
    }
  }

  void _validateRegistrationNo() {
    final regNo = _registrationNoController.text.trim();
    if (regNo.isEmpty) {
      setState(() {
        _registrationNoError = 'Registration number is required';
        _registrationNoValid = false;
      });
    } else if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(regNo)) {
      setState(() {
        _registrationNoError = 'Registration number should be alphanumeric and can contain hyphens!';
        _registrationNoValid = false;
      });
    } else {
      setState(() {
        _registrationNoError = null;
        _registrationNoValid = true;
      });
    }
  }

  void _validatePhoneNo() {
    final phone = _phoneNoController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _phoneNoError = 'Phone number is required';
        _phoneNoValid = false;
      });
    } else if (!RegExp(r'^\d{10,11}$').hasMatch(phone)) {
      setState(() {
        _phoneNoError = 'Please enter a valid phone number (11 digits)!';
        _phoneNoValid = false;
      });
    } else {
      setState(() {
        _phoneNoError = null;
        _phoneNoValid = true;
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Run all validations
    _validateName();
    _validateEmail();
    _validatePassword();
    _validateRegistrationNo();
    _validatePhoneNo();

    // If any field is invalid, stop
    if (!_nameValid || !_emailValid || !_passwordValid || !_registrationNoValid || !_phoneNoValid || _imageFile == null) {
      setState(() {
        if (_imageFile == null) {
          _errorMessage = 'Please select a profile image!';
        }
        _isLoading = false;
      });
      return;
    }
    // Optionally, you can require receipt image for teachers only:
    if (_whoAreYou == 'Teacher' && _receiptImageFile == null) {
      setState(() {
        _errorMessage = 'Please upload a receipt image!';
        _isLoading = false;
      });
      return;
    }

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String name = _nameController.text.trim();
    String registrationNo = _registrationNoController.text.trim();
    String phoneNo = _phoneNoController.text.trim();

    try {
      final user = await AuthService().registerUser(
        email: email,
        password: password,
        name: name,
        registrationNo: registrationNo,
        phoneNo: phoneNo,
        role: _selectedRole, // Assuming role is 'student' for this screen
        imageFile: _imageFile,
        whoAreYou: _whoAreYou, // Store who are you in the database
        receiptImageFile: _receiptImageFile,
      );
      
      if (user != null) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Signup failed: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Signup failed: ${e.toString()}";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1976D2),  // Deep Blue
              Color(0xFF2196F3),  // Material Blue
              Color(0xFF64B5F6),  // Light Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(_slideAnimation),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white.withOpacity(0.95),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Profile Image Upload
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: _imageFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(60),
                                        child: Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            size: 40,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Add Photo',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Welcome Text
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Who are you? Radio group
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Who are you?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'Student',
                                      groupValue: _whoAreYou,
                                      onChanged: (value) {
                                        setState(() {
                                          _whoAreYou = value!;
                                        });
                                      },
                                      activeColor: AppColors.primary,
                                    ),
                                    const Text('Student'),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'Teacher',
                                      groupValue: _whoAreYou,
                                      onChanged: (value) {
                                        setState(() {
                                          _whoAreYou = value!;
                                        });
                                      },
                                      activeColor: AppColors.primary,
                                    ),
                                    const Text('Teacher'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(_nameController, "Full Name", Icons.person, errorText: _nameError, isValid: _nameValid),
                            _buildTextField(_emailController, "Email", Icons.email, errorText: _emailError, isValid: _emailValid),
                            _buildTextField(
                              _passwordController,
                              "Password",
                              Icons.lock,
                              obscureText: _obscurePassword,
                              isPassword: true,
                              errorText: _passwordError,
                              isValid: _passwordValid,
                            ),
                            _buildTextField(
                              _registrationNoController,
                              "Registration No",
                              Icons.badge,
                              keyboardType: TextInputType.text,
                              errorText: _registrationNoError,
                              isValid: _registrationNoValid,
                            ),
                            // Note under registration number field
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2, bottom: 8),
                                child: Text(
                                  'Note: If you are registering as a teacher, please enter your Teacher ID as the registration number.',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            _buildTextField(
                              _phoneNoController,
                              "Phone No",
                              Icons.phone,
                              keyboardType: TextInputType.phone,
                              errorText: _phoneNoError,
                              isValid: _phoneNoValid,
                            ),
                            // Upload Receipt Section (moved here)
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Upload Receipt',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedBuilder(
                                    animation: _questionMarkScale ?? kAlwaysDismissedAnimation,
                                    builder: (context, child) => Transform.scale(
                                      scale: _questionMarkScale?.value ?? 1.0,
                                      child: child,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(24),
                                                color: AppColors.surface,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Gradient header with icon and title
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                                    decoration: BoxDecoration(
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(24),
                                                        topRight: Radius.circular(24),
                                                      ),
                                                      gradient: AppColors.gradientPrimary,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.info_outline, color: Colors.white, size: 32),
                                                        const SizedBox(width: 12),
                                                        const Text(
                                                          'Registration Details',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('Account Title:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                        const SizedBox(height: 2),
                                                        const Text('CUI-ATD', style: TextStyle(fontSize: 16)),
                                                        const SizedBox(height: 10),
                                                        Text('Account Type:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                        const SizedBox(height: 2),
                                                        const Text('Easypaisa', style: TextStyle(fontSize: 16)),
                                                        const SizedBox(height: 10),
                                                        Text('Account Number:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                        const SizedBox(height: 2),
                                                        const Text('0323-9811681', style: TextStyle(fontSize: 16)),
                                                        const SizedBox(height: 10),
                                                        Text('Charges:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                        const SizedBox(height: 2),
                                                        const Text('10,000 PKR', style: TextStyle(fontSize: 16)),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                                    child: Divider(color: AppColors.accent, thickness: 1),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.receipt_long, color: AppColors.warning, size: 22),
                                                        const SizedBox(width: 8),
                                                        const Expanded(
                                                          child: Text(
                                                            'Please upload the receipt image after successful payment.',
                                                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: Text('Close', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        Icons.help_outline,
                                        color: AppColors.warning, // More visible color
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _pickReceiptImage,
                              child: Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: _receiptImageFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _receiptImageFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 40,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap to upload receipt',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 24),
                            
                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Sign Up",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    "Login",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    String? errorText,
    bool isValid = false,
  }) {
    Color borderColor;
    if (errorText != null) {
      borderColor = Colors.red;
    } else if (isValid) {
      borderColor = Colors.green;
    } else {
      borderColor = AppColors.inputBorder;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: AppColors.primary),
              prefixIcon: Icon(icon, color: AppColors.primary),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.primary,
                      ),
                      onPressed: _togglePasswordVisibility,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              errorText: null, // Don't use default errorText
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                errorText,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
