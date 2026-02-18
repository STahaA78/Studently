import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:studently/models/course.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/resource.dart';
import 'package:studently/repositories/resource.dart';

class AddResourcePage extends StatefulWidget {
  final Course course;

  const AddResourcePage({super.key, required this.course});

  @override
  State<AddResourcePage> createState() => _AddResourcePageState();
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


class _AddResourcePageState extends State<AddResourcePage> {
  final Color blue = const Color(0xFF1976D2);

  // Uploaded File
  File? _selectedPdf;
  List<UploadImage> _selectedImages = [];
  bool _isUploading = false; // To show loading indicator during upload
  //Form Fields
  String? _selectedType;
  String? _selectedSemester;
  int? _selectedYear;
  bool _isSolved = false;
  // Text Controllers for Form Fields
  final TextEditingController _quizNumberController = TextEditingController();
  final TextEditingController _instructorController = TextEditingController();

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
  //Upload File Logic 
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
    } 
    else {
      setState(() {
        _selectedPdf = null;
        _selectedImages = files
            .map((file) => UploadImage(file: file, status: UploadStatus.compressing))
            .toList();
      });
      logger.i("Pick Files - Compressing Images");
      // Compress each image
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
              file: _selectedImages[i].file, // keep original
              status: UploadStatus.failed,
            );
          });
        }
      }
      logger.i("Pick Files Ended - Images");
    }

  }

  // This function will convert the selected images into a single PDF file and return it
  Future<File> _convertImagesToPdf() async {
    logger.i("Convert Images to PDF Started");
    final pdf = pw.Document();

    for (final imageFile in _selectedImages) {
      final imageBytes = await imageFile.file.readAsBytes();
      final pwImage = pw.MemoryImage(imageBytes);
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(child: pw.Image(pwImage))
        )
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

    setState(() => _isUploading = true);

    try {

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

      if (_selectedSemester == null || _selectedSemester!.isEmpty) {
        logger.i("File Upload Ended - No Semester Selected");
        throw Exception("Please select a semester");
      }
      if (_selectedYear == null) {
        logger.i("File Upload Ended - No Year Selected");
        throw Exception("Please select a year");
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
        semester: _selectedSemester!,
        year: _selectedYear!,
        quizNumber: _quizNumberController.text.isNotEmpty ? int.parse(_quizNumberController.text) : null,
        instructorName: _instructorController.text.isNotEmpty ? _instructorController.text : null,
        isSolved: _isSolved,
      );

      // Call your API service to upload the file
      await ResourceRepository().uploadResource(filePath: fileToUpload.path, resourceItemRequest: resourceItemRequest);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload successful")),
      );

    } catch (e) {
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => _isUploading = false);
      logger.i("File Upload Ended - Upload Successful");      
    }
  }

  @override
  Widget build(BuildContext context) {
    final String courseDisplay = "${widget.course.code} - ${widget.course.name}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, 
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Course (Greyed Out)
            const Text(
              "Course",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: courseDisplay,
              ),
            ),
            const SizedBox(height: 20),

            /// 🔹 Resource Type Dropdown
            const Text(
              "Resource Type",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
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
              decoration: const InputDecoration(
                hintText: "Select Resource Type",
              ),
            ),
            const SizedBox(height: 20),

            /// 🔹 Final / Midterm Fields
            if (_selectedType == "final" || _selectedType == "midterm") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Semester",
                      style: TextStyle(fontWeight: FontWeight.w600)
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSemester,
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
                    decoration:
                        const InputDecoration(hintText: "Select Semester"),
                  ),
                  const SizedBox(height: 16),
                  const Text("Year", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    // Generate years from the Current Year down to 2010
                    items: List.generate(
                      DateTime.now().year - 2009, // Number of years to show
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
                ]
              ),
              const SizedBox(height: 20),
            ],

            /// 🔹 Quiz Fields
            if (_selectedType == "quiz") ...[
              TextField(
                controller: _quizNumberController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(hintText: "Quiz Number"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instructorController,
                decoration:
                    const InputDecoration(hintText: "Instructor Name"),
              ),
              const SizedBox(height: 20),
            ],

            /// 🔹 Solved Toggle (For exam types only)
            if (_selectedType == "final" || _selectedType == "midterm" || _selectedType == "quiz") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Solved?",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Switch(
                    value: _isSolved,
                    activeThumbColor: blue,
                    onChanged: (value) {
                      setState(() {
                        _isSolved = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

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
            if (_selectedImages.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _selectedImages.map((img) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          img.file,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Spinner overlay
                      if (img.status == UploadStatus.compressing)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),

                      // Failed overlay with retry
                      if (img.status == UploadStatus.failed)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                onPressed: () async {
                                  setState(() {
                                    img.status = UploadStatus.compressing;
                                  });

                                  try {
                                    final compressedFile = await _compressImage(img.file);

                                    if (!mounted) return;

                                    setState(() {
                                      img.status = UploadStatus.success;
                                      img.file = compressedFile;
                                    });
                                  } catch (_) {
                                    if (!mounted) return;
                                    setState(() {
                                      img.status = UploadStatus.failed;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),

            const SizedBox(height: 30),

            /// 🔹 Add Resource Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_isUploading) return;
                  _fileUpload();
                },
                child: const Text(
                  "Add Resource",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
