import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'core/network/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/sync/sync_engine.dart';
import 'data/local/hive_helper.dart';
import 'data/remote/supabase_service.dart';
import 'data/repositories/app_repository.dart';
import 'features/fingerprint/fingerprint_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for all platforms (Web, Windows, Linux, Mobile) safely
  if (kIsWeb) {
    try {
      databaseFactory = databaseFactoryFfiWeb;
    } catch (_) {}
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (_) {}
  }

  // Initialize Hive local database safely
  try {
    await HiveHelper.instance.init();
  } catch (e) {
    if (kDebugMode) print('Hive init notice: $e');
  }

  // Auto-connect to Supabase with hardcoded project keys safely
  try {
    await SupabaseService.instance.initDefault();
  } catch (e) {
    if (kDebugMode) print('Supabase init notice: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppRepository()),
        ChangeNotifierProvider(create: (_) => SyncEngine()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => FingerprintProvider()),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: const DawamiApp(),
    ),
  );
}
