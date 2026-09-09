import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/expense_provider.dart';
import '../home_nav_scaffold.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    final result = _isLogin
        ? await AuthService.login(email, password)
        : await AuthService.register(name, email, password);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      context.read<ExpenseProvider>().setAuthToken(result['token']);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeNavScaffold()),
      );
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    size: 64, color: Color(0xFF1E3A8A)),
                const SizedBox(height: 12),
                Text(
                  _isLogin ? 'Welcome Back to Fintor' : 'Create an Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_errorMessage!,
                        style: TextStyle(color: Colors.red.shade800)),
                  ),
                if (!_isLogin)
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isLogin ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin
                      ? "Don't have an account? Sign Up"
                      : "Already have an account? Sign In"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
