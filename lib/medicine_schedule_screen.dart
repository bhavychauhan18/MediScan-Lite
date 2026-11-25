import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'my_medicines_screen.dart';
import 'notification_service.dart';

class MedicineScheduleScreen extends StatefulWidget {
  final String extractedText;

  const MedicineScheduleScreen({
    super.key,
    required this.extractedText,
  });

  @override
  State<MedicineScheduleScreen> createState() =>
      _MedicineScheduleScreenState();
}

class _MedicineScheduleScreenState
    extends State<MedicineScheduleScreen> {
  late List<Medicine> medicines;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    medicines =
        _parsePrescription(widget.extractedText);
  }

  // ==========================================================================
  // PARSE OCR TEXT
  // ==========================================================================

  List<Medicine> _parsePrescription(String text) {
    // ML Kit can return either real line breaks or escaped "\\n" sequences.
    var normalized = text
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Repair common OCR variants in dosage units.
    normalized = normalized.replaceAll(
      RegExp(r'(\d+(?:\.\d+)?)\s*m[9yq]\b', caseSensitive: false),
      r'$1 mg',
    );

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final names = <String>[];
    final medicineIndex = lines.indexWhere(
      (line) => line.toLowerCase() == 'medicine',
    );

    if (medicineIndex >= 0) {
      for (var i = medicineIndex + 1; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();

        if (lower == 'dose' ||
            lower.startsWith('dose ') ||
            lower == 'frequency' ||
            lower.startsWith('take plenty') ||
            lower.startsWith('return for') ||
            lower == 'timing / instructions' ||
            lower == 'duration') {
          break;
        }

        final cleaned = line
            .replaceAll(RegExp(r'^[•·\-*\d.\s]+'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (cleaned.length < 3 ||
            cleaned.length > 40 ||
            RegExp(r'\d').hasMatch(cleaned) ||
            cleaned.split(' ').length > 4) {
          continue;
        }

        if (!RegExp(r'^[A-Za-z][A-Za-z\- ]+$').hasMatch(cleaned)) {
          continue;
        }

        const ignored = {
          'Advice',
          'Medicine',
          'Dose',
          'Frequency',
          'Duration',
          'Gender',
          'Male',
          'Female',
          'Timing',
          'Instructions',
        };

        if (!ignored.contains(cleaned)) {
          names.add(_titleCase(cleaned));
        }

        if (names.length == 8) break;
      }
    }

    final doses = <String>[];
    final doseStart = lines.indexWhere(
      (line) => line.toLowerCase() == 'dose',
    );
    final doseText = doseStart >= 0
        ? lines.skip(doseStart).take(18).join(' ')
        : normalized;

    for (final match in RegExp(
      r'(\d+(?:\.\d+)?)\s*mg\b',
      caseSensitive: false,
    ).allMatches(doseText)) {
      doses.add('${match.group(1)} mg');
      if (doses.length == names.length) break;
    }

    final frequencies = <String>[];
    for (final match in RegExp(
      r'(once daily|twice daily|three times daily|three times a day|'
      r'2\s*times daily|3\s*times daily)',
      caseSensitive: false,
    ).allMatches(normalized)) {
      final value = match.group(1)!.toLowerCase();
      final formatted = value.contains('twice') || value.startsWith('2')
          ? 'Twice daily'
          : value.contains('three') || value.startsWith('3')
              ? 'Three times daily'
              : 'Once daily';

      if (frequencies.length < names.length) {
        frequencies.add(formatted);
      }
      if (frequencies.length == names.length) break;
    }

    final timingValues = <String>[];
    final timingPatterns = [
      RegExp(r'after food', caseSensitive: false),
      RegExp(r'at night\s*\(bedtime\)', caseSensitive: false),
      RegExp(r'\(morning\s*&\s*afternoon\)', caseSensitive: false),
      RegExp(r'morning\s*&\s*afternoon', caseSensitive: false),
      RegExp(r'before breakfast\s*\(30 minutes\)', caseSensitive: false),
      RegExp(r'before breakfast', caseSensitive: false),
    ];

    for (final pattern in timingPatterns) {
      for (final match in pattern.allMatches(normalized)) {
        var value = match.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');

        if (value.toLowerCase().contains('before breakfast') &&
            value.toLowerCase().contains('30 minutes')) {
          value = 'Before breakfast (30 minutes)';
        } else if (value.toLowerCase().contains('before breakfast')) {
          value = 'Before breakfast';
        } else if (value.toLowerCase().contains('after food')) {
          value = 'After food';
        } else if (value.toLowerCase().contains('at night')) {
          value = 'At night (bedtime)';
        } else {
          value = 'Morning & Afternoon';
        }

        if (!timingValues.contains(value)) {
          timingValues.add(value);
        }
        if (timingValues.length == names.length) break;
      }
      if (timingValues.length == names.length) break;
    }

    final durations = <String>[];
    final durationStart = lines.indexWhere(
      (line) => line.toLowerCase() == 'duration',
    );
    final durationText = durationStart >= 0
        ? lines.skip(durationStart).take(12).join(' ')
        : normalized;

    for (final match in RegExp(
      r'(\d+)\s*days?',
      caseSensitive: false,
    ).allMatches(durationText)) {
      durations.add('${match.group(1)} days');
      if (durations.length == names.length) break;
    }

    if (names.isEmpty) {
      return [
        Medicine(
          name: 'Medicine details not detected',
          dosage: 'Not detected',
          instruction: 'Please verify the original prescription manually.',
          frequency: 'Not detected',
          duration: 'Not detected',
          timing: 'Not detected',
        ),
      ];
    }

    return List.generate(names.length, (index) {
      final dosage = index < doses.length ? doses[index] : 'Not detected';
      final frequency =
          index < frequencies.length ? frequencies[index] : 'Not detected';
      final timing =
          index < timingValues.length ? timingValues[index] : 'Not detected';
      final duration =
          index < durations.length ? durations[index] : 'Not detected';

      return Medicine(
        name: names[index],
        dosage: dosage,
        instruction: timing == 'Not detected'
            ? 'Please verify the prescription manually.'
            : timing,
        frequency: frequency,
        duration: duration,
        timing: timing,
      );
    });
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  Future<void> _saveMedicines() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final medicineData = medicines
          .map((medicine) => jsonEncode(medicine.toJson()))
          .toList();

      await prefs.setStringList('saved_medicines', medicineData);

      final savedMedicines = medicines
          .map((medicine) => medicine.toJson())
          .toList();

      final granted = await NotificationService.requestPermission();

      if (granted) {
        await NotificationService.scheduleMedicines(savedMedicines);
      } else {
        await NotificationService.cancelAll();
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Medicines saved and reminders scheduled.'
                : 'Medicines saved. Notifications are disabled on this device.',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyMedicinesScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save medicines: $e'),
        ),
      );
    }
  }

  // ==========================================================================
  // MEDICINE CARD
  // ==========================================================================

  Widget _buildMedicineCard(
    Medicine medicine,
    int number,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF2563EB),
                  size: 27,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF111827),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      medicine.dosage,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF3F4F6),
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: Text(
                  '#$number',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _infoRow(
            Icons.description_outlined,
            'Instruction',
            medicine.instruction,
          ),

          const SizedBox(height: 11),

          _infoRow(
            Icons.repeat_rounded,
            'Frequency',
            medicine.frequency,
          ),

          const SizedBox(height: 11),

          _infoRow(
            Icons.calendar_today_outlined,
            'Duration',
            medicine.duration,
          ),

          const SizedBox(height: 11),

          _infoRow(
            Icons.access_time_rounded,
            'Timing',
            medicine.timing,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // INFO ROW
  // ==========================================================================

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF6B7280),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF7F9FC),
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
          'Medicine Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review your medicines',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF111827),
                      ),
                    ),

                    const SizedBox(height: 7),

                    const Text(
                      'We detected the following medicines from your prescription.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color:
                            Color(0xFF6B7280),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---------------------------------------------------------
                    // WARNING
                    // ---------------------------------------------------------

                    Container(
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(
                          0xFFFFFBEB,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        border: Border.all(
                          color:
                              const Color(
                            0xFFFDE68A,
                          ),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            Icons
                                .warning_amber_rounded,
                            color:
                                Color(0xFFD97706),
                          ),

                          SizedBox(width: 11),

                          Expanded(
                            child: Text(
                              'OCR can make mistakes. Always verify medicine names and dosage instructions against the original prescription.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color:
                                    Color(
                                  0xFF92400E,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---------------------------------------------------------
                    // MEDICINES
                    // ---------------------------------------------------------

                    ...medicines
                        .asMap()
                        .entries
                        .map(
                          (entry) =>
                              _buildMedicineCard(
                            entry.value,
                            entry.key + 1,
                          ),
                        ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // SAVE BUTTON
            // ----------------------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20,
              ),
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color:
                        Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : _saveMedicines,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.save_rounded,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : 'Save Medicines',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF059669),
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
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

// ============================================================================
// MEDICINE MODEL
// ============================================================================

class Medicine {
  final String name;
  final String dosage;
  final String instruction;
  final String frequency;
  final String duration;
  final String timing;

  Medicine({
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.frequency,
    required this.duration,
    required this.timing,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'instruction': instruction,
      'frequency': frequency,
      'duration': duration,
      'timing': timing,
    };
  }
}