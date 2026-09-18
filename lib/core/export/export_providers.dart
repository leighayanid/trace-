import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'export_service.dart';
import 'import_service.dart';

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(databaseProvider)),
);

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(databaseProvider)),
);
