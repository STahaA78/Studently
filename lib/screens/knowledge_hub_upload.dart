import 'package:studently/app_style.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';

class AddResourcePage extends ConsumerStatefulWidget {
  final Course course;

  const AddResourcePage({super.key, required this.course});

  @override
  ConsumerState<AddResourcePage> createState() => _AddResourcePageState();
}

enum UploadStatus { compressing, success, failed }

class UploadImage {
  File file;
  UploadStatus status;
  List<int>? bytes; // Store bytes for web upload
  String? filename; // Store filename for web upload

  UploadImage({
    required this.file,
    this.status = UploadStatus.compressing,
    this.bytes,
    this.filename,
  });
}

class _AddResourcePageState extends ConsumerState<AddResourcePage> {
  final Color blue = AppStyle.primaryBlue;
  static const List<String> _semesterOrder = ['Spring', 'Summer', 'Fall'];

  // Uploaded File
  File? _selectedPdf;
  List<int>? _selectedPdfBytes;
  String? _selectedPdfFilename;
  List<UploadImage> _selectedImages = [];
  // Form Fields
  String? _selectedType;
  String? _selectedSemester;
  int? _selectedYear;
  bool _isSolved = false;
  // Mid Number Selection
  int? _selectedMidNumber;

  // Upload state
  bool _isUploading = false;

  @override
  void dispose() {
    super.dispose();
  }

  List<String> _semesterOptionsFromConfig(BackendConfig? config) {
    final options = <String>[];
    final seen = <String>{};

    void addSemester(String? value) {
      if (value == null) return;
      final normalized = value.trim();
      if (normalized.isEmpty) return;
      if (seen.add(normalized)) {
        options.add(normalized);
      }
    }

    addSemester(config?.currentTerm.term);
    for (final semester in _semesterOrder) {
      addSemester(semester);
    }

    return options;
  }

  List<int> _yearOptionsFromConfig(BackendConfig? config) {
    final now = DateTime.now().year;
    final start = config?.batchRange.start ?? (now - 6);
    final end = config?.batchRange.end ?? now;

    if (end < start) {
      return [now];
    }

    return List<int>.generate(end - start + 1, (i) => end - i);
  }

  // Compress Images before PDF conversion (to reduce file size)
  // Returns original file if compression fails (e.g., on web)
  Future<File> _compressImage(File file) async {
    logger.i("Image Compression Started for ${file.path}");
    try {
      final dir = await getTemporaryDirectory();

      String temporaryName = DateTime.now().millisecondsSinceEpoch.toString();

      final targetPath = '${dir.path}/$temporaryName.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        logger.e(
          "Image Compression Failed for ${file.path}, returning original",
        );
        return file;
      }

      logger.i("Image Compression Successful");
      return File(compressedFile.path);
    } catch (e) {
      // On web or if compression fails, return original file
      logger.w(
        "Image Compression Error (likely web platform): $e, using original file",
      );
      return file;
    }
  }

  // Upload File Logic (web-compatible using bytes)
  Future<void> _pickFiles() async {
    logger.i("Pick Files Started");
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null) return;

    // Use result.files which works on all platforms (web, mobile, desktop)
    final platformFiles = result.files;

    // Determine MIME type based on file extension
    final firstMime = lookupMimeType('dummy.${platformFiles.first.extension}');
    if (firstMime == null) return;

    final isPdf = firstMime == 'application/pdf';
    final isImage = firstMime.startsWith('image/');

    final hasMixed = platformFiles.any((platformFile) {
      final mime = lookupMimeType('dummy.${platformFile.extension}');
      if (isPdf) return mime != 'application/pdf';
      if (isImage) return mime == null || !mime.startsWith('image/');
      return true;
    });

    if (hasMixed) {
      logger.i("Pick Files Ended - Mixed File Types");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select either only PDF or only images")),
      );
      return;
    }

    if (isPdf) {
      // For PDF, create a File object from bytes for storage
      final file = File.fromRawPath(platformFiles.first.bytes ?? Uint8List(0));
      setState(() {
        _selectedPdf = file;
        _selectedImages.clear();
        // Store the bytes for later use
        _selectedPdfBytes = platformFiles.first.bytes;
        _selectedPdfFilename = platformFiles.first.name;
      });
      logger.i("Pick Files Ended - PDF");
    } else {
      // For images, handle compression only on native platforms
      setState(() {
        _selectedPdf = null;
        _selectedImages = platformFiles
            .map(
              (platformFile) => UploadImage(
                file: File.fromRawPath(platformFile.bytes ?? Uint8List(0)),
                status: UploadStatus.compressing,
                bytes: platformFile.bytes,
                filename: platformFile.name,
              ),
            )
            .toList();
      });
      logger.i("Pick Files - Compressing Images");
      for (int i = 0; i < _selectedImages.length; i++) {
        try {
          // Only compress on native platforms where file I/O is available
          if (platformFiles[i].bytes != null) {
            // Use bytes directly for web, but try compression for native
            final compressedFile = await _compressImage(
              _selectedImages[i].file,
            );

            if (!mounted) return;

            setState(() {
              _selectedImages[i] = UploadImage(
                file: compressedFile,
                status: UploadStatus.success,
                bytes: _selectedImages[i].bytes,
                filename: _selectedImages[i].filename,
              );
            });
          }
        } catch (e) {
          // If compression fails (web or other issues), keep original
          if (!mounted) return;

          setState(() {
            _selectedImages[i] = UploadImage(
              file: _selectedImages[i].file,
              status: UploadStatus.success,
              bytes: _selectedImages[i].bytes,
              filename: _selectedImages[i].filename,
            );
          });
        }
      }
      logger.i("Pick Files Ended - Images");
    }
  }

  // Convert selected images into a single PDF file and return it
  // On web, this will return a dummy file since we use bytes directly
  Future<File> _convertImagesToPdf() async {
    logger.i("Convert Images to PDF Started");
    try {
      final pdf = pw.Document();

      for (final imageFile in _selectedImages) {
        final imageBytes = await imageFile.file.readAsBytes();
        final pwImage = pw.MemoryImage(imageBytes);
        pdf.addPage(
          pw.Page(build: (context) => pw.Center(child: pw.Image(pwImage))),
        );
      }

      try {
        final dir = await getTemporaryDirectory();
        String temporaryName = DateTime.now().millisecondsSinceEpoch.toString();
        final file = File('${dir.path}/$temporaryName.pdf');
        await file.writeAsBytes(await pdf.save());

        logger.i("Convert Images to PDF Ended Successful");
        return file;
      } catch (e) {
        // On web, getTemporaryDirectory() fails - return dummy file
        // The actual bytes will be used from _selectedImages
        logger.w("PDF file creation skipped (web platform): $e");
        return File('memory.pdf');
      }
    } catch (e) {
      logger.e("Convert Images to PDF Failed: $e");
      throw Exception("Failed to process images for upload");
    }
  }

  Future<void> _fileUpload() async {
    logger.i("File Upload Started");
    if (_selectedPdf == null && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a file")));
      logger.i("File Upload Ended - No File Selected");
      return;
    }

    try {
      setState(() {
        _isUploading = true;
      });

      File fileToUpload;

      if (_selectedPdf != null) {
        fileToUpload = _selectedPdf!;
      } else {
        logger.i("File Upload - Converting Images to PDF");
        fileToUpload = await _convertImagesToPdf();
      }

      // Check file size - skip on web if using bytes
      if (!(_selectedImages.isNotEmpty &&
          _selectedImages.first.bytes != null)) {
        try {
          final fileSizeInMB = await fileToUpload.length() / (1024 * 1024);

          if (fileSizeInMB > 20) {
            logger.i("File Upload Ended - File Too Large");
            throw Exception("File too large (max 20MB)");
          }
        } catch (e) {
          if (e.toString().contains("File too large")) rethrow;
          logger.w("Could not check file size (web): $e");
          // Continue with upload anyway
        }
      }

      // Semester and year are required for everything except books
      if (_selectedType != "book") {
        if (_selectedSemester == null || _selectedSemester!.isEmpty) {
          logger.i("File Upload Ended - No Semester Selected");
          throw Exception("Please select a semester");
        }
        if (_selectedYear == null) {
          logger.i("File Upload Ended - No Year Selected");
          throw Exception("Please select a year");
        }
      }

      final resourceItemRequest = ResourceItemRequest(
        course: widget.course,
        type: _selectedType!,
        semester: _selectedSemester ?? 'Unknown',
        year: _selectedYear ?? 0,
        isSolved: _isSolved,
        midNumber: _selectedMidNumber,
      );

      // Use the provider to upload the resource
      final uploadFunction = ref.read(resourceUploadFunctionProvider);

      // Prefer bytes upload if available (web), fallback to file path (native)
      if (_selectedPdfBytes != null && _selectedPdfFilename != null) {
        await uploadFunction(
          resourceItemRequest: resourceItemRequest,
          fileBytes: _selectedPdfBytes,
          filename: _selectedPdfFilename,
        );
      } else if (_selectedImages.isNotEmpty &&
          _selectedImages.first.bytes != null) {
        // For images, use the first image's bytes
        final imageBytes = _selectedImages.first.bytes!;
        final imageFilename = _selectedImages.first.filename ?? 'image.jpg';
        await uploadFunction(
          resourceItemRequest: resourceItemRequest,
          fileBytes: imageBytes,
          filename: imageFilename,
        );
      } else {
        // Fallback to file path for native platforms
        await uploadFunction(
          resourceItemRequest: resourceItemRequest,
          filePath: fileToUpload.path,
        );
      }

      if (!context.mounted) return;

      logger.i("File Upload Ended - Upload Successful");

      // Refresh fresh resources to fetch from backend using the custom refresh provider
      try {
        final refresh = ref.read(
          refreshResourcesForCourseProvider(widget.course.code),
        );
        await refresh();
        logger.i("Resources refreshed after upload");
      } catch (e) {
        logger.e("Error refreshing resources after upload: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resource Uploaded Successfully")),
        );
      }

      // Close the screen and notify success
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
      logger.e("File Upload Error: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  bool get _canShowUpload {
    return _selectedType != null;
  }

  bool get _canSubmit {
    return (_selectedPdf != null || _selectedImages.isNotEmpty) &&
        _canShowUpload;
  }

  @override
  Widget build(BuildContext context) {
    final String courseDisplay =
        "${widget.course.code} - ${widget.course.name}";
    final isUploading = _isUploading;
    final configAsync = ref.watch(backendConfigProvider);
    final config = configAsync.asData?.value;
    final semesterOptions = _semesterOptionsFromConfig(config);
    final yearOptions = _yearOptionsFromConfig(config);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add Resource",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
        centerTitle: true,
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 40,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isUploading || !_canSubmit)
                  ? null
                  : () async {
                      await _fileUpload();
                    },
              child: isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Add Resource"),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Course
            const Text("Course", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              decoration: InputDecoration(hintText: courseDisplay),
            ),
            const SizedBox(height: 20),

            /// Resource Type
            const Text(
              "Resource Type",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              decoration: AppStyle.dropdownContainerDecoration(),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedType,
                items: const [
                  DropdownMenuItem(value: "Mid", child: Text("Midterm")),
                  DropdownMenuItem(value: "Final", child: Text("Final")),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                    _selectedMidNumber = null;
                  });
                },
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                ),
                borderRadius: BorderRadius.circular(20),
                menuMaxHeight: 220,
                decoration: AppStyle.dropdownInputDecoration(
                  hintText: "Select Resource Type",
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedType != null) ...[
              const Text(
                "Semester",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 50,
                decoration: AppStyle.dropdownContainerDecoration(),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSemester,
                  items: semesterOptions
                      .map(
                        (semester) => DropdownMenuItem<String>(
                          value: semester,
                          child: Text(semester),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSemester = value;
                    });
                  },
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  menuMaxHeight: 220,
                  decoration: AppStyle.dropdownInputDecoration(
                    hintText: "Select Semester",
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Year", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                height: 50,
                decoration: AppStyle.dropdownContainerDecoration(),
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  items: yearOptions
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                    });
                  },
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  menuMaxHeight: 220,
                  decoration: AppStyle.dropdownInputDecoration(
                    hintText: "Select Year",
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            /// Mid Number — shown for Mid exams
            if (_selectedType == "Mid") ...[
              const Text(
                "Mid Exam Number",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 50,
                decoration: AppStyle.dropdownContainerDecoration(),
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMidNumber,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Mid 1")),
                    DropdownMenuItem(value: 2, child: Text("Mid 2")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMidNumber = value;
                    });
                  },
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  menuMaxHeight: 220,
                  decoration: AppStyle.dropdownInputDecoration(
                    hintText: "Select Mid Number",
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Leave if this is a lab exam or mid number is unknown.",
                style: TextStyle(
                  color: AppStyle.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],

            /// Solved Toggle
            if (_selectedType != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Solved",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Checkbox(
                    value: _isSolved,
                    onChanged: (value) {
                      setState(() {
                        _isSolved = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            /// Upload Button — shown only when required fields are filled
            if (_canShowUpload) ...[
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _selectedPdf != null
                      ? "PDF Selected"
                      : _selectedImages.isNotEmpty
                      ? "${_selectedImages.length} image(s) selected"
                      : "Upload PDF or Images",
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
