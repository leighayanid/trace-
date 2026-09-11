import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';

/// The opening screen: a dark field, the wordmark, and a quiet promise.
///
/// Three staged motions, all settling rather than arriving: the background
/// eases out of a 1.08 scale, `T R A C E` tightens its tracking from 18 to 12 as
/// it fades up out of a blur, and the tagline follows 200ms behind.
///
/// Then it leaves as deliberately as it arrived: the type lifts away first,
/// the image dims into the ink field, and only then does the app take over —
/// so the hand-off is from one quiet dark frame, not a cut mid-composition.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: TraceMotion.splashExit,
  );

  /// Type leaves first and fast; the image dims under it a beat later.
  late final Animation<double> _typeOut = CurvedAnimation(
    parent: _exit,
    curve: const Interval(0, 0.7, curve: TraceMotion.emphasizedAccelerate),
  );

  late final Animation<double> _dim = CurvedAnimation(
    parent: _exit,
    curve: const Interval(0.2, 1, curve: Curves.easeIn),
  );

  late final Animation<double> _markBlur = Tween(begin: 8.0, end: 0.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0.1, 0.55, curve: Curves.easeOut),
    ),
  );

  late final Animation<double> _bgScale = Tween(begin: 1.08, end: 1.0).animate(
    CurvedAnimation(
        parent: _c,
        curve: const Interval(0, 0.85, curve: TraceMotion.standard)),
  );

  late final Animation<double> _tracking =
      Tween(begin: 18.0, end: 12.0).animate(
    CurvedAnimation(
        parent: _c, curve: const Interval(0.1, 0.7, curve: TraceMotion.enter)),
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
      if (status != AnimationStatus.completed) return;
      Future.delayed(TraceMotion.splashHold, () async {
        if (!mounted) return;
        await _exit.forward().orCancel.catchError((_) {});
        if (mounted) widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _exit.dispose();
    super.dispose();
  }

  /// Type lifting away on exit: up a few pixels and out.
  Widget _leaving(Widget child) {
    return AnimatedBuilder(
      animation: _typeOut,
      child: child,
      builder: (context, child) => Opacity(
        opacity: 1 - _typeOut.value,
        child: Transform.translate(
          offset: Offset(0, -14 * _typeOut.value),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dark regardless of the device theme — the splash is a fixed image.
    const ink = Color(0xFF0B0D10);
    const white = Color(0xFFF5F5F2);
    const muted = Color(0xFF858991);

    // Light system-bar icons regardless of the app theme, for the same reason.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ScaleTransition(
              scale: _bgScale,
              // Keeps drifting forward a touch as it dims, so the exit has
              // depth rather than just going dark.
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.04).animate(_dim),
                child: Image.asset(
                  'assets/images/splash.jpg',
                  fit: BoxFit.cover,
                  // The ink field shows through until the asset decodes, so
                  // the first frame is never a white flash.
                  errorBuilder: (_, _, _) => const ColoredBox(color: ink),
                ),
              ),
            ),
            // A legibility scrim, not decoration: dark where the type sits, clear
            // across the middle so the peak still reads. Without it the wordmark
            // would fall on snow and disappear.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xC20B0D10),
                    Color(0x4D0B0D10),
                    Color(0x8A0B0D10),
                    Color(0xEB0B0D10),
                  ],
                  stops: [0.0, 0.42, 0.74, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(TraceSpace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sits high, in the sky band. Lower and the wordmark lands on
                    // the snowfield, where white type has nothing to hold against.
                    const Spacer(flex: 2),
                    _leaving(
                      FadeTransition(
                        opacity: _markFade,
                        // Tracking tightens as the mark comes into focus —
                        // two motions that read as one lens settling.
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => ImageFiltered(
                            enabled: _markBlur.value > 0.01,
                            imageFilter: ImageFilter.blur(
                              sigmaX: _markBlur.value,
                              sigmaY: _markBlur.value,
                              tileMode: TileMode.decal,
                            ),
                            child: Text(
                              'TRACE',
                              style: TraceText.wordmark.copyWith(
                                color: white,
                                letterSpacing: _tracking.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: TraceSpace.md),
                    _leaving(
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'Build. Read. Explore. Live.',
                          style: TraceText.rowSubtitle.copyWith(color: muted),
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    _leaving(
                      FadeTransition(
                        opacity: _footerFade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The rule draws out rather than appearing.
                            SizeTransition(
                              sizeFactor: _footerFade,
                              axis: Axis.horizontal,
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                width: 24,
                                height: 1,
                                color: muted,
                              ),
                            ),
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
                    ),
                  ],
                ),
              ),
            ),
            // The exit: the whole composition dims into the ink field, which
            // is the frame the app fades up out of.
            IgnorePointer(
              child: FadeTransition(
                opacity: _dim,
                child: const ColoredBox(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
