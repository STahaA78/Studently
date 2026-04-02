import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/knowledge_hub.dart';
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

  UploadImage({
    required this.file,
    this.status = UploadStatus.compressing,
  });
}


class _AddResourcePageState extends ConsumerState<AddResourcePage> {
  final Color blue = const Color(0xFF1976D2);

  // Uploaded File
  File? _selectedPdf;
  List<UploadImage> _selectedImages = [];
  // Form Fields
  String? _selectedType;
  String? _selectedSemester;
  int? _selectedYear;
  bool _isSolved = false;
  // Text Controllers for Form Fields
  final TextEditingController _quizNumberController = TextEditingController();
  final TextEditingController _instructorController = TextEditingController();
  
  // Upload state
  bool _isUploading = false;

  @override
  void dispose() {
    _quizNumberController.dispose();
    _instructorController.dispose();
    super.dispose();
  }

  // Compress Images before PDF conversion (to reduce file size)
  Future<File> _compressImage(File file) async {
    logger.i("Image Compression Started for ${file.path}");
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
      logger.e("Image Compression Failed for ${file.path}");
      throw Exception("Image compression failed for ${file.path}");
    }

    logger.i("Image Compression Successful");
    return File(compressedFile.path);
  }

  // Upload File Logic
  Future<void> _pickFiles() async {
    logger.i("Pick Files Started");
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null) return;

    final files = result.paths.map((path) => File(path!)).toList();

    final firstMime = lookupMimeType(files.first.path);
    if (firstMime == null) return;

    final isPdf = firstMime == 'application/pdf';
    final isImage = firstMime.startsWith('image/');

    final hasMixed = files.any((file) {
      final mime = lookupMimeType(file.path);
      if (isPdf) return mime != 'application/pdf';
      if (isImage) return mime == null || !mime.startsWith('image/');
      return true;
    });

    if (hasMixed) {
      logger.i("Pick Files Ended - Mixed File Types");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select either only PDF or only images"),
        ),
      );
      return;
    }

    if (isPdf) {
      setState(() {
        _selectedPdf = files.first;
        _selectedImages.clear();
      });
      logger.i("Pick Files Ended - PDF");
    } else {
      setState(() {
        _selectedPdf = null;
        _selectedImages = files
            .map((file) => UploadImage(file: file, status: UploadStatus.compressing))
            .toList();
      });
      logger.i("Pick Files - Compressing Images");
      for (int i = 0; i < _selectedImages.length; i++) {
        try {
          final compressedFile = await _compressImage(_selectedImages[i].file);

          if (!mounted) return;

          setState(() {
            _selectedImages[i] = UploadImage(
              file: compressedFile,
              status: UploadStatus.success,
            );
          });
        } catch (e) {
          if (!mounted) return;

          setState(() {
            _selectedImages[i] = UploadImage(
              file: _selectedImages[i].file,
              status: UploadStatus.failed,
            );
          });
        }
      }
      logger.i("Pick Files Ended - Images");
    }
  }

  // Convert selected images into a single PDF file and return it
  Future<File> _convertImagesToPdf() async {
    logger.i("Convert Images to PDF Started");
    final pdf = pw.Document();

    for (final imageFile in _selectedImages) {
      final imageBytes = await imageFile.file.readAsBytes();
      final pwImage = pw.MemoryImage(imageBytes);
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(child: pw.Image(pwImage)),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    String temporaryName = DateTime.now().millisecondsSinceEpoch.toString();
    final file = File('${dir.path}/$temporaryName.pdf');
    await file.writeAsBytes(await pdf.save());

    logger.i("Convert Images to PDF Ended Successful");
    return file;
  }

  Future<void> _fileUpload() async {
    logger.i("File Upload Started");
    if (_selectedPdf == null && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a file")),
      );
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

      final fileSizeInMB = await fileToUpload.length() / (1024 * 1024);

      if (fileSizeInMB > 20) {
        logger.i("File Upload Ended - File Too Large");
        throw Exception("File too large (max 20MB)");
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

      if (_selectedType == "quiz" && _quizNumberController.text.isEmpty) {
        logger.i("File Upload Ended - No Quiz Number");
        throw Exception("Please enter quiz number");
      }

      if (_selectedType == "quiz" && _instructorController.text.isEmpty) {
        logger.i("File Upload Ended - No Instructor Name");
        throw Exception("Please enter instructor name");
      }

      final resourceItemRequest = ResourceItemRequest(
        course: widget.course,
        type: _selectedType!,
        semester: _selectedSemester!,
        year: _selectedYear!,
        quizNumber: _quizNumberController.text.isNotEmpty
            ? int.parse(_quizNumberController.text)
            : null,
        instructorName: _instructorController.text.isNotEmpty
            ? _instructorController.text
            : null,
        isSolved: _isSolved,
      );

      // Use the provider to upload the resource
      final uploadFunction = ref.read(resourceUploadFunctionProvider);
      await uploadFunction(
        resourceItemRequest: resourceItemRequest,
        filePath: fileToUpload.path,
      );

      if (!context.mounted) return;

      logger.i("File Upload Ended - Upload Successful");

      // Refresh fresh resources to fetch from backend using the custom refresh provider
      try {
        final refresh = ref.read(refreshResourcesForCourseProvider(widget.course.code));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e")),
        );
      }
      logger.e("File Upload Error: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  bool get _canShowUpload {
    if (_selectedType == null) return false;

    if (_selectedType == "book") {
      return true;
    }

    // final, midterm, quiz all require semester + year
    if (_selectedSemester == null || _selectedYear == null) return false;

    if (_selectedType == "quiz") {
      return _quizNumberController.text.isNotEmpty &&
          _instructorController.text.isNotEmpty;
    }

    // final or midterm
    return true;
  }

  bool get _canSubmit {
    return (_selectedPdf != null || _selectedImages.isNotEmpty) && _canShowUpload;
  }

  @override
  Widget build(BuildContext context) {
    final String courseDisplay = "${widget.course.code} - ${widget.course.name}";
    final isUploading = _isUploading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add Resource",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
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
            const Text("Resource Type", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              items: const [
                DropdownMenuItem(value: "final", child: Text("Final")),
                DropdownMenuItem(value: "midterm", child: Text("Midterm")),
                DropdownMenuItem(value: "quiz", child: Text("Quiz")),
                DropdownMenuItem(value: "book", child: Text("Book")),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
              decoration: const InputDecoration(hintText: "Select Resource Type"),
            ),
            const SizedBox(height: 20),

            /// Semester + Year — shown for final, midterm, and quiz
            if (_selectedType == "final" ||
                _selectedType == "midterm" ||
                _selectedType == "quiz") ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Semester",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSemester,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: "Fall", child: Text("Fall")),
                            DropdownMenuItem(value: "Spring", child: Text("Spring")),
                            DropdownMenuItem(value: "Summer", child: Text("Summer")),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedSemester = value;
                            });
                          },
                          decoration: const InputDecoration(hintText: "Select Semester"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Year",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          isExpanded: true,
                          items: List.generate(
                            DateTime.now().year - 2009,
                            (index) {
                              int year = DateTime.now().year - index;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            },
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                            });
                          },
                          decoration: const InputDecoration(hintText: "Select Year"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            /// Quiz-only Fields
            if (_selectedType == "quiz") ...[
              TextField(
                controller: _quizNumberController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}), // triggers _canShowUpload rebuild
                decoration: const InputDecoration(hintText: "Quiz Number"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instructorController,
                onChanged: (_) => setState(() {}), // triggers _canShowUpload rebuild
                decoration: const InputDecoration(hintText: "Instructor Name"),
              ),
              const SizedBox(height: 20),
            ],

            /// Solved Toggle — shown for final, midterm, and quiz
            if (_selectedType == "final" ||
                _selectedType == "midterm" ||
                _selectedType == "quiz") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Solved", style: TextStyle(fontWeight: FontWeight.w600)),
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