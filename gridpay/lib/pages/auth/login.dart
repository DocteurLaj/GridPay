import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gridpay/pages/auth/authService.dart';
import 'package:gridpay/pages/screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();

  // Format du numéro: +243 9XX XXX XXX
  String formatPhoneNumber(String value) {
    if (value.isEmpty) return value;

    String numbers = value.replaceAll(RegExp(r'[^\d]'), '');

    if (numbers.startsWith('243')) {
      numbers = numbers.substring(3);
    }

    if (numbers.length > 9) {
      numbers = numbers.substring(0, 9);
    }

    if (numbers.isEmpty) return '+243 ';

    String formatted = '+243 ';
    if (numbers.length <= 2) {
      formatted += numbers;
    } else if (numbers.length <= 5) {
      formatted += '${numbers.substring(0, 2)} ${numbers.substring(2)}';
    } else if (numbers.length <= 8) {
      formatted +=
          '${numbers.substring(0, 2)} ${numbers.substring(2, 5)} ${numbers.substring(5)}';
    } else {
      formatted +=
          '${numbers.substring(0, 2)} ${numbers.substring(2, 5)} ${numbers.substring(5, 8)}';
      if (numbers.length > 8) {
        formatted += numbers.substring(8);
      }
    }

    return formatted;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain a number';
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain a special character';
    }

    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Nettoyer le numéro pour la validation
    String cleanNumber = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.startsWith('243')) {
      cleanNumber = cleanNumber.substring(3);
    }

    if (cleanNumber.length != 9) {
      return 'Number must contain 9 digits after +243';
    }

    if (!cleanNumber.startsWith('9') && !cleanNumber.startsWith('8')) {
      return 'Number must start with 9 after +243';
    }

    // Vérifier le format congolais (RDC)
    final validPrefixes = [
      '97', '98', '99', // Airtel, Vodacom
      '81', '82', '83', '84', '85', '86', '87', '88', '89', // Orange, Africell
    ];
    if (cleanNumber.length >= 2) {
      String prefix = cleanNumber.substring(0, 2);
      if (!validPrefixes.contains(prefix)) {
        return 'Invalid phone prefix for DRC';
      }
    }

    return null;
  }

  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      if (isLogin) {
        // Processus de connexion
        final result = await _authService.login(
          _emailController.text,
          _passwordController.text,
        );

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Naviguer vers la page d'accueil
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          // Afficher un message d'erreur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Processus d'inscription
        final result = await _authService.register(
          _emailController.text,
          _passwordController.text,
          _phoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
          _nameController.text,
        );

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Afficher un message de succès et basculer vers le login
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            isLogin = true;
            _confirmPasswordController.clear();
            _phoneController.clear();
            _nameController.clear();
          });
        } else {
          // Afficher un message d'erreur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (!isLogin) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != _passwordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              // Logo and title
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isLogin ? 'Welcome back' : 'Create account',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin ? 'Sign in to continue' : 'Join us today',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!isLogin)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        style: const TextStyle(color: Colors.white),
                        validator: validateName,
                      ),
                    if (!isLogin) const SizedBox(height: 16),

                    // Phone number field (only for registration)
                    if (!isLogin)
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone),
                          prefixText: '+243 ',
                        ),
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _phoneController.text = formatPhoneNumber(value);
                            _phoneController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _phoneController.text.length,
                                  ),
                                );
                          });
                        },
                        validator: !isLogin ? validatePhone : null,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    if (!isLogin) const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      obscureText: _obscurePassword,
                      validator: validatePassword,
                    ),

                    if (!isLogin) const SizedBox(height: 16),
                    if (!isLogin)
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscureConfirmPassword,
                        validator: _validateConfirmPassword,
                      ),

                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(color: Colors.blue.shade400),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    _buildButtonAction(),
                    const SizedBox(height: 24),

                    _buildOr(),
                    const SizedBox(height: 32),

                    _buildFooterLink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonAction() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                isLogin ? 'Sign in' : 'Register',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildOr() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade700, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Or', style: TextStyle(color: Colors.grey.shade500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade700, thickness: 1)),
      ],
    );
  }

  Widget _buildFooterLink() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey<bool>(isLogin),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isLogin ? 'Don\'t have an account?' : 'Already have an account?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      isLogin = !isLogin;
                      _confirmPasswordController.clear();
                      _phoneController.clear();
                      _nameController.clear();
                    });
                  },
            child: Text(
              isLogin ? 'Sign up' : 'Sign in',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
