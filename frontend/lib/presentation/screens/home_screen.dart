import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Clean, professional home screen matching the login/signup theme.
/// Features white background with blue accents for consistency.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
  }

  void _goToSignup(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildNavBar(context),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildHeroSection(context, isWide),
                    const SizedBox(height: 60),
                    _buildFeaturesSection(context, isWide),
                    const SizedBox(height: 50),
                    _buildFooter(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'ATS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Color(0xFF1D2A3A),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          FutureBuilder<String?>(
            future: AuthService.getToken(),
            builder: (context, snapshot) {
              final hasToken = snapshot.data != null;
              if (hasToken) {
                return TextButton(
                  onPressed: () async {
                    await AuthService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF007AFF),
                  ),
                  child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
                );
              }
              return Row(
                children: [
                  TextButton(
                    onPressed: () => _goToLogin(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                    ),
                    child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _goToSignup(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Icon/Badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency,
              size: 64,
              color: Color(0xFF007AFF),
            ),
          ),
          const SizedBox(height: 30),
          
          // Main heading
          Text(
            'Ambulance Tracking System',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWide ? 42 : 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1D2A3A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Real-Time Emergency Response',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWide ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF007AFF),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Track ambulances in real-time, receive instant proximity alerts, and coordinate seamlessly between emergency vehicles and traffic police.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWide ? 18 : 16,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          
          // CTA Buttons
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _goToSignup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'GET STARTED',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => _goToLogin(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  side: const BorderSide(color: Color(0xFF007AFF), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SIGN IN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text(
            'Key Features',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2A3A),
            ),
          ),
          const SizedBox(height: 40),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFeatureCard(
                      Icons.gps_fixed,
                      'Live GPS Tracking',
                      'Real-time ambulance location updates on interactive maps',
                    )),
                    const SizedBox(width: 20),
                    Expanded(child: _buildFeatureCard(
                      Icons.notifications_active,
                      'Proximity Alerts',
                      'Instant notifications to nearby traffic police when ambulances approach',
                    )),
                    const SizedBox(width: 20),
                    Expanded(child: _buildFeatureCard(
                      Icons.security,
                      'Secure & Fast',
                      'JWT authentication with real-time WebSocket communication',
                    )),
                  ],
                )
              : Column(
                  children: [
                    _buildFeatureCard(
                      Icons.gps_fixed,
                      'Live GPS Tracking',
                      'Real-time ambulance location updates on interactive maps',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      Icons.notifications_active,
                      'Proximity Alerts',
                      'Instant notifications to nearby traffic police when ambulances approach',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      Icons.security,
                      'Secure & Fast',
                      'JWT authentication with real-time WebSocket communication',
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF007AFF)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2A3A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          color: Colors.black12,
        ),
        const SizedBox(height: 24),
        Text(
          '© ${DateTime.now().year} ATS - Ambulance Tracking System',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Saving lives through technology',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black38,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
