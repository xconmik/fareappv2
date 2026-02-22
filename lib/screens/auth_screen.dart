import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/responsive.dart';
import '../widgets/fare_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  
  // Screen states
  bool _showInitial = true;
  bool _showSignInPhone = false;
  bool _showSignUpForm = false;
  bool _showOTP = false;
  bool _showNotRecognized = false;
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSignInPhone() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a phone number';
          _isLoading = false;
        });
        return;
      }

      // Check if phone exists in Firestore users collection
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: '+63 ' + phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Phone not recognized
        setState(() {
          _showSignInPhone = false;
          _showNotRecognized = true;
          _isLoading = false;
        });
        return;
      }

      // Phone exists, send OTP
      await _auth.verifyPhoneNumber(
        phoneNumber: '+63' + phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home_main');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = e.message ?? 'Verification failed';
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _showSignInPhone = false;
            _showOTP = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final otp = _otpController.text.trim();
      if (otp.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter OTP';
          _isLoading = false;
        });
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      // If this is a signup, save user data
      if (_firstNameController.text.isNotEmpty) {
        await _saveUserData(
          userCredential.user?.uid,
          _firstNameController.text.trim(),
          _lastNameController.text.trim(),
          _emailController.text.trim(),
          _phoneController.text.trim(),
        );
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home_main');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid OTP: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignUpPhone() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();

      if (phone.isEmpty || firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
        setState(() {
          _errorMessage = 'Please fill in all fields';
          _isLoading = false;
        });
        return;
      }

      // Send OTP for phone verification
      await _auth.verifyPhoneNumber(
        phoneNumber: '+63' + phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto sign in and save user data
          final userCredential = await _auth.signInWithCredential(credential);
          await _saveUserData(userCredential.user?.uid, firstName, lastName, email, phone);
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home_main');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = e.message ?? 'Verification failed';
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _showInitial = false;
            _showSignUpForm = false;
            _showOTP = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserData(String? uid, String firstName, String lastName, String email, String phone) async {
    if (uid == null) return;
    
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': '+63 ' + phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    
    if (_showInitial) {
      return _buildInitialScreen(r);
    } else if (_showSignInPhone) {
      return _buildSignInPhoneScreen(r);
    } else if (_showNotRecognized) {
      return _buildNotRecognizedScreen(r);
    } else if (_showSignUpForm) {
      return _buildSignUpFormScreen(r);
    } else if (_showOTP) {
      return _buildOTPScreen(r);
    }
    
    return const SizedBox.expand();
  }

  Widget _buildInitialScreen(Responsive r) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Column(
          children: [
            // Centered logo + tagline area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FareLogo(height: r.space(80)),
                    SizedBox(height: r.space(12)),
                    Text(
                      'Less but better',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: r.font(18),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: r.space(24), right: r.space(24)),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: r.space(56),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showInitial = false;
                          _showSignInPhone = true;
                          _phoneController.clear();
                          _otpController.clear();
                          _errorMessage = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC9B469),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.radius(14)),
                        ),
                      ),
                      child: Text(
                        'Sign in',
                        style: TextStyle(
                          color: const Color(0xFF0E0E0E),
                          fontSize: r.font(16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: r.space(12)),
                  SizedBox(
                    width: double.infinity,
                    height: r.space(56),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showInitial = false;
                          _showSignUpForm = true;
                          _phoneController.clear();
                          _firstNameController.clear();
                          _lastNameController.clear();
                          _emailController.clear();
                          _otpController.clear();
                          _errorMessage = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.radius(14)),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.font(16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.space(60)),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPhoneScreen(Responsive r) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _showSignInPhone = false;
              _showInitial = true;
              _errorMessage = null;
            });
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: r.space(24), right: r.space(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: r.space(20)),
              Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: r.space(8)),
              Text(
                'Enter your mobile number',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: r.font(14),
                ),
              ),
              SizedBox(height: r.space(32)),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(16),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  prefixText: '+63 ',
                  prefixStyle: TextStyle(
                    color: Colors.white,
                    fontSize: r.font(16),
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: '900 000 0000',
                  hintStyle: TextStyle(
                    color: Colors.white30,
                    fontSize: r.font(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.space(16),
                    vertical: r.space(12),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: r.space(12)),
                Container(
                  padding: EdgeInsets.all(r.space(12)),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(r.radius(8)),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: r.font(12),
                    ),
                  ),
                ),
              ],
              Spacer(),
              SizedBox(
                width: double.infinity,
                height: r.space(56),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignInPhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC9B469),
                    disabledBackgroundColor: Colors.white30,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.radius(14)),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: r.space(24),
                          width: r.space(24),
                          child: const CircularProgressIndicator(
                            color: Color(0xFF0E0E0E),
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(
                            color: const Color(0xFF0E0E0E),
                            fontSize: r.font(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: r.space(32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpFormScreen(Responsive r) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _showSignUpForm = false;
              _showInitial = true;
              _errorMessage = null;
            });
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: r.space(24), right: r.space(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: r.space(20)),
              Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: r.space(32)),
              Text(
                'First Name',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: r.font(12),
                ),
              ),
              SizedBox(height: r.space(8)),
              TextField(
                controller: _firstNameController,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(14),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  contentPadding: EdgeInsets.only(
                    left: r.space(16),
                    right: r.space(16),
                    top: r.space(12),
                  ),
                ),
              ),
              SizedBox(height: r.space(16)),
              Text(
                'Last Name',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: r.font(12),
                ),
              ),
              SizedBox(height: r.space(8)),
              TextField(
                controller: _lastNameController,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(14),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  contentPadding: EdgeInsets.only(
                    left: r.space(16),
                    right: r.space(16),
                    top: r.space(12),
                  ),
                ),
              ),
              SizedBox(height: r.space(16)),
              Text(
                'Email',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: r.font(12),
                ),
              ),
              SizedBox(height: r.space(8)),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(14),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  contentPadding: EdgeInsets.only(
                    left: r.space(16),
                    right: r.space(16),
                    top: r.space(12),
                  ),
                ),
              ),
              SizedBox(height: r.space(16)),
              Text(
                'Phone Number',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: r.font(12),
                ),
              ),
              SizedBox(height: r.space(8)),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(14),
                ),
                decoration: InputDecoration(
                  prefixText: '+63 ',
                  prefixStyle: TextStyle(
                    color: Colors.white54,
                    fontSize: r.font(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.space(16),
                    vertical: r.space(12),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: r.space(12)),
                Container(
                  padding: EdgeInsets.all(r.space(12)),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(r.radius(8)),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: r.font(12),
                    ),
                  ),
                ),
              ],
              SizedBox(height: r.space(32)),
              SizedBox(
                width: double.infinity,
                height: r.space(56),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUpPhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC9B469),
                    disabledBackgroundColor: Colors.white30,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.radius(14)),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: r.space(24),
                          width: r.space(24),
                          child: const CircularProgressIndicator(
                            color: Color(0xFF0E0E0E),
                          ),
                        )
                      : Text(
                          'Create Account',
                          style: TextStyle(
                            color: const Color(0xFF0E0E0E),
                            fontSize: r.font(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: r.space(32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPScreen(Responsive r) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _showOTP = false;
              if (_showSignInPhone) {
                _phoneController.clear();
              } else {
                _showSignUpForm = true;
              }
              _otpController.clear();
              _errorMessage = null;
            });
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: r.space(24), right: r.space(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: r.space(20)),
              Text(
                'Verify OTP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: r.space(8)),
              Text(
                'Enter the code sent to ${_phoneController.text}',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: r.font(14),
                ),
              ),
              SizedBox(height: r.space(32)),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(24),
                  fontWeight: FontWeight.bold,
                  letterSpacing: r.space(8),
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: Colors.white30,
                    fontSize: r.font(24),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.radius(12)),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.space(16),
                    vertical: r.space(16),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: r.space(12)),
                Container(
                  padding: EdgeInsets.all(r.space(12)),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(r.radius(8)),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: r.font(12),
                    ),
                  ),
                ),
              ],
              Spacer(),
              SizedBox(
                width: double.infinity,
                height: r.space(56),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC9B469),
                    disabledBackgroundColor: Colors.white30,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.radius(14)),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: r.space(24),
                          width: r.space(24),
                          child: const CircularProgressIndicator(
                            color: Color(0xFF0E0E0E),
                          ),
                        )
                      : Text(
                          'Verify',
                          style: TextStyle(
                            color: const Color(0xFF0E0E0E),
                            fontSize: r.font(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: r.space(32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotRecognizedScreen(Responsive r) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _showNotRecognized = false;
              _showSignInPhone = true;
              _errorMessage = null;
            });
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: r.space(24), right: r.space(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: r.space(20)),
              Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.font(24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: r.space(32)),
              Container(
                padding: EdgeInsets.only(left: r.space(16), right: r.space(16), top: r.space(16)),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(r.radius(12)),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: r.space(24),
                      height: r.space(24),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: r.icon(14),
                      ),
                    ),
                    SizedBox(width: r.space(12)),
                    Expanded(
                      child: Text(
                        "We don't recognize this mobile number",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.font(14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.space(32)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _phoneController.text.isNotEmpty
                        ? '+63 ${_phoneController.text}'
                        : 'N/A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.font(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showNotRecognized = false;
                        _showSignInPhone = true;
                        _phoneController.clear();
                      });
                    },
                    child: Text(
                      'Change',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.font(14),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                height: r.space(56),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showNotRecognized = false;
                      _showSignUpForm = true;
                      _errorMessage = null;
                      _firstNameController.clear();
                      _lastNameController.clear();
                      _emailController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC9B469),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.radius(14)),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      color: const Color(0xFF0E0E0E),
                      fontSize: r.font(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.space(32)),
            ],
          ),
        ),
      ),
    );
  }
}
