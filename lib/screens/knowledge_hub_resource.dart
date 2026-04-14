import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';
import 'package:studently/storage/knowledge_hub.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:studently/logger.dart';
import 'dart:typed_data';

class PdfGalleryScreen extends ConsumerStatefulWidget {
  final List<ResourceItem> resources;
  final int initialIndex;
  final String courseCode;

  const PdfGalleryScreen({
    super.key,
    required this.resources,
    required this.initialIndex,
    required this.courseCode,
  });

  @override
  ConsumerState<PdfGalleryScreen> createState() => _PdfGalleryScreenState();
}

class _PdfGalleryScreenState extends ConsumerState<PdfGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex; // Track current page for the title

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Access the current item for the App Bar title
    final currentItem = widget.resources[_currentIndex];
    final totalResources = widget.resources.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              "${currentItem.year} - ${currentItem.semester}",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            Text(
              "${_currentIndex + 1} of $totalResources",
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: SizedBox(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.resources.length,
        // UPDATE STATE ON SWIPE
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.resources[index];
          final downloadUrl = ref.watch(resourceDownloadUrlProvider(item.id));
          final localFilePath =
              ref.watch(resourceLocalFilePathProvider((widget.courseCode, item.id)));

          return Column(
            children: [
              Expanded(
                child: _buildPdfViewer(
                  context,
                  ref,
                  item,
                  downloadUrl,
                  localFilePath,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build PDF viewer with support for local cached files
  Widget _buildPdfViewer(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
    String downloadUrl,
    String? localFilePath,
  ) {
    // If local file exists and is accessible, use it
    if (localFilePath != null && localFilePath.isNotEmpty) {
      final file = File(localFilePath);
      if (file.existsSync()) {
        logger.i('Using cached local file: $localFilePath');
        return SfPdfViewer.file(
          file,
          key: ValueKey(item.id),
          onDocumentLoadFailed: (details) {
            logger.e("Error loading local file: ${details.error} - ${details.description}");
          },
        );
      }
    }

    // Otherwise, download from network and optionally cache it
    return FutureBuilder<Uint8List>(
      future: _downloadAndCacheFile(context, ref, item),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: const CircularProgressIndicator(),
            );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (snapshot.hasData) {
          return SfPdfViewer.memory(
            snapshot.data!,
            key: ValueKey(item.id),
            onDocumentLoadFailed: (details) {
              logger.e("Error: ${details.error} - ${details.description}");
            },
          );
        }

        return const Center(child: Text('No data'));
      },
    );
  }

  /// Download file and cache it locally
  Future<Uint8List> _downloadAndCacheFile(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
  ) async {
    try {
      final fileBytes = await ref.read(
        downloadResourceFileProvider(item.id).future,
      );

      // Save to local storage asynchronously
      _savePdfLocally(ref, item, fileBytes);

      return fileBytes;
    } catch (e) {
      logger.e('Error downloading file: $e');
      rethrow;
    }
  }

  /// Save PDF file locally and update resource path
  void _savePdfLocally(
    WidgetRef ref,
    ResourceItem item,
    Uint8List fileBytes,
  ) async {
    try {
      final storage = KnowledgeHubStorage();
      final cacheDir = await storage.getDownloadsCacheDir();
      
      // Create file path
      final fileName = '${item.id}.pdf';
      final filePath = '$cacheDir/$fileName';
      final file = File(filePath);

      // Save file
      await file.writeAsBytes(fileBytes);
      logger.i('File saved locally: $filePath');

      // Update resource with local path in storage
      await storage.updateResourceWithLocalPath(
        widget.courseCode,
        item.id,
        filePath,
      );
      logger.i('Resource updated with local path');
      
      // Refresh provider to reflect new local path
      ref.invalidate(saveResourceLocalPathProvider);
    } catch (e) {
      logger.e('Error saving PDF locally: $e');
      // Don't rethrow - the file was already downloaded, just local caching failed
    }
  }
}