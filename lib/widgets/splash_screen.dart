import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import for SVG support
import 'dart:ui'; // Import for BackdropFilter
import 'package:subtitle_studio/utils/app_info.dart'; // Add this import

class SvgSplashScreen extends StatefulWidget {
  const SvgSplashScreen({super.key, this.onBackgroundReady});

  /// Called after the background has rendered, or if loading fails.
  final VoidCallback? onBackgroundReady;

  @override
  State<SvgSplashScreen> createState() => _SvgSplashScreenState();
}

class _SvgSplashScreenState extends State<SvgSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  double _opacity = 0.0;
  bool _backgroundReadyNotified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Faster animation
    )..repeat();

    // Start fade-in animation immediately without waiting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });
  }

  void _notifyBackgroundReady() {
    if (_backgroundReadyNotified) return;
    _backgroundReadyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBackgroundReady?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedContainer(
      double startInterval, double endInterval, double width) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isActive =
            _controller.value >= startInterval && _controller.value < endInterval;
        return Container(
          height: 5,
          width: width,
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant, // Use const colors
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height > screenSize.width;

    // Remove FutureBuilder - show content immediately
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The bundled WebP is already display-sized. Decode it once and
          // notify the route after the first frame has actually been painted.
          Positioned.fill(
            child: Image.asset(
              'assets/msone_bg.webp',
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  _notifyBackgroundReady();
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                // Do not hold startup indefinitely when an asset is invalid.
                debugPrint(
                  'Splash background unavailable: ${error.runtimeType}',
                );
                _notifyBackgroundReady();
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          // Main splash screen content - appears immediately
          SafeArea(
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 500), // Faster fade-in
              curve: Curves.easeOut, // Smooth easing
              child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top spacer
                        SizedBox(height: screenSize.height * 0.1),
                        
                        // Main content
                        Column(
                          children: [
                            RepaintBoundary( // Isolate SVG repaints
                              child: SvgPicture.asset(
                                'assets/msone.svg',
                                width: isPortrait 
                                    ? screenSize.width * 0.2
                                    : screenSize.height * 0.2,
                                placeholderBuilder: (BuildContext context) => SizedBox(
                                  width: isPortrait 
                                      ? screenSize.width * 0.2
                                      : screenSize.height * 0.2,
                                  height: isPortrait 
                                      ? screenSize.width * 0.2
                                      : screenSize.height * 0.2,
                                ),
                              ),
                            ),
                            SizedBox(height: screenSize.height * 0.01),
                            RepaintBoundary( // Isolate animation repaints
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAnimatedContainer(0.0, 0.2, screenSize.width * 0.08),
                                  SizedBox(width: screenSize.width * 0.015),
                                  _buildAnimatedContainer(0.2, 0.4, screenSize.width * 0.05),
                                  SizedBox(width: screenSize.width * 0.015),
                                  _buildAnimatedContainer(0.4, 0.6, screenSize.width * 0.09),
                                ],
                              ),
                            ),
                            SizedBox(height: screenSize.height * 0.01),
                            RepaintBoundary( // Isolate animation repaints
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAnimatedContainer(0.6, 0.8, screenSize.width * 0.09),
                                  SizedBox(width: screenSize.width * 0.015),
                                  _buildAnimatedContainer(0.8, 1.0, screenSize.width * 0.08),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Bottom text section
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: screenSize.height * 0.05,
                            left: 20,
                            right: 20,
                          ),
                          child: Column(
                            children: [
                              // Text group with aligned right edges
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Main title
                                  Text(
                                    'Subtitle Studio',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: GoogleFonts.prompt().fontFamily,
                                      fontSize: isPortrait
                                          ? screenSize.width * 0.06
                                          : screenSize.height * 0.06,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // "by Msone" tag aligned to the right edge of the title
                                  Text(
                                    'by Msone',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontFamily: GoogleFonts.josefinSans().fontFamily,
                                      fontSize: isPortrait
                                          ? screenSize.width * 0.04
                                          : screenSize.height * 0.04,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: screenSize.height * 0.01),
                              Text(
                                'Version ${AppInfo.versionWithBuild}',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontFamily: GoogleFonts.josefinSans().fontFamily,
                                  fontSize: isPortrait
                                      ? screenSize.width * 0.04
                                      : screenSize.height * 0.04,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}

