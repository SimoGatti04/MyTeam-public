import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'data/datasources/remote/video_remote_datasource.dart';
import 'data/repositories/video_repository_impl.dart';
import 'data/datasources/remote/upload_remote_datasource.dart';
import 'data/datasources/local/upload_local_datasource.dart';
import 'data/repositories/upload_repository_impl.dart';
import 'domain/usecases/get_videos_usecase.dart';
import 'domain/usecases/upload_video_usecase.dart';
import 'features/video/viewmodels/video_list_viewmodel.dart';
import 'features/upload/viewmodels/upload_viewmodel.dart';
import 'presentation/screens/home_screen.dart';
import 'core/services/settings_service.dart';
import 'core/services/debug_logger.dart';
import 'core/services/updater/update_service.dart';
import 'core/services/updater/active_tasks_guard.dart';

/// Inizializza i servizi dell'app
Future<void> _initializeServices() async {
  await SettingsService.initialize();
  DebugLogger.info('Services initialized');
}

void main() {
  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    final errorMsg = 'Flutter Error: ${details.exception}';
    final stackMsg = 'Stack: ${details.stack}';
    DebugLogger.error(errorMsg);
    DebugLogger.debug(stackMsg);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final errorMsg = 'Uncaught Error: $error';
    final stackMsg = 'Stack: $stack';
    DebugLogger.error(errorMsg);
    DebugLogger.debug(stackMsg);
    return true;
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _initializeServices();
      runApp(const MyTeamVideoApp());
    },
    (error, stack) async {
      DebugLogger.error('Zone Error: $error');
      DebugLogger.debug('Stack: $stack');
    },
  );
}

class MyTeamVideoApp extends StatelessWidget {
  const MyTeamVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inizializzazione delle dipendenze centrali
    final apiClient = ApiClient();
    final videoRemoteDataSource = VideoRemoteDataSource(apiClient);
    final videoRepository = VideoRepositoryImpl(videoRemoteDataSource);
    final getVideosUseCase = GetVideosUseCase(videoRepository);
    final videoListViewModel = VideoListViewModel(getVideosUseCase);

    final uploadRemoteDataSource = UploadRemoteDataSource(apiClient);
    final uploadLocalDataSource = UploadLocalDataSource();
    final uploadRepository = UploadRepositoryImpl(uploadRemoteDataSource, uploadLocalDataSource);
    final uploadUseCase = UploadVideoUseCase(uploadRepository);
    final uploadViewModel = UploadViewModel(uploadUseCase);
    // Avvia immediatamente il caricamento asincrono dei task persistiti
    uploadViewModel.loadSavedUploadTasks();

    // Collega la guardia dell'UpdateService all'unica istanza autorevole di UploadViewModel
    final updateService = UpdateService.instance;
    updateService.setGuard(ActiveTasksGuard(uploadViewModel: uploadViewModel));

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: videoListViewModel),
        ChangeNotifierProvider.value(value: uploadViewModel),
        ChangeNotifierProvider.value(value: SettingsService.instance),
        ChangeNotifierProvider.value(value: updateService),
      ],
      child: MaterialApp(
        title: 'MyTeam Video',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
