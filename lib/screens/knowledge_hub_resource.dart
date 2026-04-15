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
        toolbarHeight: 140,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Course name and code
            Text(
              "${currentItem.course.name} (${currentItem.course.code})",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            // Type, Year, Semester, Mid number and Status (if applicable)
            Text(
              _buildResourceLabel(currentItem),
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Page indicator
            Text(
              "${_currentIndex + 1} of $totalResources",
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.black87),
            onPressed: () => _downloadAndCacheFile(context, ref, currentItem),
          ),
        ],
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
          final localFilePath =
              ref.watch(resourceLocalFilePathProvider((widget.courseCode, item.id)));

          return Column(
            children: [
              Expanded(
                child: _buildPdfViewer(
                  context,
                  ref,
                  item,
                  localFilePath,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build PDF viewer with support for local cached files and network streaming
  Widget _buildPdfViewer(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
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

    // Otherwise, stream from Cloudflare R2 URL
    if (item.fileUrl.isNotEmpty) {
      logger.i('Streaming PDF from Cloudflare R2: ${item.fileUrl}');
      return SfPdfViewer.network(
        item.fileUrl,
        key: ValueKey(item.id),
        onDocumentLoadFailed: (details) {
          logger.e("Error loading network PDF: ${details.error} - ${details.description}");
        },
      );
    }

    return const Center(child: Text('No file URL available'));
  }

  /// Download file from Cloudflare R2 and cache it locally
  void _downloadAndCacheFile(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
  ) async {
    try {
      if (item.fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file URL available')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading file...')),
      );

      // Download from Cloudflare URL
      final fileBytes = await ref.read(
        downloadResourceFromUrlProvider(item.fileUrl).future,
      );

      // Save to local storage
      await _savePdfLocally(ref, item, fileBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File downloaded and cached successfully')),
        );
      }
    } catch (e) {
      logger.e('Error downloading file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading file: $e')),
        );
      }
    }
  }

  /// Save PDF file locally and update resource path
  Future<void> _savePdfLocally(
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

  /// Build a descriptive label for the resource (Type, Year, Semester, Mid number, Status)
  String _buildResourceLabel(ResourceItem item) {
    final parts = <String>[];
    
    // Add type (Mid/Final)
    parts.add(item.type);
    
    // Add year if not 0 (misc)
    if (item.year != 0) {
      parts.add('${item.year}');
    }
    
    // Add semester if not 'Unknown'
    if (item.semester != 'Unknown') {
      parts.add(item.semester);
    }
    
    // Add mid number if available
    if (item.midNumber != null && item.midNumber! > 0) {
      parts.add('Mid ${item.midNumber}');
    }
    
    // Add status
    parts.add(item.isSolved == true ? 'Solved' : 'Unsolved');
    
    return parts.join(' • ');
  }
}