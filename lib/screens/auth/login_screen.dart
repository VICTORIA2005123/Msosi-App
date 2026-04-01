import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _loginAs = 'User';

  void _login() async {
    setState(() => _isLoading = true);
    final errorMsg = await ref.read(authProvider.notifier).login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fastfood, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_loginAs),
              initialValue: _loginAs,
              decoration: const InputDecoration(labelText: 'Login As', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'User', child: Text('Student / User')),
                DropdownMenuItem(value: 'Business Owner', child: Text('Business Owner / Admin')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _loginAs = value);
                if (value == 'Business Owner') {
                  _emailController.text = 'admin@msosi.com';
                } else {
                  _emailController.clear();
                }
              },
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Login'),
                  ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
              ),
            ),
          ),
        ),
    );
  }
}
