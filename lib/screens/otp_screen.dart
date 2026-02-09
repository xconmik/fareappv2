import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  String? _verificationId;
  String? _phone;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_verificationId != null) {
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _verificationId = args['verificationId'] as String?;
      _phone = args['phone'] as String?;
      _resendToken = args['resendToken'] as int?;
    }
  }

  Future<void> _createUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'phone': _phone ?? user.phoneNumber,
        'role': 'rider',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6 || _verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code.')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      await _createUserProfile();
      if (!mounted) {
        setState(() { _isVerifying = false; });
        return;
      }
      Navigator.pushReplacementNamed(context, '/home_main');
    } on TimeoutException {
      if (mounted) {
        setState(() { _isVerifying = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification timed out. Try again.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() { _isVerifying = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Invalid code.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isVerifying = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    }
  }

  Future<void> _resendCode() async {
    if (_phone == null) {
      return;
    }
    setState(() {
      _isResending = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phone!,
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _createUserProfile();
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(context, '/home_main');
      },
      verificationFailed: (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to resend code.')),
        );
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) {
          return;
        }
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    if (mounted) {
      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('OTP', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Verify your number', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              _phone == null ? 'We sent a code to your phone' : 'We sent a code to $_phone',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _codeFocusNode.requestFocus(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _codeController,
                    builder: (context, value, _) {
                      final text = value.text;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final char = index < text.length ? text[index] : '';
                          return Container(
                            width: 44,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF232323),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              char,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isResending ? null : _resendCode,
              child: _isResending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend code', style: TextStyle(color: Color(0xFFD4AF37))),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                child: _isVerifying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
