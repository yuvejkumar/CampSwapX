import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Ensure this file exists from your flutterfire configure
import 'package:http/http.dart' as http; // Import HTTP
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart'; // Import for LinkedIn
import 'package:shimmer/shimmer.dart'; // Make sure to add this dependency
import 'package:google_sign_in/google_sign_in.dart'; // Import this
import 'dart:async';
import 'package:crypto/crypto.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KalasalingamMarketplaceApp());
}

class KalasalingamMarketplaceApp extends StatelessWidget {
  const KalasalingamMarketplaceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampSwapX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50], // Light grey background
        // --- ADD THIS BLOCK FOR SMOOTH ANIMATIONS ---
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(), // Smooth Zoom/Fade
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(), // Smooth Slide
          },
        ),
        // ---------------------------------------------
      ),
      home: const AuthWrapper(), // Or SplashScreen
    );
  }
}

/// Listens to Auth State changes to redirect user automatically
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // GOOGLE USERS ARE AUTO VERIFIED — ONLY CHECK FOR EMAIL/PASSWORD USERS
          final isGoogleUser = user.providerData
              .any((p) => p.providerId == 'google.com');
          if (!user.emailVerified && !isGoogleUser) {
            return VerifyEmailScreen(user: user);
          }
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
class VerifyEmailScreen extends StatefulWidget {
  final User user;
  const VerifyEmailScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSending = false;
  bool _emailSent = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // AUTO SEND ON OPEN
    _sendVerificationEmail();
    // CHECK EVERY 5 SECONDS IF USER VERIFIED
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        _timer?.cancel();
        // NAVIGATE TO HOME
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isSending = true);
    try {
      await widget.user.sendEmailVerification();
      setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending email: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _logout() async {
    _timer?.cancel();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ICON
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded,
                    size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 30),

              const Text(
                'Verify Your Email',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              Text(
                _emailSent
                    ? 'A verification link has been sent to:\n${widget.user.email}'
                    : 'Sending verification email...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),

              Text(
                'Please check your inbox and click the link to activate your account. (check in your spam/junk folder)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 10),

              // AUTO CHECK INDICATOR
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.blue[300]),
                  ),
                  const SizedBox(width: 10),
                  Text('Checking verification status...',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[400])),
                ],
              ),
              const SizedBox(height: 40),

              // RESEND BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendVerificationEmail,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Resend Email',
                          style: TextStyle(
                              fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.grey),
                  label: const Text('Back to Login',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _agreedToTerms = false; // NEW

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedYear = 'First Year';
  String _selectedDepartment = 'CSE';
  

  
  final List<String> _years = ['First Year', 'Second Year', 'Third Year', 'Final Year', 'Alumni'];
  final List<String> _departments = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'IT', 'BIOTECH', 'CHEM', 'MBA', 'Other'];


  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          if (!mounted) return;
          await _showCompleteProfileDialog(user);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In Failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCompleteProfileDialog(User user) async {
    final _profileFormKey = GlobalKey<FormState>();
    final _phoneCtrl = TextEditingController();

    String dYear = 'First Year';
    String dDept = 'CSE';
    

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Complete Profile"),
              content: SingleChildScrollView(
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Please provide your college details to continue."),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.length != 10 ? 'Enter 10 digits' : null,
                      ),
                      // PHONE WARNING
                      const Padding(
                        padding: EdgeInsets.only(top: 6, bottom: 4),
                        child: Text(
                          '⚠ Your phone number will be visible to other students on your listings. Enter 0000000000 to keep it private.',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: dYear,
                        decoration: const InputDecoration(labelText: 'Year'),
                        items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                        onChanged: (v) => setDialogState(() => dYear = v!),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: dDept,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setDialogState(() => dDept = v!),
                      ),
                      const SizedBox(height: 10),
                     
                      
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (_profileFormKey.currentState!.validate()) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'uid': user.uid,
                        'email': user.email,
                        'name': user.displayName ?? 'Google User',
                        'phone': _phoneCtrl.text.trim(),
                        'year': dYear,
                        'department': dDept,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Save & Continue"),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitAuth() async {
    // TERMS CHECK
    if (!_isLogin && !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm you are a KARE student and 18+')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'year': _selectedYear,
          'department': _selectedDepartment,
         
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('Welcome to',
                    style: TextStyle(fontSize: 24, color: Colors.grey)),
                const Text('CampSwapX',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                const SizedBox(height: 10),
                Text(
                    _isLogin
                        ? 'Login to continue'
                        : 'Register to get started',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 30),

                // EMAIL
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) =>
                      val!.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 15),

                // PASSWORD
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) =>
                      val!.length < 6 ? 'Min 6 chars' : null,
                ),
                const SizedBox(height: 15),

                // REGISTER FIELDS
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) =>
                        val!.length != 10 ? '10 digits required' : null,
                  ),
                  // PHONE NUMBER WARNING
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 4, left: 4),
                    child: Text(
                      '⚠ Your phone number will be visible to other students on your listings. Enter 0000000000 to keep it private.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      prefixIcon: Icon(Icons.school),
                      border: OutlineInputBorder(),
                    ),
                    items: _years
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    items: _departments
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedDepartment = v!),
                  ),
                  const SizedBox(height: 15),

                  
                
                  const SizedBox(height: 15),

                  // TERMS CHECKBOX
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: Colors.blue,
                          onChanged: (val) =>
                              setState(() => _agreedToTerms = val!),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 11),
                            child: Text(
                              'I am a student of KARE and I confirm that I am 18 years or older.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // LOGIN / REGISTER BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isLogin ? 'Login' : 'Register',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 20),

                // OR DIVIDER
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OR",
                            style: TextStyle(color: Colors.grey))),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // GOOGLE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/google_logo.png',
                      height: 34,
                      width: 34,
                    ),
                    label: const Text("Sign in with Google",
                        style: TextStyle(
                            fontSize: 16, color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                ),

                TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _agreedToTerms = false; // RESET ON SWITCH
                  }),
                  child: Center(
                      child: Text(_isLogin
                          ? 'Create an account'
                          : 'I already have an account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




// Import your other screens so navigation works
// import 'product_list_screen.dart';
// import 'lost_and_found_screen.dart';
// import 'my_products_screen.dart';
// import 'profile_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isProfileIncomplete = false;
  StreamSubscription? _userSubscription; // ADD THIS
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
  }

  // ADD DISPOSE
  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserData() {
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        if (mounted) {
          setState(() {
            _userData = snapshot.data();
            _isProfileIncomplete = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userData = null;
            _isProfileIncomplete = true;
          });
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileIncomplete) {
      return _buildCompleteProfileScreen();
    }

    if (_userData == null) {
      return _buildSkeletonLoading();
    }

    final List<Widget> _screens = [
      ProductListScreen(userData: _userData),
      LostAndFoundScreen(userData: _userData),
      const MyProductsScreen(),
      ProfileScreen(
        onLogout: _logout,
        onDeleteStart: () => _userSubscription?.cancel(), // ADD THIS
      ),
    ];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _selectedIndex = 0;
        });
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))]),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.blue[700],
            unselectedItemColor: Colors.grey[400],
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Lost & Found'),
              BottomNavigationBarItem(icon: Icon(Icons.add_box_rounded), label: 'My Ads'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteProfileScreen() {
    final _formKey = GlobalKey<FormState>();
    final _phoneCtrl = TextEditingController();
    String _year = 'First Year';
    String _dept = 'CSE';
    bool _saving = false;
    bool _agreedToTerms = false;

    final List<String> years = ['First Year', 'Second Year', 'Third Year', 'Final Year', 'Alumni'];
    final List<String> depts = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'IT', 'BIOTECH', 'CHEM', 'MBA', 'Other'];

    return Scaffold(
      appBar: AppBar(title: const Text("Complete Registration"), centerTitle: true),
      body: StatefulBuilder(
        builder: (context, setState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Welcome! Please finish setting up your profile.",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.length != 10 ? '10 Digits Required' : null,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 4, left: 4),
                    child: Text(
                      '⚠ Your phone number will be visible to other students on your listings. Enter 0000000000 to keep it private.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField(
                      value: _year,
                      items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _year = v!),
                      decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  DropdownButtonFormField(
                      value: _dept,
                      items: depts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _dept = v!),
                      decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: Colors.blue,
                          onChanged: (val) => setState(() => _agreedToTerms = val!),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 11),
                            child: Text(
                              'I am a student of KARE and I confirm that I am 18 years or older.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (!_agreedToTerms) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm you are a KARE student and 18+')));
                                return;
                              }
                              if (_formKey.currentState!.validate()) {
                                setState(() => _saving = true);
                                final user = FirebaseAuth.instance.currentUser!;
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                  'uid': user.uid,
                                  'email': user.email,
                                  'name': user.displayName ?? 'Google User',
                                  'registerNumber': '',
                                  'phone': _phoneCtrl.text.trim(),
                                  'year': _year,
                                  'department': _dept,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                              }
                            },
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save & Continue", style: TextStyle(fontSize: 18)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        leading: Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: const Icon(Icons.menu)),
        title: Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(width: 150, height: 20, color: Colors.white)),
      ),
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
        child: Column(children: [
          Container(height: 60, color: Colors.white, margin: const EdgeInsets.only(bottom: 10)),
          Expanded(child: ListView.builder(itemCount: 6, padding: const EdgeInsets.all(10), itemBuilder: (_, __) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))))),
        ]),
      ),
    );
  }
}

class LostAndFoundScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const LostAndFoundScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<LostAndFoundScreen> createState() => _LostAndFoundScreenState();
}

class _LostAndFoundScreenState extends State<LostAndFoundScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Lost', 'Found'];

  @override
  Widget build(BuildContext context) {
    // Note: Ensure collection name matches your Firestore ('lost_found' vs 'lostfound')
    // I am using 'lost_found' based on the Rules we set up previously.
    final Query query = FirebaseFirestore.instance
    .collection('lost_found')
    .where('status', isEqualTo: 'approved')
    .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Lost & Found', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. MODERN FILTER HEADER
          Container(
            padding: const EdgeInsets.only(bottom: 15, left: 15, right: 15, top: 10),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _filters.map((filter) {
                bool isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: ChoiceChip(
                    label: Text(filter),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.orange : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    selected: isSelected,
                    selectedColor: Colors.white,
                    backgroundColor: Colors.orange[700],
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 2. LIST AREA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                // SKELETON LOADING
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: 5,
                    itemBuilder: (_, __) => const SkeletonLostFoundCard(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter logic
                final items = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _selectedFilter == 'All' || data['type'] == _selectedFilter;
                }).toList();

                if (items.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10, left: 12, right: 12, bottom: 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index].data() as Map<String, dynamic>;
                    item['id'] = items[index].id;

                    // ANIMATION WRAPPER
                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      builder: (context, double val, child) {
                        return Opacity(
                          opacity: val, 
                          child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)
                        );
                      },
                      child: LostFoundCard(
                        item: item,
                        onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LostFoundDetailScreen(item: item), // Navigate to the full screen
                          ),
                        );
                      },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLostFoundScreen(userData: widget.userData),
            ),
          );
        },
        backgroundColor: Colors.orange,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Report Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.orange[200]),
          const SizedBox(height: 20),
          Text('No items found', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Simple Detail Dialog since we didn't define a DetailScreen for Lost&Found yet
  
}

// --- HELPER CLASSES ---

class LostFoundCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const LostFoundCard({Key? key, required this.item, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isLost = item['type'] == 'Lost';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE
              ClipRRect(
                child: Container(
                width: 80, height: 80,
                color: Colors.grey[100],
                child: item['imageUrl'] != null 
                  ? Image.network(
                      item['imageUrl'], 
                      fit: BoxFit.cover,
                      // --- FIX ---
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.cloud_off, size: 20, color: Colors.grey));
                      },
                      // -----------
                    )
                  : Icon(isLost ? Icons.search : Icons.check_circle, color: isLost ? Colors.red[200] : Colors.green[200], size: 40),
              ),
              ),
              const SizedBox(width: 15),
              
              // INFO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLost ? Colors.red[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: isLost ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3))
                          ),
                          child: Text(
                            item['type'].toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isLost ? Colors.red : Colors.green),
                          ),
                        ),
                        Text(item['date'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['description'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonLostFoundCard extends StatelessWidget {
  const SkeletonLostFoundCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 50, height: 15, color: Colors.white),
                        Container(width: 30, height: 10, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(width: 150, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 14, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}







class LostFoundDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const LostFoundDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<LostFoundDetailScreen> createState() => _LostFoundDetailScreenState();
}

class _LostFoundDetailScreenState extends State<LostFoundDetailScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // --- NEW: CALL LOGIC ---
  Future<void> _callContactPerson() async {
    // 1. Get phone number
    String phone = widget.item['phone'] ?? '';
    
    // 2. Clean the number (remove spaces, dashes)
    phone = phone.replaceAll(RegExp(r'[^0-9]'), ''); 

    if (phone.isEmpty || phone == 'Unknown') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available."))
      );
      return;
    }

    // 3. Create URI
    final Uri callUri = Uri.parse('tel:$phone');

    try {
      // 4. Launch
      if (!await launchUrl(callUri)) {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open phone dialer."))
      );
    }
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteItem() async {
  bool? confirm = await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Delete Report"),
      content: const Text(
          "Has this item been returned or found? This action cannot be undone."),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel")),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.red))),
      ],
    ),
  );

  if (confirm == true) {
    try {
      // 1. DELETE IMAGE FROM CLOUDINARY
      final imageUrl = widget.item['imageUrl'] as String?;
      if (imageUrl != null) {
        await _deleteFromCloudinary(_extractPublicId(imageUrl));
      }

      // 2. DELETE FROM FIRESTORE
        await FirebaseFirestore.instance
            .collection('lost_found')
            .doc(widget.item['id'])
            .delete();

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item removed successfully.")));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }


  String _extractPublicId(String url) {
  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1) return '';
    final afterUpload = segments.sublist(uploadIndex + 1);
    final relevantParts = afterUpload.first.startsWith('v') &&
            int.tryParse(afterUpload.first.substring(1)) != null
        ? afterUpload.sublist(1)
        : afterUpload;
    final withExtension = relevantParts.join('/');
    return withExtension.contains('.')
        ? withExtension.substring(0, withExtension.lastIndexOf('.'))
        : withExtension;
  } catch (e) {
    return '';
  }
}

  Future<void> _deleteFromCloudinary(String publicId) async {
  if (publicId.isEmpty) return;
  try {
    // 1. FETCH CREDENTIALS FROM FIRESTORE
    final configDoc = await FirebaseFirestore.instance
        .collection('config')
        .doc('cloudinary')
        .get();

    if (!configDoc.exists) return;

    final cloudName = configDoc['cloud_name'];
    final apiKey = configDoc['api_key'];
    final apiSecret = configDoc['api_secret'];

    // 2. GENERATE SIGNATURE
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureString = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    final signatureBytes = utf8.encode(signatureString);
    final signature = sha256.convert(signatureBytes).toString();

    // 3. SEND SIGNED DELETE REQUEST
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
    final response = await http.post(url, body: {
      'public_id': publicId,
      'api_key': apiKey,
      'timestamp': timestamp.toString(),
      'signature': signature,
    });

    final result = jsonDecode(response.body);
    debugPrint('Cloudinary delete result: $result');
  } catch (e) {
    debugPrint('Cloudinary delete error: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.item['imageUrl'] as String?;
    final type = widget.item['type'] as String;
    final bool isLost = type == 'Lost';
    final themeColor = isLost ? Colors.red : Colors.green;
    
    // CHECK OWNERSHIP
    final bool isOwner = widget.item['userId'] == currentUid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // APP BAR
                    SliverAppBar(
                      expandedHeight: 350,
                      pinned: true,
                      backgroundColor: themeColor,
                      iconTheme: const IconThemeData(color: Colors.white), // Back button white
                      
                      // --- UPDATED ACTIONS (Black Edit / Red Delete) ---
                      actions: isOwner ? [
                        // 1. Edit Button (Black Icon in White Circle)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.black, size: 20),
                            tooltip: 'Edit',
                            onPressed: () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => EditLostFoundScreen(item: widget.item))
                              );
                            },
                          ),
                        ),

                        // 2. Delete Button (Red Icon in White Circle)
                        Container(
                          margin: const EdgeInsets.only(right: 15), // Little extra space on right
                          decoration: const BoxDecoration(
                            color: Colors.white, 
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            tooltip: 'Delete',
                            onPressed: _deleteItem,
                          ),
                        ),
                      ] : null,
                      // -------------------------------------------------

                      // Your Image Code (Kept exactly as you provided)
                      flexibleSpace: FlexibleSpaceBar(
                        background: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover, // Keeps image filling the space
                                loadingBuilder: (ctx, child, prog) => prog == null ? child : Container(color: Colors.grey[200]),
                                errorBuilder: (ctx, error, stackTrace) => Container(
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [Icon(Icons.cloud_off, color: Colors.grey), Text("Offline", style: TextStyle(fontSize: 10, color: Colors.grey))],
                                  ),
                                ),
                              )
                            : Container(
                                color: themeColor.withOpacity(0.1),
                                child: Icon(isLost ? Icons.search : Icons.check_circle, size: 100, color: themeColor.withOpacity(0.3)),
                              ),
                      ),
                    ),

          // BODY
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item['title'], 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: themeColor.withOpacity(0.5)),
                        ),
                        child: Text(type.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 5),
                      Text("Posted on ${widget.item['date'] ?? 'Unknown'}", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.item['description'], style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5)),

                  const SizedBox(height: 20),
                  const Text("Posted By", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.person, 'Name', widget.item['userName'] ?? widget.item['posterName']),
                        const Divider(height: 20),
                        _buildDetailRow(Icons.phone, 'Phone', widget.item['phone']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // FLOATING ACTION BUTTON (CALL)
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _callContactPerson, // <--- CALLS THE NEW FUNCTION
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
            ),
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text('Contact Person', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 15),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}


class EditLostFoundScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditLostFoundScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<EditLostFoundScreen> createState() => _EditLostFoundScreenState();
}

class _EditLostFoundScreenState extends State<EditLostFoundScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late String _type;
  
  File? _newImage;
  String? _existingImageUrl;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  final String cloudName = 'dh4yiaces'; 
  final String uploadPreset = 'ml_default'; 

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item['title']);
    _descCtrl = TextEditingController(text: widget.item['description']);
    _type = widget.item['type'];
    _existingImageUrl = widget.item['imageUrl'];
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (await pickedFile.length() > 307200) {
          if(!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image too large > 300KB'), backgroundColor: Colors.red));
          return;
        }
        setState(() => _newImage = File(pickedFile.path));
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<String?> _uploadToCloudinary() async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', _newImage!.path));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(String.fromCharCodes(await response.stream.toBytes()));
      return jsonMap['secure_url'];
    }
    throw Exception('Upload Failed');
  }

  Future<void> _update() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);
      try {
        String? finalImageUrl = _existingImageUrl;
        if (_newImage != null) {
          finalImageUrl = await _uploadToCloudinary();
        }

        await FirebaseFirestore.instance.collection('lost_found').doc(widget.item['id']).update({
          'type': _type,
          'title': _titleCtrl.text,
          'description': _descCtrl.text,
          'imageUrl': finalImageUrl,
        });

        if (!mounted) return;
        Navigator.pop(context); // Go back to detail
        Navigator.pop(context); // Go back to list (optional, or rely on stream update)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if(mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLost = _type == 'Lost';
    Color themeColor = isLost ? Colors.red : Colors.green;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Edit Report", style: TextStyle(color: Colors.white)), backgroundColor: themeColor, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // IMAGE
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200, width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withOpacity(0.5)),
                    image: _newImage != null 
                      ? DecorationImage(image: FileImage(_newImage!), fit: BoxFit.cover)
                      : (_existingImageUrl != null ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover) : null),
                  ),
                  child: (_newImage == null && _existingImageUrl == null) 
                    ? Center(child: Icon(Icons.camera_alt, size: 50, color: Colors.grey[400])) 
                    : null,
                ),
              ),
              const SizedBox(height: 20),
              
              // TYPE TOGGLE
              Row(
                children: [
                  _buildToggleBtn("LOST", isLost, Colors.red),
                  const SizedBox(width: 10),
                  _buildToggleBtn("FOUND", !isLost, Colors.green),
                ],
              ),
              const SizedBox(height: 20),

              // FIELDS
              _buildInput(_titleCtrl, "Item Name", Icons.title),
              const SizedBox(height: 15),
              _buildInput(_descCtrl, "Description", Icons.description, maxLines: 4),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _update,
                  style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text("UPDATE", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = label == "LOST" ? 'Lost' : 'Found'),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: Colors.grey),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }
}



class AddLostFoundScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const AddLostFoundScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<AddLostFoundScreen> createState() => _AddLostFoundScreenState();
}

class _AddLostFoundScreenState extends State<AddLostFoundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  String _type = 'Lost';
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // --- CONFIG ---
  final String cloudName = 'dh4yiaces'; 
  final String uploadPreset = 'ml_default'; 

  // --- UPDATED LOGIC WITH PERMISSIONS ---
  Future<void> _pickImage() async {
  try {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      int sizeInBytes = await pickedFile.length();
      if (sizeInBytes > 307200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large! Max size is 300KB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _selectedImage = File(pickedFile.path));
    }
  } catch (e) {
    debugPrint("Error picking image: $e");
  }
}


  Future<String?> _uploadToCloudinary() async {
    if (_selectedImage == null) return null;
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);
      return jsonMap['secure_url'];
    } else {
      throw Exception('Failed to upload image');
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);
      try {
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _uploadToCloudinary();
        }

        await FirebaseFirestore.instance.collection('lost_found').add({
          'type': _type,
          'title': _titleCtrl.text,
          'description': _descCtrl.text,
          'imageUrl': imageUrl, 
          'userId': FirebaseAuth.instance.currentUser!.uid,
          'userName': widget.userData?['name'] ?? 'Unknown',
          'phone': widget.userData?['phone'] ?? 'Unknown',
          'createdAt': FieldValue.serverTimestamp(),
          'date': DateTime.now().toString().split(' ')[0],
          'status': 'pending',       
          'reviewedAt': null,         
          'reviewedBy': null,         
          'rejectionReason': null,    
        });

        if (!mounted) return;
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle),
                      child: const Icon(Icons.campaign_rounded, color: Colors.orange, size: 44),
                    ),
                    const SizedBox(height: 18),
                    const Text('Report Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      'Your lost & found report has been submitted. It will be visible to other students after admin review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                      child: Row(
                        children: const [
                          Icon(Icons.hourglass_empty, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Usually approved within 24 hours', style: TextStyle(fontSize: 13, color: Colors.orange))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Got it!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLost = _type == 'Lost';
    Color themeColor = isLost ? Colors.red : Colors.green;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Report Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IMAGE UPLOAD AREA
              GestureDetector(
                onTap: _pickImage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                    image: _selectedImage != null 
                      ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                      : null,
                  ),
                  child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 50, color: themeColor.withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text('Upload Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          const SizedBox(height: 5),
                          Text('Max 1 image (300KB)', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 25),

              // 2. TOGGLE SWITCH
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _buildToggleBtn("LOST", isLost, Colors.red),
                    _buildToggleBtn("FOUND", !isLost, Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 3. INPUT FIELDS
              _buildModernInput(_titleCtrl, isLost ? 'What did you lose?' : 'What did you find?', Icons.help_outline),
              const SizedBox(height: 15),
              _buildModernInput(_descCtrl, 'Description (Where & When?)', Icons.description_outlined, maxLines: 4),
              
              const SizedBox(height: 40),

              // 4. SUBMIT BUTTON
              SizedBox(
                width: double.infinity, 
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: themeColor.withOpacity(0.4),
                  ),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text(
                        'POST REPORT', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = label == "LOST" ? 'Lost' : 'Found'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 45,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: isActive ? activeColor : Colors.grey[600]
              )
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }
}





class ProductListScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ProductListScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _selectedCategory = 'All';
  String _selectedType = 'All';
  String _searchQuery = ""; // NEW: Search Variable
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _categories = ['All', 'Books', 'Electronics', 'Furniture', 'Cycle', 'Sports', 'Stationery', 'Other'];
  final List<String> _types = ['All', 'Sell', 'Rent'];

  // --- ABOUT DIALOG ---
  void _showAboutDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: const [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 10),
            Text('About App'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.shopping_bag, size: 30, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'CampSwapX - Campus Marketplace',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Center(
                child: Text('Version 1.0.0',
                    style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 20),
              const Text(
                'A platform designed exclusively for Kalasalingam University students to buy, sell, and rent items within the campus securely and easily.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 20),
              const Text(
                'Uploading inappropriate content will result in account suspension.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.justify,
              ),
              const Divider(height: 30),

              // Developer Section
              const Text('Developers',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              const Text('Designed & Developed by:',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color.fromARGB(255, 118, 112, 112))),
              const Text('YuvejKumar',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const Text('Vudugundla Revathi',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const Text('Jaya Varshini Vummadichetty',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const Text('Goutham Reddy Esambadi',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),

              const Divider(height: 30),

              // PRIVACY POLICY SECTION
              const Text('Legal',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://student-management-syste-2ea31.web.app'); // 🔥 PUT YOUR LINK
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open website')),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50], // 🔥 Different color (optional)
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.language, color: Colors.green, size: 20), // 🌐 website icon
                      SizedBox(width: 10),
                      Text(
                        'Visit Our Website',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.open_in_new, color: Colors.green, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse(
                      'https://sites.google.com/view/campswapx/home');
                  try {
                    await launchUrl(url,
                        mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not open link')),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.privacy_tip_outlined,
                          color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.open_in_new,
                          color: Colors.blue, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

  // Helper widget for Tech Stack rows
 

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
    .collection('products')
    .where('status', isEqualTo: 'approved')
    .orderBy('createdAt', descending: true);
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: _showAboutDialog),
        title: const Text('CampSwapX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').where('users', arrayContains: currentUid).snapshots(),
            builder: (context, snapshot) {
              bool hasUnread = false;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['isRead'] == false && data['lastSenderId'] != currentUid) {
                    hasUnread = true; break;
                  }
                }
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                  if (hasUnread)
                    Positioned(right: 11, top: 11, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)))
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. HEADER (Search + Filters)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 15, left: 15, right: 15, top: 10),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- NEW: SEARCH BAR ---
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase().trim();
                    });
                  },
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Search items (e.g. Cycle, Book...)",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                          },
                        ) 
                      : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(height: 15),
                // -----------------------

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((c) {
                      bool isSelected = _selectedCategory == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c, style: TextStyle(color: isSelected ? Colors.blue : Colors.white, fontWeight: FontWeight.bold)),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.blue[700],
                          onSelected: (bool selected) => setState(() => _selectedCategory = c),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Type Chips
                Row(
                  children: _types.map((t) {
                    bool isSelected = _selectedType == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(t, style: TextStyle(color: isSelected ? Colors.blue : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // 2. PRODUCT LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: 6,
                    itemBuilder: (_, __) => const SkeletonProductCard(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                // --- UPDATED FILTER LOGIC ---
                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // 1. Category Filter
                  bool catMatch = _selectedCategory == 'All' || data['category'] == _selectedCategory;
                  
                  // 2. Type Filter
                  bool typeMatch = _selectedType == 'All' || data['type'] == _selectedType;
                  
                  // 3. Search Filter
                  bool searchMatch = _searchQuery.isEmpty || 
                      data['title'].toString().toLowerCase().contains(_searchQuery) ||
                      data['description'].toString().toLowerCase().contains(_searchQuery);

                  return catMatch && typeMatch && searchMatch;
                }).toList();

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    data['id'] = docs[index].id;

                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 400 + (index * 50)),
                      curve: Curves.easeOut,
                      builder: (context, double val, child) {
                        return Opacity(
                          opacity: val,
                          child: Transform.translate(offset: Offset(0, 30 * (1 - val)), child: child),
                        );
                      },
                      child: ProductCard(
                        product: data,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: data))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(userData: widget.userData))),
        backgroundColor: Colors.blue,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Sell Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No products match", style: TextStyle(fontSize: 18, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
// --- 2. ENHANCED PRODUCT CARD ---
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductCard({Key? key, required this.product, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final images = product['images'] as List<dynamic>?;
    final firstImage = images != null && images.isNotEmpty ? images[0] : null;
    final isSell = product['type'] == 'Sell';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE WITH OVERLAY
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100, height: 100,
                      color: Colors.grey[100],
                      child: firstImage != null
                          ? Image.network(
                              firstImage, 
                              fit: BoxFit.cover,
                              // --- FIX: ERROR BUILDER FOR OFFLINE MODE ---
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.cloud_off, size: 24, color: Colors.grey),
                                      SizedBox(height: 4),
                                      Text("Offline", style: TextStyle(fontSize: 10, color: Colors.grey))
                                    ],
                                  ),
                                );
                              },
                              // -------------------------------------------
                            )
                          : Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey[400]),
                    ),
                  ),
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSell ? Colors.green.withOpacity(0.9) : Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product['type'].toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              
              // DETAILS (Unchanged)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.2),
                      maxLines: 2, overflow: TextOverflow.ellipsis
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product['description'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2, overflow: TextOverflow.ellipsis
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product['price']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)
                        ),
                        Text(
                          product['condition'] ?? 'Good',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 3. SKELETON LOADER ---
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15, left: 12, right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: 10),
                    Container(width: 150, height: 14, color: Colors.white),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 60, height: 20, color: Colors.white),
                        Container(width: 40, height: 14, color: Colors.white),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final Map<String, dynamic>? userData;

  const EditProductScreen({
    Key? key,
    required this.productId,
    required this.productData,
    this.userData,
  }) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  final ImagePicker _picker = ImagePicker();
  List<String> _existingImageUrls = [];
  List<XFile> _newImages = [];
  bool _isUploading = false;

  final String cloudName = 'dh4yiaces';
  final String uploadPreset = 'ml_default';

  late String _selectedCategory;
  late String _selectedType;
  late String _selectedCondition;

  final List<String> _categories = ['Books', 'Electronics', 'Furniture', 'Cycle', 'Sports', 'Stationery', 'Other'];
  final List<String> _types = ['Sell', 'Rent'];
  final List<String> _conditions = ['Excellent', 'Good', 'Fair', 'Poor'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.productData['title']);
    _descriptionController = TextEditingController(text: widget.productData['description']);
    _priceController = TextEditingController(text: widget.productData['price']);
    _selectedCategory = widget.productData['category'] ?? 'Books';
    _selectedType = widget.productData['type'] ?? 'Sell';
    _selectedCondition = widget.productData['condition'] ?? 'Good';
    
    final images = widget.productData['images'] as List<dynamic>?;
    if (images != null) {
      _existingImageUrls = images.cast<String>();
    }
  }

  // --- UPDATED IMAGE PICKER LOGIC ---
  Future<void> _pickImages() async {
  try {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      limit: 2, // ← limits selection to 2 in the gallery itself
    );

    if (pickedFiles.isNotEmpty) {
      List<XFile> validFiles = [];
      bool sizeExceeded = false;

      for (var file in pickedFiles) {
        int sizeInBytes = await file.length();
        if (sizeInBytes <= 307200) {
          validFiles.add(file);
        } else {
          sizeExceeded = true;
        }
      }

      setState(() {
        _newImages.addAll(validFiles);

        int totalImages = _existingImageUrls.length + _newImages.length;
        if (totalImages > 2) {
          int excess = totalImages - 2;
          if (_newImages.length >= excess) {
            _newImages = _newImages.sublist(0, _newImages.length - excess);
          }
        }
      });

      if (sizeExceeded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some images were skipped (max 300KB each)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint("Error picking images: $e");
  }
}


  

  void _removeExistingImage(int index) => setState(() => _existingImageUrls.removeAt(index));
  void _removeNewImage(int index) => setState(() => _newImages.removeAt(index));

  Future<List<String>> _uploadNewImages() async {
    List<String> downloadUrls = [];
    for (var imageFile in _newImages) {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        downloadUrls.add(jsonMap['secure_url']);
      } else { throw Exception('Failed to upload image'); }
    }
    return downloadUrls;
  }

  Future<void> _updateProduct() async {
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please keep at least 1 image')));
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);
      try {
        List<String> newImageUrls = await _uploadNewImages();
        List<String> allImageUrls = [..._existingImageUrls, ...newImageUrls];

        await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'price': _priceController.text,
          'category': _selectedCategory,
          'type': _selectedType,
          'condition': _selectedCondition,
          'images': allImageUrls,
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if(mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: const Text('Edit Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IMAGE EDITOR
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    if (_existingImageUrls.isNotEmpty || _newImages.isNotEmpty)
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Existing Images (Network)
                            ..._existingImageUrls.asMap().entries.map((entry) {
                              return _buildImageThumbnail(
                                imageProvider: NetworkImage(entry.value),
                                onDelete: () => _removeExistingImage(entry.key),
                                isLocal: false,
                              );
                            }),
                            // New Images (Local File)
                            ..._newImages.asMap().entries.map((entry) {
                              return _buildImageThumbnail(
                                imageProvider: FileImage(File(entry.value.path)),
                                onDelete: () => _removeNewImage(entry.key),
                                isLocal: true,
                              );
                            }),
                          ],
                        ),
                      )
                    else 
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("No images selected", style: TextStyle(color: Colors.grey)),
                      ),
                    
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: (_existingImageUrls.length + _newImages.length) < 2 ? _pickImages : null,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text('Add / Change Photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const Text("Max 2 images • Max 300KB each", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              // 2. INPUT FIELDS
              _buildInput(_titleController, 'Product Title', Icons.title),
              const SizedBox(height: 15),
              _buildInput(_descriptionController, 'Description', Icons.description_outlined, maxLines: 4),
              const SizedBox(height: 15),
              
              Row(
                children: [
                  Expanded(child: _buildDropdown('Category', _selectedCategory, _categories, (v) => setState(() => _selectedCategory = v!))),
                  const SizedBox(width: 15),
                  Expanded(child: _buildDropdown('Type', _selectedType, _types, (v) => setState(() => _selectedType = v!))),
                ],
              ),
              const SizedBox(height: 15),
              _buildDropdown('Condition', _selectedCondition, _conditions, (v) => setState(() => _selectedCondition = v!)),
              const SizedBox(height: 15),
              _buildInput(_priceController, 'Price', Icons.currency_rupee, isNumber: true),

              const SizedBox(height: 40),
              
              // 3. UPDATE BUTTON
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.4),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('UPDATE PRODUCT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildImageThumbnail({required ImageProvider imageProvider, required VoidCallback onDelete, required bool isLocal}) {
    return Stack(
      children: [
        Container(
          width: 100, height: 100,
          margin: const EdgeInsets.only(right: 10, top: 5), 
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: isLocal ? Border.all(color: Colors.green, width: 2) : Border.all(color: Colors.grey[300]!),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: 0, top: 0,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
              child: const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: onChanged,
    );
  }
}





class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = false;

  // --- LOGIC (Same) ---
  Future<void> _callSeller() async {
    String phone = widget.product['phone'] ?? '';
    phone = phone.replaceAll(RegExp(r'[^0-9]'), ''); 
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone number not available.")));
      return;
    }
    final Uri callUri = Uri.parse('tel:$phone');
    try {
      if (!await launchUrl(callUri)) throw 'Could not launch';
    } catch (e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open dialer.")));
    }
  }

  Future<void> _handleMakeOffer() async {
    setState(() => _isLoading = true);
    try {
      if (widget.product['sellerId'] == currentUserId) throw Exception("You cannot chat with yourself.");
      final String chatId = '${widget.product['id']}_$currentUserId';
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // GET BUYER NAME FIRST
          final buyerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          final buyerName = buyerDoc['name'] ?? 'User';

          await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
            'chatId': chatId,
            'productId': widget.product['id'],
            'productTitle': widget.product['title'],
            'productPrice': widget.product['price'],
            'users': [currentUserId, widget.product['sellerId']],
            'buyerId': currentUserId,
            'sellerId': widget.product['sellerId'],
            'sellerName': widget.product['sellerName'],
            'buyerName': buyerName, // ADDED
            'lastMessage': 'Offer initiated',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'isRead': false,
            'lastSenderId': currentUserId,
          });
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUserName: widget.product['sellerName'], productTitle: widget.product['title'])));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> images = widget.product['images'] ?? [];
    bool isSell = widget.product['type'] == 'Sell';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                backgroundColor: Colors.white, 
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black87),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: Colors.white,
                    child: images.isNotEmpty
                      ? PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (ctx, index) => Image.network(
                            images[index], 
                            fit: BoxFit.contain, 
                            loadingBuilder: (ctx, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (ctx, error, stackTrace) => Container(
                              color: Colors.grey[100],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [Icon(Icons.cloud_off, color: Colors.grey), Text("Offline", style: TextStyle(color: Colors.grey, fontSize: 10))],
                              ),
                            ),
                          ),
                        )
                      : Container(color: Colors.grey[100], child: const Icon(Icons.image, size: 80, color: Colors.grey)),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(widget.product['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2))),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSell ? Colors.green[50] : Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSell ? Colors.green : Colors.blue),
                            ),
                            child: Text(widget.product['type'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSell ? Colors.green : Colors.blue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('₹${widget.product['price']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.blue)),
                      
                      const SizedBox(height: 20),

                      // --- NEW: COMMON MEETING PLACE CARD ---
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_library_rounded, color: Colors.amber, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Common Meeting Place", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                  Text("Meet at University Library for safe transactions.", style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // -------------------------------------

                      const SizedBox(height: 25),
                      const Divider(),
                      const SizedBox(height: 15),

                      const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(widget.product['description'], style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5)),
                      const SizedBox(height: 25),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _buildRow(Icons.category, 'Category', widget.product['category']),
                            const SizedBox(height: 12),
                            _buildRow(Icons.star, 'Condition', widget.product['condition']),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      const Text('Seller', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: Colors.blue[100], child: Text(widget.product['sellerName'][0].toUpperCase())),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.product['sellerName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text("${widget.product['year']} • ${widget.product['department']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callSeller,
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: const Text("Call"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleMakeOffer,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.chat_bubble),
                      label: const Text("Chat / Offer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 15),
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const Spacer(),
        Text(value ?? 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}




class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const AddProductScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;
  
  // --- CLOUDINARY CONFIG ---
  final String cloudName = 'dh4yiaces'; 
  final String uploadPreset = 'ml_default'; 

  String _selectedCategory = 'Books';
  String _selectedType = 'Sell';
  String _selectedCondition = 'Good';

  final List<String> _categories = ['Books', 'Electronics', 'Furniture', 'Cycle', 'Sports', 'Stationery', 'Other'];
  final List<String> _types = ['Sell', 'Rent'];
  final List<String> _conditions = ['Excellent', 'Good', 'Fair', 'Poor'];

  // --- UPDATED LOGIC WITH PERMISSIONS ---
  Future<void> _pickImages() async {
  try {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      limit: 2, // ← limits selection to 2 in the gallery itself
    );

    if (pickedFiles.isNotEmpty) {
      List<XFile> validFiles = [];
      bool sizeExceeded = false;

      for (var file in pickedFiles) {
        int sizeInBytes = await file.length();
        if (sizeInBytes <= 307200) {
          validFiles.add(file);
        } else {
          sizeExceeded = true;
        }
      }

      setState(() {
        _selectedImages.addAll(validFiles);
        // Extra safety trim
        if (_selectedImages.length > 2) {
          _selectedImages = _selectedImages.sublist(0, 2);
        }
      });

      if (sizeExceeded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some images were skipped (max 300KB each)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint("Error picking images: $e");
  }
}

 

  void _removeImage(int index) => setState(() => _selectedImages.removeAt(index));

  Future<List<String>> _uploadImagesToCloudinary() async {
    List<String> downloadUrls = [];
    for (var imageFile in _selectedImages) {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        downloadUrls.add(jsonMap['secure_url']);
      } else { throw Exception('Upload failed'); }
    }
    return downloadUrls;
  }

  Future<void> _saveProduct() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 1 image')));
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        List<String> imageUrls = await _uploadImagesToCloudinary();
        
        await FirebaseFirestore.instance.collection('products').add({
          'sellerId': user!.uid,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'price': _priceController.text,
          'category': _selectedCategory,
          'type': _selectedType,
          'condition': _selectedCondition,
          'images': imageUrls, 
          'sellerName': widget.userData?['name'] ?? 'Unknown',
          'department': widget.userData?['department'] ?? 'Unknown',
          'year': widget.userData?['year'] ?? 'Unknown',
          'phone': widget.userData?['phone'] ?? 'Unknown',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',       
          'reviewedAt': null,         
          'reviewedBy': null,         
          'rejectionReason': null,    
        });

        if (!mounted) return;
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 44),
                    ),
                    const SizedBox(height: 18),
                    const Text('Ad Posted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      'Your listing has been submitted and is pending admin approval. It will go live within 24 hours.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                      child: Row(
                        children: const [
                          Icon(Icons.hourglass_empty, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Usually approved within 24 hours', style: TextStyle(fontSize: 13, color: Colors.orange))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Got it!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if(mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Post Ad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.blue, 
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IMAGE UPLOAD
              GestureDetector(
                onTap: _pickImages,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: _selectedImages.isEmpty 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 50, color: Colors.blue[200]),
                          const SizedBox(height: 10),
                          Text('Add Photos (Max 2)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          Text('Max Size = 300KB', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),

                        ],
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(10),
                        itemCount: _selectedImages.length,
                        itemBuilder: (ctx, index) => Stack(
                          children: [
                            Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                image: DecorationImage(image: FileImage(File(_selectedImages[index].path)), fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(right: 15, top: 5, child: InkWell(onTap: () => _removeImage(index), child: const CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.close, size: 16, color: Colors.red)))),
                          ],
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 25),

              // 2. INPUT FIELDS
              _buildInput(_titleController, 'Product Title', Icons.title),
              const SizedBox(height: 15),
              _buildInput(_descriptionController, 'Description', Icons.description_outlined, maxLines: 4),
              const SizedBox(height: 15),
              
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown('Category', _selectedCategory, _categories, (v) => setState(() => _selectedCategory = v!)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildDropdown('Type', _selectedType, _types, (v) => setState(() => _selectedType = v!)),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildDropdown('Condition', _selectedCondition, _conditions, (v) => setState(() => _selectedCondition = v!)),
              const SizedBox(height: 15),
              
              _buildInput(_priceController, 'Price', Icons.currency_rupee, isNumber: true),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.4),
                  ),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('POST AD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: onChanged,
    );
  }
}







class MyProductsScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const MyProductsScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1) return '';
      final afterUpload = segments.sublist(uploadIndex + 1);
      final relevantParts = afterUpload.first.startsWith('v') &&
              int.tryParse(afterUpload.first.substring(1)) != null
          ? afterUpload.sublist(1)
          : afterUpload;
      final withExtension = relevantParts.join('/');
      return withExtension.contains('.')
          ? withExtension.substring(0, withExtension.lastIndexOf('.'))
          : withExtension;
    } catch (e) {
      return '';
    }
  }

  Future<void> _deleteFromCloudinary(String publicId) async {
    if (publicId.isEmpty) return;
    try {
      final configDoc = await FirebaseFirestore.instance.collection('config').doc('cloudinary').get();
      if (!configDoc.exists) return;
      final cloudName = configDoc['cloud_name'];
      final apiKey = configDoc['api_key'];
      final apiSecret = configDoc['api_secret'];
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signatureString = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signatureBytes = utf8.encode(signatureString);
      final signature = sha256.convert(signatureBytes).toString();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      await http.post(url, body: {
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      });
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
    }
  }

  Future<void> _deleteProduct(BuildContext context, String productId, List<dynamic>? images) async {
    try {
      if (images != null) {
        for (String imageUrl in images.cast<String>()) {
          await _deleteFromCloudinary(_extractPublicId(imageUrl));
        }
      }
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteLostFound(BuildContext context, String docId, String? imageUrl) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Report"),
        content: const Text("Are you sure you want to delete this report?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (imageUrl != null) {
        await _deleteFromCloudinary(_extractPublicId(imageUrl));
      }
      await FirebaseFirestore.instance.collection('lost_found').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted successfully!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green; icon = Icons.check_circle; label = 'Approved'; break;
      case 'rejected':
        color = Colors.red; icon = Icons.cancel; label = 'Rejected'; break;
      default:
        color = Colors.orange; icon = Icons.hourglass_empty; label = 'Pending Review';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Ads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'My Products'),
            Tab(icon: Icon(Icons.search_outlined), text: 'Lost & Found'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: MY PRODUCTS ──
          _buildProductsTab(context, user),
          // ── TAB 2: MY LOST & FOUND ──
          _buildLostFoundTab(context, user),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(userData: widget.userData)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddLostFoundScreen(userData: widget.userData)));
          }
        },
        backgroundColor: Colors.blue,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (_, __) => Text(
            _tabController.index == 0 ? 'Add Product' : 'Report Item',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: 5, itemBuilder: (_, __) => const SkeletonMyProductCard());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_shopping_cart, size: 80, color: Colors.blue[100]),
              const SizedBox(height: 20),
              Text('No products posted yet', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(userData: widget.userData))),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Post Your First Ad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              ),
            ]),
          );
        }

        final products = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index].data() as Map<String, dynamic>;
            final productId = products[index].id;
            final images = product['images'] as List<dynamic>?;
            final firstImage = images != null && images.isNotEmpty ? images[0] : null;
            final status = product['status'] ?? 'pending';
            final rejectionReason = product['rejectionReason'] as String?;

            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 100)),
              builder: (context, double val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80, height: 80, color: Colors.grey[100],
                          child: firstImage != null
                              ? Image.network(firstImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.cloud_off, size: 24, color: Colors.grey))))
                              : Icon(Icons.image, size: 30, color: Colors.grey[400]),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(product['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('₹${product['price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 4),
                          Text('${product['type']} • ${product['category']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          _buildStatusBadge(status),
                        ]),
                      ),
                      Column(children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(productId: productId, productData: product, userData: widget.userData))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete'),
                              content: const Text('Are you sure?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                TextButton(onPressed: () { Navigator.pop(ctx); _deleteProduct(context, productId, images); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ]),

                    if (status == 'pending') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.4))),
                        child: Row(children: const [Icon(Icons.info_outline, size: 16, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Your post is under review and will be approved within 24 hours.', style: TextStyle(fontSize: 12, color: Colors.orange)))]),
                      ),
                    ],

                    if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.4))),
                        child: Row(children: [const Icon(Icons.error_outline, size: 16, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text('Rejected: $rejectionReason', style: const TextStyle(fontSize: 12, color: Colors.red)))]),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLostFoundTab(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lost_found')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: 5, itemBuilder: (_, __) => const SkeletonMyProductCard());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search_off, size: 80, color: Colors.orange[100]),
              const SizedBox(height: 20),
              Text('No reports posted yet', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddLostFoundScreen(userData: widget.userData))),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Report an Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              ),
            ]),
          );
        }

        final items = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index].data() as Map<String, dynamic>;
            final docId = items[index].id;
            final imageUrl = item['imageUrl'] as String?;
            final isLost = item['type'] == 'Lost';
            final status = item['status'] ?? 'pending';
            final rejectionReason = item['rejectionReason'] as String?;
            final typeColor = isLost ? Colors.red : Colors.green;

            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 100)),
              builder: (context, double val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // IMAGE
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80, height: 80, color: Colors.grey[100],
                          child: imageUrl != null
                              ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.cloud_off, size: 24, color: Colors.grey))))
                              : Icon(isLost ? Icons.search : Icons.check_circle, size: 30, color: typeColor.withOpacity(0.4)),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // INFO
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          // LOST / FOUND BADGE
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: typeColor.withOpacity(0.4)),
                            ),
                            child: Text(item['type'].toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor)),
                          ),
                          const SizedBox(height: 6),
                          Text(item['date'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          const SizedBox(height: 6),
                          _buildStatusBadge(status),
                        ]),
                      ),

                      // ACTIONS
                      Column(children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            item['id'] = docId;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => EditLostFoundScreen(item: item)));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteLostFound(context, docId, imageUrl),
                        ),
                      ]),
                    ]),

                    // DESCRIPTION PREVIEW
                    if ((item['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(item['description'], style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],

                    if (status == 'pending') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.4))),
                        child: Row(children: const [Icon(Icons.info_outline, size: 16, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Your report is under review and will be approved within 24 hours.', style: TextStyle(fontSize: 12, color: Colors.orange)))]),
                      ),
                    ],

                    if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.4))),
                        child: Row(children: [const Icon(Icons.error_outline, size: 16, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text('Rejected: $rejectionReason', style: const TextStyle(fontSize: 12, color: Colors.red)))]),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}


// 3. SKELETON CLASS FOR MY PRODUCTS
class SkeletonMyProductCard extends StatelessWidget {
  const SkeletonMyProductCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 120, height: 12, color: Colors.white),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(width: 30, height: 30, color: Colors.white),
                  const SizedBox(height: 10),
                  Container(width: 30, height: 30, color: Colors.white),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}





class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onDeleteStart; // ADD THIS

  const ProfileScreen({
    Key? key,
    required this.onLogout,
    required this.onDeleteStart, // ADD THIS
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isDeleting = false;

  final List<Map<String, String>> _developers = [
    {'name': 'Yuvej kumar', 'url': 'https://www.linkedin.com/in/yuvejkumar/'},
    {'name': 'V Revathi', 'url': 'https://www.linkedin.com/in/revathi-vudugundla-46a7893b3?utm_source=share_via&utm_content=profile&utm_medium=member_android'},
    {'name': 'Jaya Varshini', 'url': 'https://www.linkedin.com/in/jaya-varshini-vummadichetty-514783378'},
    {'name': 'Goutham Reddy', 'url': 'https://www.linkedin.com/in/goutham-reddy-esambadi-99955831b/'}
  ];

  void _showDevelopersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: const [Icon(Icons.people, color: Colors.blue), SizedBox(width: 10), Text("Developers")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _developers.map((dev) => ListTile(
            leading: const Icon(Icons.link, color: Colors.blue),
            title: Text(dev['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => _launchURL(dev['url']!),
          )).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw 'Err';
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () { Navigator.pop(ctx); widget.onLogout(); }, child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
        content: const Text("Are you sure? This will permanently delete your profile, ads, and messages."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); _deleteAccount(); },
            child: const Text("Delete Forever", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (user == null) return;
    setState(() => _isDeleting = true);

    // CANCEL FIRESTORE LISTENER BEFORE ANYTHING ELSE
    widget.onDeleteStart();

    try {
      final String uid = user!.uid;
      final db = FirebaseFirestore.instance;

      // 1. DELETE PRODUCT IMAGES FROM CLOUDINARY THEN FIRESTORE
      var products = await db.collection('products').where('sellerId', isEqualTo: uid).get();
      for (var doc in products.docs) {
        final images = doc['images'] as List<dynamic>?;
        if (images != null) {
          for (String imageUrl in images.cast<String>()) {
            await _deleteFromCloudinary(_extractPublicId(imageUrl));
          }
        }
        await doc.reference.delete();
      }

      // 2. DELETE LOST & FOUND IMAGES FROM CLOUDINARY THEN FIRESTORE
      var lostFound = await db.collection('lost_found').where('userId', isEqualTo: uid).get();
      for (var doc in lostFound.docs) {
        final imageUrl = doc['imageUrl'] as String?;
        if (imageUrl != null) {
          await _deleteFromCloudinary(_extractPublicId(imageUrl));
        }
        await doc.reference.delete();
      }

      // 3. DELETE CHATS
      var chats = await db.collection('chats').where('users', arrayContains: uid).get();
      for (var doc in chats.docs) {
        var messages = await doc.reference.collection('messages').get();
        for (var msg in messages.docs) {
          await msg.reference.delete();
        }
        await doc.reference.delete();
      }

      // 4. DELETE USER DOCUMENT
      await db.collection('users').doc(uid).delete();

      // 5. SAVE REFERENCE BEFORE SIGNING OUT
      final userToDelete = user!;

      // 6. SIGN OUT FIRST (triggers AuthWrapper → LoginScreen)
      await FirebaseAuth.instance.signOut();

      // 7. DELETE AUTH ACCOUNT USING SAVED REFERENCE
      await userToDelete.delete();

    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please re-login to delete.')));
      }
    }
  }

  String _extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1) return '';
      final afterUpload = segments.sublist(uploadIndex + 1);
      final relevantParts = afterUpload.first.startsWith('v') &&
              int.tryParse(afterUpload.first.substring(1)) != null
          ? afterUpload.sublist(1)
          : afterUpload;
      final withExtension = relevantParts.join('/');
      return withExtension.contains('.')
          ? withExtension.substring(0, withExtension.lastIndexOf('.'))
          : withExtension;
    } catch (e) {
      return '';
    }
  }

  Future<void> _deleteFromCloudinary(String publicId) async {
    if (publicId.isEmpty) return;
    try {
      final configDoc = await FirebaseFirestore.instance.collection('config').doc('cloudinary').get();
      if (!configDoc.exists) return;

      final cloudName = configDoc['cloud_name'];
      final apiKey = configDoc['api_key'];
      final apiSecret = configDoc['api_secret'];

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signatureString = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signatureBytes = utf8.encode(signatureString);
      final signature = sha256.convert(signatureBytes).toString();

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      final response = await http.post(url, body: {
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      final result = jsonDecode(response.body);
      debugPrint('Cloudinary delete result: $result');
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
    }
  }
      void _showReportDialog(BuildContext context) {
      final _formKey = GlobalKey<FormState>();
      final _descCtrl = TextEditingController();
      String _reportType = 'Bug / App Issue';
      bool _isSubmitting = false;

      final List<String> reportTypes = [
        'Bug / App Issue',
        'Inappropriate Listing',
        'Scam / Fraud',
        'Fake Profile',
        'Harassment',
        'Other',
      ];

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: const [
                    Icon(Icons.flag_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Report an Issue'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Help us keep CampSwapX safe. Your report will be reviewed by the admin.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        // TYPE DROPDOWN
                        const Text('Report Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _reportType,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: reportTypes
                              .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14))))
                              .toList(),
                          onChanged: (v) => setDialogState(() => _reportType = v!),
                        ),
                        const SizedBox(height: 16),

                        // DESCRIPTION
                        const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Describe the issue in detail...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please describe the issue' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  StatefulBuilder(
                    builder: (context, setButtonState) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                setButtonState(() => _isSubmitting = true);
                                try {
                                  final u = FirebaseAuth.instance.currentUser;
                                  await FirebaseFirestore.instance.collection('reports').add({
                                    'type': _reportType,
                                    'description': _descCtrl.text.trim(),
                                    'userId': u?.uid,
                                    'userEmail': u?.email,
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'status': 'pending',
                                  });
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 10),
                                          Text('Report submitted successfully!'),
                                        ],
                                      ),
                                      backgroundColor: Colors.green[600],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                } finally {
                                  if (mounted) setButtonState(() => _isSubmitting = false);
                                }
                              },
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Submit Report', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }

  void _showEditProfileDialog(Map<String, dynamic> currentData) {
    final _formKey = GlobalKey<FormState>();
    TextEditingController phoneCtrl = TextEditingController(text: currentData['phone']);

    final List<String> years = ['First Year', 'Second Year', 'Third Year', 'Final Year', 'Alumni'];
    final List<String> depts = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'IT', 'BIOTECH', 'CHEM', 'MBA', 'Other'];

    String sYear = years.contains(currentData['year']) ? currentData['year'] : years[0];
    String sDept = depts.contains(currentData['department']) ? currentData['department'] : depts[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _buildReadOnlyField('Name', currentData['name']),
                  const SizedBox(height: 10),
                  TextFormField(controller: phoneCtrl, decoration: _inputDec('Phone'), keyboardType: TextInputType.phone, validator: (v) => v!.length != 10 ? 'Invalid' : null),
                  const SizedBox(height: 10),
                  _buildDropdown('Year', sYear, years, (v) => setStateDialog(() => sYear = v!)),
                  const SizedBox(height: 10),
                  _buildDropdown('Department', sDept, depts, (v) => setStateDialog(() => sDept = v!)),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                    'phone': phoneCtrl.text.trim(),
                    'year': sYear,
                    'department': sDept,
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
                }
              }, child: const Text('Save')),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.red)));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const SkeletonProfile();
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("User data not found"));

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    ClipPath(
                      clipper: HeaderClipper(),
                      child: Container(height: 260, width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue[800]!, Colors.blue[400]!]))),
                    ),
                    Positioned(top: 50, right: 20, child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _showEditProfileDialog(userData)))),
                    Positioned(top: 80, child: Column(children: [
                      Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: CircleAvatar(radius: 50, backgroundColor: Colors.blue[50], child: Text(userData['name']?.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(fontSize: 40, color: Colors.blue, fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 10),
                      Text(userData['name'] ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(userData['registerNumber'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    ])),
                  ],
                ),

                const SizedBox(height: 60),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildInfoTile(Icons.school, 'Department', userData['department']),
                      _buildInfoTile(Icons.calendar_today, 'Year', userData['year']),
                      _buildInfoTile(Icons.phone, 'Phone', userData['phone']),

                      const SizedBox(height: 30),

                      SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                        icon: const Icon(Icons.star_rate_rounded, color: Colors.white),
                        label: const Text('Give Feedback', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[400], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- NEW REPORT BUTTON ---
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () => _showReportDialog(context),
                        icon: const Icon(Icons.flag_rounded, color: Colors.white),
                        label: const Text('Report an Issue', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout_rounded, color: Colors.white),
                          label: const Text('Logout', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[400], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextButton.icon(
                        onPressed: _confirmDeleteAccount,
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),

                      const Text('Developed by', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const Text('Team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 5),

                      InkWell(
                        onTap: _showDevelopersDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFF0077b5).withOpacity(0.1), borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0xFF0077b5))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.link, size: 20, color: Color(0xFF0077b5)), SizedBox(width: 8), Text('Developers LinkedIn', style: TextStyle(color: Color(0xFF0077b5), fontWeight: FontWeight.bold))]),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: Icon(icon, color: Colors.blue, size: 20)),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          Text(value ?? 'N/A', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ]),
      ]),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));
  Widget _buildReadOnlyField(String label, String val) => TextField(controller: TextEditingController(text: val), decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), enabled: false);
  Widget _buildDropdown(String label, String val, List<String> items, Function(String?) changed) => DropdownButtonFormField<String>(value: val, decoration: _inputDec(label), items: items.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(), onChanged: changed);
}
// --- HELPER CLASSES (HeaderClipper & SkeletonProfile) ---


// --- CURVED CLIPPER ---
class HeaderClipper extends CustomClipper<Path> {
  @override
    Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// --- SKELETON PROFILE ---
class SkeletonProfile extends StatelessWidget {
const SkeletonProfile({Key? key}) : super(key: key);

      @override
      Widget build(BuildContext context) {
        return Scaffold(
        backgroundColor: Colors.white,
        body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
        children: [
        Container(height: 250, color: Colors.white), // Header
        const SizedBox(height: 20),
        Container(width: 200, height: 24, color: Colors.white), // Name
        const SizedBox(height: 10),
        Container(width: 100, height: 16, color: Colors.white), // Reg No
        const SizedBox(height: 40),
        Expanded(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
      children: List.generate(5, (index) => Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
      )),
      ),
      ),
      ),
      ],
      ),
      ),
      );
      }
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: currentUid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. SKELETON LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: 6,
              itemBuilder: (_, __) => const SkeletonChatTile(),
            );
          }

          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.chat_bubble_outline, size: 80, color: Colors.blue[100]),
                   const SizedBox(height: 20),
                   Text("No messages yet", style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                 ],
               ),
             );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              String displayName = data['productTitle'] ?? 'Chat';
              String subtitle = data['lastMessage'] ?? '';
              Timestamp? time = data['lastMessageTime'];
              
              // Unread Logic
              bool isUnread = (data['isRead'] == false) && (data['lastSenderId'] != currentUid);

              // 2. ANIMATED LIST ITEM
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 100)),
                builder: (context, double val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isUnread ? Colors.blue[50] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: isUnread ? Border.all(color: Colors.blue.withOpacity(0.3)) : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: isUnread ? Colors.blue : Colors.blue[100],
                      child: Icon(Icons.person, color: isUnread ? Colors.white : Colors.blue),
                    ),
                    title: Text(
                      displayName, 
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                        fontSize: 16,
                      )
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        subtitle, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.grey[600],
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        )
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimestamp(time),
                          style: TextStyle(fontSize: 12, color: isUnread ? Colors.blue : Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        if (isUnread)
                          Container(
                            width: 12, height: 12,
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          )
                      ],
                    ),
                    onTap: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: data['chatId'],
                            otherUserName: currentUid == data['sellerId']
                                ? data['buyerName'] ?? 'User'
                                : data['sellerName'] ?? 'User',
                            productTitle: data['productTitle'] ?? 'Product',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Simple Helper to format time (e.g. 10:30)
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

// --- SKELETON TILE ---
class SkeletonChatTile extends StatelessWidget {
  const SkeletonChatTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
        child: Row(
          children: [
            Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 150, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 200, height: 14, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String productTitle;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserName,
    required this.productTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _markAsRead() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'isRead': true});
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final msg = _msgController.text.trim();
    _msgController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'text': msg,
      'senderId': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': msg,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
      'isRead': false,
    });
  }

  // DELETE CHAT
  Future<void> _deleteChat() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Chat"),
        content: const Text(
            "Are you sure you want to delete this chat? This will delete all messages and cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. DELETE ALL MESSAGES IN SUBCOLLECTION
        final messages = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .get();
        for (var msg in messages.docs) {
          await msg.reference.delete();
        }

        // 2. DELETE CHAT DOCUMENT
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .delete();

        if (!mounted) return;
        Navigator.pop(context); // GO BACK TO CHAT LIST
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  widget.productTitle,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        // DELETE BUTTON IN APPBAR
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete Chat',
            onPressed: _deleteChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // MESSAGES LIST
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text('No messages yet',
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16)),
                          const SizedBox(height: 5),
                          Text('Start the conversation!',
                              style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == currentUid;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width *
                                      0.75),
                          decoration: BoxDecoration(
                            gradient: isMe
                                ? LinearGradient(colors: [
                                    Colors.blue[400]!,
                                    Colors.blue[700]!
                                  ])
                                : null,
                            color: isMe ? null : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isMe
                                  ? const Radius.circular(20)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            data['text'],
                            style: TextStyle(
                              color:
                                  isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    onTap: _markAsRead,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.blue, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _commentCtrl = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a star rating!")));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'rating': _rating,
        'comment': _commentCtrl.text.trim(),
        'userId': user?.uid,
        'userName': user?.displayName ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Thank you for your feedback! ❤️")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showAdminLogin() {
    final idCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: const [
            Icon(Icons.admin_panel_settings, color: Colors.blue),
            SizedBox(width: 10),
            Text("Admin Access"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: InputDecoration(
                labelText: "Admin ID",
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              try {
                final doc = await FirebaseFirestore.instance
                    .collection('admin')
                    .doc('credentials')
                    .get();

                if (doc.exists &&
                    doc['id'] == idCtrl.text.trim() &&
                    doc['password'] == passCtrl.text.trim()) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Invalid Credentials"),
                      backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Login",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Give Feedback",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("How was your experience?",
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                "Your feedback helps us improve the CampSwapX.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            // STAR RATING
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: () => setState(() => _rating = index + 1),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // COMMENT BOX
            TextField(
              controller: _commentCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    "Tell us what you liked or what we can improve...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 30),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit Feedback",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 50),
            const Divider(),

            // ADMIN ANALYTICS BUTTON
            Center(
              child: TextButton.icon(
                onPressed: _showAdminLogin,
                icon: const Icon(Icons.analytics, color: Colors.grey),
                label: const Text("View Analytics (Admin Only)",
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ANALYTICS SCREEN (Protected) ---
class FeedbackAnalyticsScreen extends StatefulWidget {
  const FeedbackAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackAnalyticsScreen> createState() => _FeedbackAnalyticsScreenState();
}

class _FeedbackAnalyticsScreenState extends State<FeedbackAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.star), text: 'Feedback'),
            Tab(icon: Icon(Icons.flag), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FeedbackTab(),
          _ReportsTab(),
        ],
      ),
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No feedback yet'));

        double total = docs.fold(0, (sum, d) => sum + (d['rating'] as num));
        String avg = (total / docs.length).toStringAsFixed(1);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.purple[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    Text(docs.length.toString(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.purple)),
                    const Text('Total Reviews'),
                  ]),
                  Column(children: [
                    Text(avg, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.amber)),
                    const Text('Avg Rating'),
                  ]),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: Text(d['rating'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    ),
                    title: Text(d['comment']?.isEmpty ?? true ? 'No comment' : d['comment']),
                    subtitle: Text('By: ${d['userName'] ?? 'Anonymous'}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({Key? key}) : super(key: key);

  Color _typeColor(String type) {
    switch (type) {
      case 'Bug / App Issue': return Colors.orange;
      case 'Inappropriate Listing': return Colors.red;
      case 'Scam / Fraud': return Colors.red[800]!;
      case 'Fake Profile': return Colors.deepOrange;
      case 'Harassment': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(docId)
        .update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No reports yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        int pending = docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
        int resolved = docs.where((d) => (d.data() as Map)['status'] == 'resolved').length;

        return Column(
          children: [
            // SUMMARY
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.red[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    Text(docs.length.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
                    const Text('Total'),
                  ]),
                  Column(children: [
                    Text(pending.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const Text('Pending'),
                  ]),
                  Column(children: [
                    Text(resolved.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                    const Text('Resolved'),
                  ]),
                ],
              ),
            ),
            const Divider(height: 1),

            // LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final status = d['status'] ?? 'pending';
                  final color = _typeColor(d['type'] ?? '');
                  final ts = d['timestamp'] as Timestamp?;
                  final dateStr = ts != null
                      ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                      : 'N/A';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOP ROW
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: color.withOpacity(0.4)),
                                ),
                                child: Text(d['type'] ?? 'Unknown',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: status == 'resolved' ? Colors.green[50] : Colors.orange[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'resolved' ? Colors.green[700] : Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // DESCRIPTION
                          Text(
                            d['description'] ?? 'No description',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          // BOTTOM ROW
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(d['userEmail'] ?? 'Unknown',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const Spacer(),
                              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // ACTION BUTTONS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (status == 'pending')
                                TextButton.icon(
                                  onPressed: () => _updateStatus(doc.id, 'resolved'),
                                  icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                  label: const Text('Mark Resolved', style: TextStyle(color: Colors.green, fontSize: 13)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    backgroundColor: Colors.green[50],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () => _updateStatus(doc.id, 'pending'),
                                  icon: const Icon(Icons.refresh, size: 16, color: Colors.orange),
                                  label: const Text('Reopen', style: TextStyle(color: Colors.orange, fontSize: 13)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    backgroundColor: Colors.orange[50],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}


class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: 'Products'),
            Tab(icon: Icon(Icons.search), text: 'Lost & Found'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AdminProductsTab(),
          _AdminLostFoundTab(),
        ],
      ),
    );
  }
}

// --- PRODUCTS TAB ---
class _AdminProductsTab extends StatelessWidget {
  const _AdminProductsTab({Key? key}) : super(key: key);

  Future<void> _approve(String docId) async {
    await FirebaseFirestore.instance.collection('products').doc(docId).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reject(BuildContext context, String docId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Product'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('products').doc(docId).update({
        'status': 'rejected',
        'rejectionReason': reasonCtrl.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green[200]),
                const SizedBox(height: 20),
                Text('No pending products!', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final images = data['images'] as List<dynamic>?;
            final firstImage = images != null && images.isNotEmpty ? images[0] : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGE
                  if (firstImage != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                      child: Image.network(
                        firstImage,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.cloud_off, color: Colors.grey, size: 40)),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PENDING BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.5))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.hourglass_empty, size: 12, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('PENDING REVIEW', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(data['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text('₹${data['price']} • ${data['type']} • ${data['category']}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 5),
                        Text(data['description'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),

                        // SELLER INFO
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('${data['sellerName']} • ${data['department']} • ${data['year']}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // APPROVE / REJECT BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _approve(docId),
                                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _reject(context, docId),
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                label: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- LOST & FOUND TAB ---
class _AdminLostFoundTab extends StatelessWidget {
  const _AdminLostFoundTab({Key? key}) : super(key: key);

  Future<void> _approve(String docId) async {
    await FirebaseFirestore.instance.collection('lost_found').doc(docId).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reject(BuildContext context, String docId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Report'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Rejection Reason (optional)', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('lost_found').doc(docId).update({
        'status': 'rejected',
        'rejectionReason': reasonCtrl.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lost_found')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green[200]),
                const SizedBox(height: 20),
                Text('No pending reports!', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final imageUrl = data['imageUrl'] as String?;
            final isLost = data['type'] == 'Lost';

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                      child: Image.network(
                        imageUrl,
                        height: 200, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.cloud_off, color: Colors.grey, size: 40)),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // PENDING BADGE
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.5))),
                              child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.hourglass_empty, size: 12, color: Colors.orange), SizedBox(width: 4), Text('PENDING', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold))]),
                            ),
                            const SizedBox(width: 8),
                            // LOST/FOUND BADGE
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLost ? Colors.red[50] : Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isLost ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5)),
                              ),
                              child: Text(data['type'].toUpperCase(), style: TextStyle(fontSize: 11, color: isLost ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(data['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(data['description'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('${data['userName']} • ${data['phone']}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ]),
                        ),
                        const SizedBox(height: 15),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _approve(docId),
                                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _reject(context, docId),
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                label: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}


class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Tools', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // MODERATION CARD
            _buildAdminCard(
              context,
              icon: Icons.shield,
              color: Colors.deepPurple,
              title: 'Content Moderation',
              subtitle: 'Review & approve pending products and lost/found reports',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
            ),
            const SizedBox(height: 15),

            // ANALYTICS CARD
            _buildAdminCard(
              context,
              icon: Icons.analytics,
              color: Colors.blue,
              title: 'Feedback Analytics',
              subtitle: 'View user ratings and feedback comments',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackAnalyticsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}