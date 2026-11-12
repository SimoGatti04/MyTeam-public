import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'upload/upload_screen.dart';
import 'video/video_list_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/debug_log_overlay.dart';
import '../widgets/updater/update_banner_widget.dart';
import '../widgets/updater/startup_update_notice.dart';
import '../../core/services/updater/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const VideoListScreen(),
    const UploadScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              if (updateService.isQaChannel)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text(
                    'BUILD DI COLLAUDO · CANALE QA',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              // Banner aggiornamenti in testa allo schermo se disponibile/in download
              UpdateBannerWidget(updateService: updateService),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          StartupUpdateNotice(
            listenable: updateService,
            readState: () => updateService.state,
            checkForUpdates: updateService.checkForUpdates,
          ),
          // Debug log overlay
          const DebugLogOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Videos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
