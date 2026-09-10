import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The opening screen: a dark field, the wordmark, and a quiet promise.
///
/// Three staged motions, all settling rather than arriving: the background
/// eases out of a 1.08 scale, `T R A C E` tightens its tracking from 18 to 12 as
/// it fades up, and the tagline follows 200ms behind.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final Animation<double> _bgScale = Tween(begin: 1.08, end: 1.0).animate(
    CurvedAnimation(parent: _c, curve: const Interval(0, 0.85, curve: TraceMotion.standard)),
  );

  late final Animation<double> _tracking = Tween(begin: 18.0, end: 12.0).animate(
    CurvedAnimation(parent: _c, curve: const Interval(0.1, 0.7, curve: TraceMotion.enter)),
  );

  late final Animation<double> _markFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
  );

  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(TraceMotion.splashHold, () {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dark regardless of the device theme — the splash is a fixed image.
    const ink = Color(0xFF0B0D10);
    const white = Color(0xFFF5F5F2);
    const muted = Color(0xFF858991);

    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // TODO: swap for the mountain photograph once supplied.
          // assets/images/splash.jpg — declare it and replace this container.
          ScaleTransition(
            scale: _bgScale,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF10161F)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(TraceSpace.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _markFade,
                    child: AnimatedBuilder(
                      animation: _tracking,
                      builder: (context, _) => Text(
                        'TRACE',
                        style: TraceText.wordmark.copyWith(
                          color: white,
                          letterSpacing: _tracking.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: TraceSpace.md),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Build. Read. Explore. Live.',
                      style: TraceText.rowSubtitle.copyWith(color: muted),
                    ),
                  ),
                  const Spacer(flex: 4),
                  FadeTransition(
                    opacity: _footerFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 24, height: 1, color: muted),
                        const SizedBox(height: TraceSpace.md),
                        Text(
                          'A quiet record\nof what you do.',
                          style: TraceText.rowSubtitle.copyWith(
                            color: muted,
                            height: 1.5,
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
