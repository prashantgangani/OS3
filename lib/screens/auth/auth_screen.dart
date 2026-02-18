import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/home_screen.dart';

class AuthScreen extends StatefulWidget {
  static const String routeName = '/auth';
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  final _signupName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  final _signupConfirm = TextEditingController();

  bool _loginObscure = true;
  bool _signupObscure = true;
  bool _confirmObscure = true;

  bool _loadingLogin = false;
  bool _loadingSignup = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _signupName.dispose();
    _signupEmail.dispose();
    _signupPass.dispose();
    _signupConfirm.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: suffix,
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _login() async {
    final email = _loginEmail.text.trim();
    final pass = _loginPass.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _toast('Please enter email and password', isError: true);
      return;
    }

    setState(() => _loadingLogin = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      _goHome();
    } on FirebaseAuthException catch (e) {
      
      print('Login FirebaseAuthException: code=${e.code}, message=${e.message}');

      String friendly;
      switch (e.code) {
        case 'user-not-found':
          friendly = 'No account found for this email';
          break;
        case 'wrong-password':
          friendly = 'Invalid credentials';
          break;
        case 'invalid-email':
          friendly = 'Invalid email address';
          break;
        case 'network-request-failed':
          friendly = 'Network error. Check your connection';
          break;
        case 'too-many-requests':
          friendly = 'Too many attempts. Try again later';
          break;
        default:
          friendly = 'Invalid credentials';
      }

      if (e.code == 'user-not-found') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('User not found'),
              content: Text('$friendly. Would you like to create one?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _tabs.animateTo(1);
                    _signupEmail.text = email;
                  },
                  child: const Text('Sign up'),
                ),
              ],
            ),
          );
        }
      } else if (e.code == 'wrong-password') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Wrong password'),
              content: Text('$friendly. Would you like to reset it?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      _toast('Password reset email sent');
                    } catch (err) {
                      _toast('Failed to send reset email', isError: true);
                      // ignore: avoid_print
                      print('Reset email error: $err');
                    }
                  },
                  child: const Text('Reset password'),
                ),
              ],
            ),
          );
        }
      } else {
        _toast(friendly, isError: true);
      }
    } catch (ex, st) {
      _toast('Invalid credentials', isError: true);
      // ignore: avoid_print
      print('Login error: $ex\n$st');
    } finally {
      if (mounted) setState(() => _loadingLogin = false);
    }
  }

  Future<void> _signup() async {
    final name = _signupName.text.trim();
    final email = _signupEmail.text.trim();
    final pass = _signupPass.text.trim();
    final confirm = _signupConfirm.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _toast('Please fill all fields', isError: true);
      return;
    }
    if (pass.length < 6) {
      _toast('Password must be at least 6 characters', isError: true);
      return;
    }
    if (pass != confirm) {
      _toast('Passwords do not match', isError: true);
      return;
    }

    setState(() => _loadingSignup = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Optional: update display name (not required)
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      _goHome();
    } on FirebaseAuthException catch (e) {
      // Handle known errors with friendly actions
      if (e.code == 'email-already-in-use') {
        // Let the user switch to Login or send a password reset
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Email already in use'),
              content: Text('The email "$email" is already registered. Would you like to log in or reset the password?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _tabs.animateTo(0);
                    _loginEmail.text = email;
                  },
                  child: const Text('Login'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      _toast('Password reset email sent');
                    } catch (err) {
                      _toast('Failed to send reset email', isError: true);
                      // ignore: avoid_print
                      print('Reset email error: $err');
                    }
                  },
                  child: const Text('Reset password'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Use different email'),
                ),
              ],
            ),
          );
        }
      } else {
        _toast('Invalid credentials', isError: true);
        // ignore: avoid_print
        print('Signup FirebaseAuthException: code=${e.code}, message=${e.message}');
      }
    } catch (ex, st) {
      _toast('Invalid credentials', isError: true);
      // ignore: avoid_print
      print('Signup error: $ex\n$st');
    } finally {
      if (mounted) setState(() => _loadingSignup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OS Scheduler Simulator'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Login'),
            Tab(text: 'Signup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ---------------- LOGIN UI ----------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _loginEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _loginPass,
                  obscureText: _loginObscure,
                  decoration: _dec(
                    'Password',
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _loginObscure = !_loginObscure),
                      icon: Icon(
                        _loginObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _loadingLogin ? null : _login,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _loadingLogin
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                ),

                TextButton(
                  onPressed: () => _tabs.animateTo(1),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),

          // ---------------- SIGNUP UI ----------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _signupName,
                  decoration: _dec('Full Name'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _signupEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _signupPass,
                  obscureText: _signupObscure,
                  decoration: _dec(
                    'Password',
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _signupObscure = !_signupObscure),
                      icon: Icon(
                        _signupObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _signupConfirm,
                  obscureText: _confirmObscure,
                  decoration: _dec(
                    'Confirm Password',
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _confirmObscure = !_confirmObscure),
                      icon: Icon(
                        _confirmObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _loadingSignup ? null : _signup,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _loadingSignup
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Signup'),
                  ),
                ),

                TextButton(
                  onPressed: () => _tabs.animateTo(0),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
