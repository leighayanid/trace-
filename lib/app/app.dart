import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/theme.dart';

class TraceApp extends StatefulWidget {
  const TraceApp({super.key});

  @override
  State<TraceApp> createState() => _TraceAppState();
}

class _TraceAppState extends State<TraceApp> {
  // Built once. Recreating the router on rebuild would drop navigation state.
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TRACE',
      debugShowCheckedModeBanner: false,
      theme: TraceTheme.light(),
      darkTheme: TraceTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
