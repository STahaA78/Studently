import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:studently/logger.dart';

class _PdfSource {
  final File? file;
  final Uint8List? bytes;

  const _PdfSource.file(this.file) : bytes = null;
  const _PdfSource.bytes(this.bytes) : file = null;
}

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
    return FutureBuilder<_PdfSource>(
      future: _downloadAndSavePdf(
        ref,
        item,
        downloadUrl,
        widget.courseCode,
        localFilePath,
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

        // Success state - display downloaded PDF
        if (snapshot.hasData) {
          final pdfSource = snapshot.data!;
          if (pdfSource.file != null) {
            final pdfFile = pdfSource.file!;
            logger.i('Opening PDF from file: ${pdfFile.path}');
            return SfPdfViewer.file(
              pdfFile,
              key: ValueKey(item.id),
              onDocumentLoadFailed: (details) {
                logger.e("Error loading PDF: ${details.error} - ${details.description}");
              },
            );
          }

          if (pdfSource.bytes != null) {
            logger.i('Opening PDF from in-memory bytes for resource: ${item.id}');
            return SfPdfViewer.memory(
              pdfSource.bytes!,
              key: ValueKey('${item.id}-memory'),
              onDocumentLoadFailed: (details) {
                logger.e("Error loading PDF: ${details.error} - ${details.description}");
              },
            );
          }
        }

        return const Center(child: Text('No data'));
      },
    );
  }

  /// Download PDF from backend or Google Drive using Dio and save locally
  Future<_PdfSource> _downloadAndSavePdf(
    WidgetRef ref,
    ResourceItem item,
    String downloadUrl,
    String courseCode,
    String? localFilePath,
  ) async {
    try {
      final rawGdriveLink = item.gdriveLink?.trim();
      final hasGdriveLink = rawGdriveLink != null && rawGdriveLink.isNotEmpty;

      // Reuse previously persisted local path when possible.
      if (!kIsWeb && localFilePath != null && localFilePath.isNotEmpty) {
        final existingLocalFile = File(localFilePath);
        if (existingLocalFile.existsSync()) {
          logger.i('Using persisted local PDF path: $localFilePath');
          return _PdfSource.file(existingLocalFile);
        }
      }

      String actualDownloadUrl = downloadUrl;
      String? authToken;

      if (hasGdriveLink) {
        logger.i('Detected Google Drive resource: $rawGdriveLink');
        actualDownloadUrl = rawGdriveLink;

        final fileId = _extractGoogleDriveFileId(rawGdriveLink);
        if (fileId != null) {
          actualDownloadUrl = _buildGoogleDriveDownloadUrl(fileId);
          logger.i('Using normalized Google Drive direct download URL: $actualDownloadUrl');
        }
      } else {
        // For backend resources, add auth token
        authToken = await authService.value.getIdToken();
        if (authToken == null) {
          logger.e('No auth token found. User may not be logged in.');
          throw Exception('Authentication required. Please log in again.');
        }
      }

      final headers = <String, dynamic>{};
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final dio = Dio();

      // On web, stream bytes directly into SPDF memory viewer.
      if (kIsWeb) {
        logger.i('Downloading PDF from: $actualDownloadUrl (web)');

        final response = await dio.get<List<int>>(
          actualDownloadUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: headers,
            followRedirects: true,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );

        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Downloaded PDF is empty.');
        }

        return _PdfSource.bytes(Uint8List.fromList(bytes));
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
        final saveLocalPath =
            ref.read(saveResourceLocalPathProvider((courseCode, item.id)));
        await saveLocalPath(filePath);
        return _PdfSource.file(file);
      }

      // Download the file using Dio
      logger.i('Downloading PDF from: $actualDownloadUrl to $filePath');

      await dio.download(
        actualDownloadUrl,
        filePath,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            logger.i('Download progress: $progress%');
          }
        },
      );

      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('Downloaded PDF file is empty or missing.');
      }

      final saveLocalPath =
          ref.read(saveResourceLocalPathProvider((courseCode, item.id)));
      await saveLocalPath(filePath);

      logger.i('PDF downloaded and saved: $filePath');
      return _PdfSource.file(file);
    } catch (e) {
      logger.e('Error downloading PDF: $e');
      rethrow;
    }
  }

  String _buildGoogleDriveDownloadUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';
  }

  String? _extractGoogleDriveFileId(String? link) {
    if (link == null || link.trim().isEmpty) {
      return null;
    }

    final trimmedLink = link.trim();

    // Sometimes the stored value is already a file id.
    final idOnlyPattern = RegExp(r'^[a-zA-Z0-9_-]{20,}$');
    if (idOnlyPattern.hasMatch(trimmedLink)) {
      return trimmedLink;
    }

    final uri = Uri.tryParse(trimmedLink);
    if (uri == null) {
      return null;
    }

    final queryId = uri.queryParameters['id'];
    if (queryId != null && queryId.isNotEmpty) {
      return queryId;
    }

    final pathSegments = uri.pathSegments;
    final dIndex = pathSegments.indexOf('d');
    if (dIndex != -1 && dIndex + 1 < pathSegments.length) {
      return pathSegments[dIndex + 1];
    }

    final filePathMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(uri.path);
    if (filePathMatch != null) {
      return filePathMatch.group(1);
    }

    return null;
  }
}