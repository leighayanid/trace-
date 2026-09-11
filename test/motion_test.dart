import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/theme/theme.dart';
import 'package:trace/shared/widgets/entrance_tween.dart';
import 'package:trace/shared/widgets/hero_text.dart';
import 'package:trace/shared/widgets/reveal.dart';
import 'package:trace/shared/widgets/trace_sheet.dart';

/// The guarantees the motion layer makes that a glance at the screen can't
/// check: entrances play once and never remount what they wrap, the reduced-
/// motion setting is honoured, and the shared sheet controller survives reuse.
void main() {
  Widget app(Widget home, {bool reduced = false}) => MaterialApp(
        theme: TraceTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: home,
      );

  /// Effective opacity from every fading ancestor, whichever widget does it.
  double opacityOf(WidgetTester tester, Finder finder) {
    final plain = tester
        .widgetList<Opacity>(
          find.ancestor(of: finder, matching: find.byType(Opacity)),
        )
        .fold(1.0, (v, o) => v * o.opacity);
    return tester
        .widgetList<FadeTransition>(
          find.ancestor(of: finder, matching: find.byType(FadeTransition)),
        )
        .fold(plain, (v, f) => v * f.opacity.value);
  }

  group('Reveal', () {
    testWidgets('cascades in once, and a rebuild neither replays nor remounts',
        (tester) async {
      final rebuild = ValueNotifier(0);
      await tester.pumpWidget(app(
        RevealScope(
          child: ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, n, _) => Column(
              children: [
                Text('rebuilt $n'),
                const _Counter(key: ValueKey('counter')).reveal(2),
              ],
            ),
          ),
        ),
      ));

      // Held at its cascade slot, then fully in. The hold is a timer, not a
      // frame, so settle alone would return before the entrance even starts.
      expect(opacityOf(tester, find.byType(_Counter)), 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, find.byType(_Counter)), 1);

      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);

      rebuild.value++;
      await tester.pump();
      expect(find.text('rebuilt 1'), findsOneWidget);
      // Same state (the count survived) and still fully visible.
      expect(find.text('taps 1'), findsOneWidget);
      expect(opacityOf(tester, find.byType(_Counter)), 1);
    });

    testWidgets('reduced motion shows content on the first frame',
        (tester) async {
      await tester.pumpWidget(app(
        RevealScope(child: const Text('here').reveal(5, focus: true)),
        reduced: true,
      ));
      expect(opacityOf(tester, find.text('here')), 1);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('content arriving after the cascade opens up from zero height',
        (tester) async {
      final show = ValueNotifier(false);
      await tester.pumpWidget(app(
        RevealScope(
          child: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (context, visible, _) => Column(
              children: [
                if (visible)
                  const SizedBox(height: 100, child: Text('new'))
                      .reveal(0, late: RevealLate.expand),
              ],
            ),
          ),
        ),
      ));

      // The window is measured in real time, so let real time pass.
      await tester.runAsync(
        () => Future<void>.delayed(
          TraceMotion.cascadeWindow + const Duration(milliseconds: 100),
        ),
      );

      show.value = true;
      await tester.pump();
      final start = tester.getSize(find.byType(Reveal)).height;
      await tester.pumpAndSettle();
      final end = tester.getSize(find.byType(Reveal)).height;

      expect(start, lessThan(5));
      expect(end, 100);
    });
  });

  group('EntranceTween', () {
    Widget tween(double end) => app(
          EntranceTween<double>(
            begin: 0,
            end: end,
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 400),
            curve: Curves.linear,
            builder: (context, v) => Text(v.toStringAsFixed(2)),
          ),
        );

    testWidgets('waits out its delay, then runs, then moves from where it is',
        (tester) async {
      await tester.pumpWidget(tween(1));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('0.00'), findsOneWidget, reason: 'still waiting');

      await tester.pumpAndSettle();
      expect(find.text('1.00'), findsOneWidget);

      // A later change has no delay and starts from the current value.
      await tester.pumpWidget(tween(0.5));
      await tester.pump(const Duration(milliseconds: 200));
      final mid = double.parse(
        tester.widget<Text>(find.byType(Text)).data!,
      );
      expect(mid, inExclusiveRange(0.5, 1.0));
      await tester.pumpAndSettle();
      expect(find.text('0.50'), findsOneWidget);
    });
  });

  group('page transitions', () {
    testWidgets('the page underneath keeps its state through a push and pop',
        (tester) async {
      await tester.pumpWidget(app(
        Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const _Counter(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('detail')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.tap(find.byType(_Counter));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      // Mid-transition both pages are present.
      await tester.pump(TraceMotion.page ~/ 2);
      expect(find.text('detail'), findsOneWidget);
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('taps 1'), findsOneWidget);
    });

    testWidgets('a title Hero re-sets its type between the two sizes',
        (tester) async {
      const small = TextStyle(fontSize: 17);
      const large = TextStyle(fontSize: 26);

      await tester.pumpWidget(app(
        Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Padding(
                      padding: EdgeInsets.only(top: 200),
                      child: HeroText('PDS Express', tag: 't', style: large),
                    ),
                  ),
                ),
              ),
              child: const HeroText('PDS Express', tag: 't', style: small),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('PDS Express'));
      await tester.pump();
      await tester.pump(TraceMotion.page ~/ 2);

      final sizes = tester
          .widgetList<Text>(find.text('PDS Express'))
          .map((t) => t.style!.fontSize!)
          .toList();
      expect(
        sizes.any((s) => s > small.fontSize! && s < large.fontSize!),
        isTrue,
        reason: 'the flying text is between the two sizes, not stretched',
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('showTraceSheet', () {
    testWidgets('a shared controller drives more than one sheet in turn',
        (tester) async {
      late AnimationController controller;

      await tester.pumpWidget(app(
        _ControllerHost(
          onReady: (c) => controller = c,
          builder: (context) => TextButton(
            onPressed: () => showTraceSheet<void>(
              context: context,
              controller: controller,
              builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
            ),
            child: const Text('open'),
          ),
        ),
      ));

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('sheet'), findsOneWidget);
        expect(controller.value, 1);

        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(find.text('sheet'), findsNothing);
        expect(controller.value, 0);
      }
      expect(tester.takeException(), isNull);
    });
  });
}

/// Counts its own taps, so a remount (which resets the count) is visible.
class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _taps++),
        child: Text('taps $_taps'),
      );
}

/// Owns an AnimationController the way TraceShell does.
class _ControllerHost extends StatefulWidget {
  const _ControllerHost({required this.onReady, required this.builder});

  final ValueChanged<AnimationController> onReady;
  final WidgetBuilder builder;

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: TraceMotion.sheet,
    reverseDuration: TraceMotion.sheetReverse,
  );

  @override
  void initState() {
    super.initState();
    widget.onReady(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Builder(builder: widget.builder));
}
