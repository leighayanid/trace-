import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// The one database instance for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
