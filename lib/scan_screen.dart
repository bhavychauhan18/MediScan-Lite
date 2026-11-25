import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'medicine_schedule_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  File? _image;
  String _extractedText = '';
  bool _isProcessing = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // ==========================================================================
  // PICK IMAGE
  // ==========================================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _image = File(pickedFile.path);
        _extractedText = '';
        _isProcessing = true;
      });

      await _runOCR(pickedFile.path);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to process image: $e',
          ),
        ),
      );
    }
  }

  // ==========================================================================
  // OCR
  // ==========================================================================

  Future<void> _runOCR(String imagePath) async {
    File? enhancedFile;

    try {
      // First pass: use the original image at its full available quality.
      final originalText = await _recognizeFile(imagePath);

      // Second pass: create a local, high-contrast copy. This helps with
      // light/colored text and small printed medicine names while keeping
      // everything on-device.
      enhancedFile = await _createEnhancedOCRImage(imagePath);
      final enhancedText = await _recognizeFile(enhancedFile.path);

      final mergedText = _mergeOCRText(
        originalText,
        enhancedText,
      ).trim();

      if (!mounted) return;

      setState(() {
        _extractedText = mergedText;
        _isProcessing = false;
      });

      if (_extractedText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No readable text was detected. Please try a clearer image.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _extractedText =
            'OCR failed. Please try another image.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OCR processing failed: $e',
          ),
        ),
      );
    } finally {
      try {
        await enhancedFile?.delete();
      } catch (_) {
        // Temporary OCR file cleanup is best-effort.
      }
    }
  }

  Future<String> _recognizeFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText =
        await _textRecognizer.processImage(inputImage);
    return recognizedText.text.trim();
  }

  Future<File> _createEnhancedOCRImage(String sourcePath) async {
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Unable to prepare image for OCR.');
    }

    final targetWidth = decoded.width < 2200
        ? decoded.width * 2
        : decoded.width;

    var enhanced = img.copyResize(
      decoded,
      width: targetWidth,
      interpolation: img.Interpolation.cubic,
    );

    enhanced = img.grayscale(enhanced);
    enhanced = img.adjustColor(
      enhanced,
      contrast: 1.25,
      brightness: 1.05,
    );

    final path =
        '${Directory.systemTemp.path}/mediscan_ocr_${DateTime.now().millisecondsSinceEpoch}.png';

    final file = File(path);
    await file.writeAsBytes(
      img.encodePng(enhanced),
      flush: true,
    );

    return file;
  }

  String _mergeOCRText(
    String original,
    String enhanced,
  ) {
    final lines = <String>[];
    final seen = <String>{};

    for (final source in [original, enhanced]) {
      for (final rawLine in source.split(RegExp(r'\r?\n'))) {
        final line = rawLine.trim();

        if (line.isEmpty) continue;

        final key = line
            .toLowerCase()
            .replaceAll(RegExp(r'\\s+'), ' ')
            .trim();

        if (seen.add(key)) {
          lines.add(line);
        }
      }
    }

    return lines.join('\\n');
  }

  // ==========================================================================
  // IMAGE SOURCE BOTTOM SHEET
  // ==========================================================================

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Select Image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 18),

                // CAMERA
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Use your phone camera',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),

                const SizedBox(height: 8),

                // GALLERY
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF059669),
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing prescription',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // CLEAR SCAN
  // ==========================================================================

  void _clearScan() {
    setState(() {
      _image = null;
      _extractedText = '';
      _isProcessing = false;
    });
  }

  // ==========================================================================
  // CREATE MEDICINE SCHEDULE
  // ==========================================================================

  void _createMedicineSchedule() {
    if (_extractedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please scan a prescription first.',
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineScheduleScreen(
          extractedText: _extractedText,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      // ----------------------------------------------------------------------
      // APP BAR
      // ----------------------------------------------------------------------

      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF111827),
          ),
        ),

        title: const Text(
          'Scan Prescription',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),

      // ----------------------------------------------------------------------
      // BODY
      // ----------------------------------------------------------------------

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------------------------
              // TITLE
              // ----------------------------------------------------------------

              const Text(
                'Scan your prescription',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Take a clear photo or choose an image. '
                'MediScan will extract the text automatically.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 24),

              // ----------------------------------------------------------------
              // IMAGE PREVIEW / EMPTY STATE
              // ----------------------------------------------------------------

              GestureDetector(
                onTap: _showImageOptions,
                child: Container(
                  width: double.infinity,
                  height: 270,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFEFF6FF),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.document_scanner_rounded,
                                size: 34,
                                color: Color(0xFF2563EB),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              'No prescription selected',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              'Tap here to scan or select an image',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius:
                              BorderRadius.circular(22),
                          child: Image.file(
                            _image!,
                            width: double.infinity,
                            height: 270,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 18),

              // ----------------------------------------------------------------
              // SCAN BUTTON
              // ----------------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showImageOptions,
                  icon: const Icon(
                    Icons.camera_alt_rounded,
                  ),
                  label: Text(
                    _image == null
                        ? 'Scan Prescription'
                        : 'Scan Another',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              // ----------------------------------------------------------------
              // OCR PROCESSING
              // ----------------------------------------------------------------

              if (_isProcessing) ...[
                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF2563EB),
                        ),
                      ),

                      SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reading prescription...',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Processing text on your device',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ----------------------------------------------------------------
              // EXTRACTED TEXT
              // ----------------------------------------------------------------

              if (_extractedText.isNotEmpty &&
                  !_isProcessing) ...[
                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Extracted Text',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),

                    TextButton(
                      onPressed: _clearScan,
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 180,
                  ),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: SelectableText(
                    _extractedText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // --------------------------------------------------------------
                // CREATE SCHEDULE BUTTON
                // --------------------------------------------------------------

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _createMedicineSchedule,
                    icon: const Icon(
                      Icons.medication_rounded,
                    ),
                    label: const Text(
                      'Create Medicine Schedule',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ----------------------------------------------------------------
              // OCR TIP
              // ----------------------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFEF3C7),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Color(0xFFD97706),
                    ),

                    SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Tip: Keep the prescription flat and '
                        'make sure the text is clearly visible '
                        'for better OCR accuracy.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ----------------------------------------------------------------
              // PRIVACY / OFFLINE NOTICE
              // ----------------------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius:
                      BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFD1FAE5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: Color(0xFF059669),
                      size: 21,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'OCR runs on-device. Your prescription '
                        'image does not need to be uploaded '
                        'to a server.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}