import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/database/database_service.dart';
import 'core/services/clipboard_monitor_service.dart';
import 'core/services/ghost_layer_service.dart';
import 'core/services/platform_channel_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/teleport_service.dart';
import 'core/services/ocr_service.dart';
import 'core/services/classifier_service.dart';
import 'core/services/clean_room_service.dart';
import 'core/services/chunk_engine_service.dart';

import 'data/repositories/clip_repository.dart';
import 'data/repositories/settings_repository.dart';

import 'features/clipboard/bloc/clipboard_bloc.dart';
import 'features/stack_mode/bloc/stack_bloc.dart';
import 'features/scratchpad/bloc/scratchpad_bloc.dart';
import 'features/ghost_layer/bloc/ghost_bloc.dart';
import 'features/teleport/bloc/teleport_bloc.dart';
import 'features/chunking/bloc/chunk_bloc.dart';
import 'features/search/bloc/search_bloc.dart';
import 'features/settings/bloc/settings_bloc.dart';

import 'shared/theme/app_theme.dart';
import 'features/clipboard/widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows: initialise sqflite FFI before any DB access
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Boot core services (order matters)
  final db = DatabaseService();
  await db.init();

  final settingsRepo = SettingsRepository(db: db);
  await settingsRepo.load();

  final settingsService = SettingsService(settingsRepo);
  final classifierService = ClassifierService();
  final ocrService = OcrService();
  final cleanRoomService = CleanRoomService();
  final chunkEngineService = ChunkEngineService(settings: settingsService);
  final clipRepo = ClipRepository(db: db);
  final ghostService = GhostLayerService(clipRepo: clipRepo);
  final teleportService = TeleportService(settings: settingsService);
  final clipMonitor = ClipboardMonitorService(
    clipRepo: clipRepo,
    classifier: classifierService,
    ocr: ocrService,
    cleanRoom: cleanRoomService,
    ghost: ghostService,
    settings: settingsService,
  );

  await clipMonitor.startMonitoring();
  await ghostService.startTimers();
  await teleportService.init();

  runApp(ClipSyncNexusApp(
    db: db,
    clipRepo: clipRepo,
    settingsRepo: settingsRepo,
    settingsService: settingsService,
    classifierService: classifierService,
    ocrService: ocrService,
    cleanRoomService: cleanRoomService,
    chunkEngineService: chunkEngineService,
    ghostService: ghostService,
    teleportService: teleportService,
    clipMonitor: clipMonitor,
  ));
}

class ClipSyncNexusApp extends StatelessWidget {
  final DatabaseService db;
  final ClipRepository clipRepo;
  final SettingsRepository settingsRepo;
  final SettingsService settingsService;
  final ClassifierService classifierService;
  final OcrService ocrService;
  final CleanRoomService cleanRoomService;
  final ChunkEngineService chunkEngineService;
  final GhostLayerService ghostService;
  final TeleportService teleportService;
  final ClipboardMonitorService clipMonitor;

  const ClipSyncNexusApp({
    super.key,
    required this.db,
    required this.clipRepo,
    required this.settingsRepo,
    required this.settingsService,
    required this.classifierService,
    required this.ocrService,
    required this.cleanRoomService,
    required this.chunkEngineService,
    required this.ghostService,
    required this.teleportService,
    required this.clipMonitor,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: db),
        RepositoryProvider.value(value: clipRepo),
        RepositoryProvider.value(value: settingsRepo),
        RepositoryProvider.value(value: settingsService),
        RepositoryProvider.value(value: classifierService),
        RepositoryProvider.value(value: ocrService),
        RepositoryProvider.value(value: cleanRoomService),
        RepositoryProvider.value(value: chunkEngineService),
        RepositoryProvider.value(value: ghostService),
        RepositoryProvider.value(value: teleportService),
        RepositoryProvider.value(value: clipMonitor),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (ctx) => ClipboardBloc(
              clipRepo: ctx.read<ClipRepository>(),
              ghostService: ctx.read<GhostLayerService>(),
              cleanRoomService: ctx.read<CleanRoomService>(),
              monitor: ctx.read<ClipboardMonitorService>(),
            )..add(const ClipboardStartMonitoring()),
          ),
          BlocProvider(
            create: (ctx) => StackBloc(
              clipRepo: ctx.read<ClipRepository>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => ScratchpadBloc(),
          ),
          BlocProvider(
            create: (ctx) => GhostBloc(
              ghostService: ctx.read<GhostLayerService>(),
              clipRepo: ctx.read<ClipRepository>(),
            )..add(const GhostStartWatching()),
          ),
          BlocProvider(
            create: (ctx) => TeleportBloc(
              teleportService: ctx.read<TeleportService>(),
            )..add(const TeleportInit()),
          ),
          BlocProvider(
            create: (ctx) => ChunkBloc(
              engine: ctx.read<ChunkEngineService>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => SearchBloc(
              clipRepo: ctx.read<ClipRepository>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => SettingsBloc(
              settingsRepo: ctx.read<SettingsRepository>(),
              settingsService: ctx.read<SettingsService>(),
            )..add(const SettingsLoad()),
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
          builder: (context, settingsState) {
            return MaterialApp(
              title: 'ClipSync Nexus',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settingsState.themeMode,
              home: const MainShell(),
            );
          },
        ),
      ),
    );
  }
}
