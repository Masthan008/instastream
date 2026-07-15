import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glassmorphic_card.dart';
import 'main_layout_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  
  double _loadProgress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    
    // Main entrance animations controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Continuous pulse logo animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Shifting shimmer gradient progress indicator
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.linear,
      ),
    );

    _animationController.forward().then((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
    
    _shimmerController.repeat();
    _startProgressLoader();
    _navigateToHome();
  }

  void _startProgressLoader() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (mounted) {
        setState(() {
          if (_loadProgress < 1.0) {
            _loadProgress += 0.015;
          } else {
            _progressTimer?.cancel();
          }
        });
      }
    });
  }

  void _navigateToHome() {
    Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainLayoutScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulser Logo Glassmorphic Container
              AnimatedBuilder(
                animation: Listenable.merge([_animationController, _pulseController]),
                builder: (context, child) {
                  final scale = _scaleAnimation.value * _pulseAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: _animationController.value.clamp(0.0, 1.0),
                      child: GlassmorphicCard(
                        padding: const EdgeInsets.all(24),
                        radius: 36,
                        color: Colors.white.withValues(alpha: 0.45),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                LiquidGlassTheme.primaryBlue.withValues(alpha: 0.3),
                                LiquidGlassTheme.primaryGreen.withValues(alpha: 0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) {
                                return const Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 72,
                                  color: LiquidGlassTheme.primaryGreen,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Title Fade-in
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          'InstaStream',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Client-Side Media Extractor',
                          style: TextStyle(
                            color: LiquidGlassTheme.textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),

              // Animated Water-like Fluid Loading Indicator
              SizedBox(
                width: 180,
                child: Column(
                  children: [
                    Container(
                      height: 6,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                widthFactor: _loadProgress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      colors: const [
                                        LiquidGlassTheme.primaryGreen,
                                        LiquidGlassTheme.primaryBlue,
                                        LiquidGlassTheme.primaryGreen,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      transform: GradientRotation(_shimmerAnimation.value),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: LiquidGlassTheme.primaryGreen.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Initializing Core Engine... ${( _loadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: LiquidGlassTheme.textLight,
                      ),
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
