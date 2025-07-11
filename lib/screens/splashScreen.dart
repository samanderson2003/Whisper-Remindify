import 'package:flutter/material.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isNavigating = false; // Prevent multiple taps

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Start animations
    _animationController.forward();
  }

  void _navigateToMainPage() {
    if (_isNavigating) return; // Prevent multiple taps

    setState(() {
      _isNavigating = true;
    });

    // Small delay for smoother transition
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigationPage(),
            transitionDuration: const Duration(
              milliseconds: 800,
            ), // Increased duration
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  // Smoother fade transition with slight scale
                  const begin = 0.0;
                  const end = 1.0;
                  const curve = Curves.easeInOutCubic; // Smoother curve

                  var fadeAnimation = Tween(
                    begin: begin,
                    end: end,
                  ).animate(CurvedAnimation(parent: animation, curve: curve));

                  var scaleAnimation = Tween(
                    begin: 0.95,
                    end: 1.0,
                  ).animate(CurvedAnimation(parent: animation, curve: curve));

                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(scale: scaleAnimation, child: child),
                  );
                },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Light background
      body: Stack(
        children: [
          // Centered image without background - slightly bigger
          Center(
            child: Container(
              width:
                  MediaQuery.of(context).size.width *
                  0.9, // Increased from 0.85 to 0.9
              height:
                  MediaQuery.of(context).size.width *
                  0.9, // Square aspect ratio
              child: Image.asset(
                'assets/image.png',
                fit: BoxFit.contain, // Better for transparent images
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image doesn't load
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                    ),
                    child: const Icon(Icons.mic, size: 80, color: Colors.white),
                  );
                },
              ),
            ),
          ),

          // Content overlay
          Column(
            children: [
              // Text content at the top
              Padding(
                padding: const EdgeInsets.only(top: 80, left: 20, right: 20),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            // App title with shadow for better visibility
                            Text(
                              'Speech to Text',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withOpacity(0.8),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Subtitle with shadow
                            Text(
                              'Convert your voice to text',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black.withOpacity(0.9),
                                fontWeight: FontWeight.w300,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withOpacity(0.8),
                                    offset: const Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Spacer to push content to proper positions
              const Spacer(),

              // Start Button centered and slightly higher
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 80,
                  ), // Moved up from 40 to 80
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: TextButton(
                            onPressed: _navigateToMainPage,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                            ),
                            child: Text(
                              'START',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.black,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withOpacity(0.9),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
