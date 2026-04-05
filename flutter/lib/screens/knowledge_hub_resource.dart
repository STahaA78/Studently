import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';
import 'package:studently/services/firebase_auth.dart';
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

  /// Build PDF viewer - downloads and caches PDFs locally
  Widget _buildPdfViewer(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
    String downloadUrl,
    String? localFilePath,
  ) {
    // For web with Google Drive resources, open in Google Drive viewer
    if (kIsWeb && item.gdriveLink != null && item.gdriveLink!.isNotEmpty) {
      final fileIdMatch = RegExp(r'[?&]id=([a-zA-Z0-9-_]+)').firstMatch(item.gdriveLink!);
      if (fileIdMatch != null) {
        final fileId = fileIdMatch.group(1);
        final viewerUrl = 'https://drive.google.com/file/d/$fileId/preview';
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_present, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Google Drive PDF',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Open in Google Drive viewer',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Launch URL in new tab
                  final uri = Uri.parse(viewerUrl);
                  launchUrl(uri, webOnlyWindowName: '_blank');
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF in Browser'),
              ),
            ],
          ),
        );
      }
    }

    // For mobile and backend resources, download locally
    return FutureBuilder<File>(
      future: _downloadAndSavePdf(
        context,
        ref,
        item,
        downloadUrl,
        widget.courseCode,
      ),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Downloading PDF...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          logger.e('Error downloading PDF: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading PDF',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Success state - display PDF from local file
        if (snapshot.hasData) {
          final pdfFile = snapshot.data!;
          logger.i('Opening PDF from: ${pdfFile.path}');
          return SfPdfViewer.file(
            pdfFile,
            key: ValueKey(item.id),
            onDocumentLoadFailed: (details) {
              logger.e("Error loading PDF: ${details.error} - ${details.description}");
            },
          );
        }

        return const Center(child: Text('No data'));
      },
    );
  }

  /// Download PDF from backend or Google Drive using Dio and save locally
  Future<File> _downloadAndSavePdf(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
    String downloadUrl,
    String courseCode,
  ) async {
    try {
      // Check if this is a Google Drive resource
      String actualDownloadUrl = downloadUrl;
      
      if (item.gdriveLink != null && item.gdriveLink!.isNotEmpty) {
        logger.i('Detected Google Drive resource: ${item.gdriveLink}');
        
        // Extract file ID and use direct Google Drive download URL
        final fileIdMatch = RegExp(r'[?&]id=([a-zA-Z0-9-_]+)').firstMatch(item.gdriveLink!);
        if (fileIdMatch != null) {
          final fileId = fileIdMatch.group(1);
          // Use direct download URL (doesn't require auth)
          actualDownloadUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
          logger.i('Using Google Drive direct download URL: $actualDownloadUrl');
        }
      } else {
        // For backend resources, add auth token
        final token = await authService.value.getIdToken();
        if (token == null) {
          logger.e('No auth token found. User may not be logged in.');
          throw Exception('Authentication required. Please log in again.');
        }
      }

      // On web, we can't use path_provider, so handle it differently
      if (kIsWeb) {
        logger.i('Downloading PDF from: $actualDownloadUrl (web)');
        final dio = Dio();
        
        final response = await dio.get<List<int>>(
          actualDownloadUrl,
          options: Options(
            responseType: ResponseType.bytes,
          ),
        );
        
        // Create a temporary File object (won't actually persist on web)
        final dir = Directory.systemTemp;
        final fileName = '${item.id}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.data!);
        logger.i('PDF downloaded (web temp): ${file.path}');
        return file;
      }

      // On mobile, use path_provider to save locally
      final appDocDir = await getApplicationDocumentsDirectory();
      final pdfDirectory = Directory('${appDocDir.path}/pdfs/$courseCode');

      // Create directory if it doesn't exist
      if (!pdfDirectory.existsSync()) {
        pdfDirectory.createSync(recursive: true);
      }

      // Use resource ID as filename to ensure uniqueness per resource
      final fileName = '${item.id}.pdf';
      final filePath = '${pdfDirectory.path}/$fileName';
      final file = File(filePath);

      // Check if file already exists
      if (file.existsSync()) {
        logger.i('PDF already cached locally: $filePath');
        return file;
      }

      // Download the file using Dio
      logger.i('Downloading PDF from: $actualDownloadUrl to $filePath');
      final dio = Dio();

      await dio.download(
        actualDownloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            logger.i('Download progress: $progress%');
          }
        },
      );

      logger.i('PDF downloaded and saved: $filePath');
      return file;
    } catch (e) {
      logger.e('Error downloading PDF: $e');
      rethrow;
    }
  }
}