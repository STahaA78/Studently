import 'package:flutter/material.dart';
import 'package:studently/models/resource.dart';
import 'package:studently/repositories/resource.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:studently/logger.dart';

class PdfGalleryScreen extends StatefulWidget {
  final List<ResourceItem> resources;
  final int initialIndex;

  const PdfGalleryScreen({
    super.key,
    required this.resources,
    required this.initialIndex,
  });

  @override
  State<PdfGalleryScreen> createState() => _PdfGalleryScreenState();
}

class _PdfGalleryScreenState extends State<PdfGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex; // Track current page for the title
  late Map<String, String> _headers; // Get token once for all requests
  @override
  void initState() {
    super.initState();
    authService.value.getIdToken().then((token) {
      setState(() {
        _headers = {
          "Authorization": "Bearer $token",
        };
      });
    });
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Access the current item for the App Bar title
    final currentItem = widget.resources[_currentIndex];

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
        title: Text(
          "${currentItem.year} - ${currentItem.semester}",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8), // distance below AppBar
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
                child: SfPdfViewer.network(
                  ResourceRepository().getDownloadUrl(item.id),
                  // IMPORTANT: Key ensures the viewer resets correctly on swipe
                  key: ValueKey(item.id), 
                  headers: _headers,
                  onDocumentLoadFailed: (details) {
                    logger.e("Error: ${details.error} - ${details.description}");
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}