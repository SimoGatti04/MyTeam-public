import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/video.dart';
import '../../../features/video/viewmodels/video_list_viewmodel.dart';
import '../../widgets/video_list_item.dart';
import '../../widgets/video_filters_section.dart';
import 'video_detail_screen.dart';

/// Video list screen - Presentation layer
class VideoListScreen extends StatefulWidget {
  const VideoListScreen({super.key});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  
  @override
  void initState() {
    super.initState();
    // Load videos on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<VideoListViewModel>();
      // Ripristina il testo della ricerca se presente
      if (viewModel.searchQuery != null) {
        _searchController.text = viewModel.searchQuery!;
      }
      viewModel.loadVideos(refresh: true);
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
          ),
        ],
      ),
      body: Consumer<VideoListViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.videos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (viewModel.error != null && viewModel.videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Errore: ${viewModel.error}'),
                  ElevatedButton(
                    onPressed: () => viewModel.refresh(),
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => viewModel.refresh(),
            child: Column(
              children: [
                _buildSearchBar(context, viewModel),
                _buildFiltersSection(context, viewModel),
                Expanded(
                  child: ListView.builder(
                    itemCount: viewModel.videos.length + (viewModel.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == viewModel.videos.length) {
                        // Load more
                        viewModel.loadVideos();
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      return VideoListItem(
                        video: viewModel.videos[index],
                        onTap: () => _navigateToVideoDetail(context, viewModel.videos[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSearchBar(BuildContext context, VideoListViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Cerca video, giocatori, esercizi, anni...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (query) {
          // Cancella il timer precedente
          _searchDebounce?.cancel();
          
          // Crea un nuovo timer per debounce
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              viewModel.search(query);
            }
          });
        },
      ),
    );
  }
  
  void _showSortDialog(BuildContext context) {
    final viewModel = context.read<VideoListViewModel>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordina per'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Data (più recente)'),
              value: 'date_desc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Data (più vecchio)'),
              value: 'date_asc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Nome (A-Z)'),
              value: 'name_asc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Nome (Z-A)'),
              value: 'name_desc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Data Registrazione (più recente)'),
              value: 'recorded_at_desc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Data Registrazione (più vecchia)'),
              value: 'recorded_at_asc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Dimensione (crescente)'),
              value: 'size_asc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Dimensione (decrescente)'),
              value: 'size_desc',
              groupValue: viewModel.sortOption,
              onChanged: (value) {
                if (value != null) {
                  viewModel.setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFiltersSection(BuildContext context, VideoListViewModel viewModel) {
    return const VideoFiltersSection();
  }
  
  void _navigateToVideoDetail(BuildContext context, Video video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoDetailScreen(videoId: video.id),
      ),
    );
  }
}
