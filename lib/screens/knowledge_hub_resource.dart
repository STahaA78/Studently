import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:studently/logger.dart';

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
  final Set<String> _loadedResourceIds = {};

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 140,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _buildResourceLabel(currentItem),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: AppStyle.appBarTitleSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Page indicator
            Text(
              "${_currentIndex + 1} of $totalResources",
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
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
          return Column(
            children: [
              Expanded(
                child: _buildPdfViewer(context, ref, item),
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
  ) {
    final isLoaded = _loadedResourceIds.contains(item.id);

    // Otherwise, stream from Cloudflare R2 URL
    if (item.fileUrl.isNotEmpty) {
      logger.i('Streaming PDF from Cloudflare R2: ${item.fileUrl}');
      return Stack(
        children: [
          Container(color: Colors.white),
          SfPdfViewer.network(
            item.fileUrl,
            key: ValueKey(item.id),
            onDocumentLoaded: (_) {
              if (mounted && !_loadedResourceIds.contains(item.id)) {
                setState(() => _loadedResourceIds.add(item.id));
              }
            },
            onDocumentLoadFailed: (details) {
              logger.e(
                "Error loading network PDF: ${details.error} - ${details.description}",
              );
            },
          ),
          if (!isLoaded)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      );
    }

    return const Center(child: Text('No file URL available'));
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
