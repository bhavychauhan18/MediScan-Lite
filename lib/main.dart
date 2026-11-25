import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'my_medicines_screen.dart';
import 'notification_service.dart';
import 'scan_screen.dart';

const kPrimary = Color(0xFF2563EB);
const kPrimaryDark = Color(0xFF1D4ED8);
const kBackground = Color(0xFFF7F9FC);
const kText = Color(0xFF111827);
const kMuted = Color(0xFF6B7280);
const kBorder = Color(0xFFE5E7EB);
const kGreen = Color(0xFF059669);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MediScanApp());
}

class MediScanApp extends StatelessWidget {
  const MediScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediScan Lite',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBackground,
          foregroundColor: kText,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

Future<List<Map<String, dynamic>>> loadSavedMedicines() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('saved_medicines') ?? <String>[];
  final medicines = <Map<String, dynamic>>[];

  for (final item in raw) {
    try {
      final decoded = jsonDecode(item);
      if (decoded is Map) {
        medicines.add(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  return medicines;
}

int frequencyCount(Map<String, dynamic> medicine) {
  final value = (medicine['frequency'] ?? '').toString().toLowerCase();

  if (value.contains('3') || value.contains('three')) return 3;
  if (value.contains('2') || value.contains('twice')) return 2;

  return 1;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int medicineCount = 0;
  int todayDoseCount = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final medicines = await loadSavedMedicines();

    if (!mounted) return;

    setState(() {
      medicineCount = medicines.length;
      todayDoseCount = medicines.fold<int>(
        0,
        (sum, medicine) => sum + frequencyCount(medicine),
      );
      loading = false;
    });
  }

  Future<void> _showReminderStatus() async {
    final medicines = await loadSavedMedicines();

    if (!mounted) return;

    final permissionGranted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: kPrimary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Medicine reminders',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          medicines.isEmpty
              ? 'Save a medicine schedule to create dose reminders.'
              : 'MediScan Lite can remind you when your scheduled doses are due. '
                  'Reminders are stored locally on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          if (medicines.isNotEmpty)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext, true);
                final granted = await NotificationService.requestPermission();
                if (!granted || !mounted) return;
                await NotificationService.scheduleMedicines(medicines);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Medicine reminders are enabled.'),
                  ),
                );
              },
              child: const Text('Enable reminders'),
            ),
          if (medicines.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext, true);
                final granted = await NotificationService.requestPermission();
                if (!granted) return;
                await NotificationService.showTestNotification();
              },
              child: const Text('Send test'),
            ),
        ],
      ),
    );

    if (permissionGranted == true) {
      // The dialog already handled the selected action.
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: kPrimary,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MediScan Lite',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: kText,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Smart prescription & medicine care',
                          style: TextStyle(
                            fontSize: 12,
                            color: kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showReminderStatus,
                    tooltip: 'Medicine reminders',
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: kText,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Stay on top of your medicines',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: kText,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 22),
              _ScanHero(
                onTap: () => _open(const ScanScreen()),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Today at a glance'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.medication_outlined,
                      value: loading ? '—' : '$medicineCount',
                      label: 'Active medicines',
                      onTap: () => _open(const MyMedicinesScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule_rounded,
                      value: loading ? '—' : '$todayDoseCount',
                      label: 'Doses today',
                      onTap: () => _open(const TodaysDosesScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Quick access'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.medication_rounded,
                      title: 'My Medicines',
                      subtitle: 'View saved medicines',
                      onTap: () => _open(const MyMedicinesScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.today_rounded,
                      title: "Today's Doses",
                      subtitle: "View today's schedule",
                      onTap: () => _open(const TodaysDosesScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD1FAE5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: kGreen,
                      size: 22,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Offline-first. Your medicine information stays on this device.',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: kText,
          letterSpacing: -0.2,
        ),
      );
}

class _ScanHero extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanHero({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Scan a prescription',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Extract medicine names and dosage instructions from a photo using on-device OCR.',
            style: TextStyle(
              color: Color(0xFFDCE7FF),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(
                Icons.camera_alt_rounded,
                size: 20,
              ),
              label: const Text(
                'Start scanning',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kPrimaryDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: kPrimary,
                size: 25,
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: kPrimary,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodaysDosesScreen extends StatefulWidget {
  const TodaysDosesScreen({super.key});

  @override
  State<TodaysDosesScreen> createState() => _TodaysDosesScreenState();
}

class _TodaysDosesScreenState extends State<TodaysDosesScreen> {
  List<Map<String, dynamic>> medicines = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await loadSavedMedicines();

    if (!mounted) return;

    setState(() {
      medicines = data;
      loading = false;
    });
  }

  String _name(Map<String, dynamic> m) =>
      (m['name'] ?? 'Medicine').toString();

  String _dose(Map<String, dynamic> m) =>
      (m['dosage'] ?? '').toString();

  String _instruction(Map<String, dynamic> m) =>
      (m['instruction'] ?? 'Take as prescribed').toString();

  List<String> _times(Map<String, dynamic> m) {
    final instruction = _instruction(m).toLowerCase();
    final frequency = frequencyCount(m);

    if (instruction.contains('morning') &&
        instruction.contains('night')) {
      return ['08:00 AM', '08:00 PM'];
    }

    if (instruction.contains('before breakfast')) {
      return ['07:30 AM'];
    }

    if (frequency == 3) {
      return [
        '08:00 AM',
        '02:00 PM',
        '08:00 PM',
      ];
    }

    if (frequency == 2) {
      return [
        '08:00 AM',
        '08:00 PM',
      ];
    }

    return ['08:00 AM'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          "Today's Doses",
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: kPrimary,
              ),
            )
          : medicines.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      30,
                    ),
                    children: [
                      const Text(
                        "Today's schedule",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: kText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${medicines.fold<int>(0, (s, m) => s + frequencyCount(m))} doses planned from your saved prescription.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: kMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _notice(),
                      const SizedBox(height: 18),
                      ...medicines.map(
                        (m) => _DoseCard(
                          name: _name(m),
                          dose: _dose(m),
                          instruction: _instruction(m),
                          times: _times(m),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _notice() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFDE68A),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD97706),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Demo schedule for the college project. Always follow the original prescription and your doctor\'s instructions.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 42,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'No doses scheduled',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan a prescription and save the medicines first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: kMuted,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Scan prescription'),
              ),
            ],
          ),
        ),
      );
}

class _DoseCard extends StatelessWidget {
  final String name;
  final String dose;
  final String instruction;
  final List<String> times;

  const _DoseCard({
    required this.name,
    required this.dose,
    required this.instruction,
    required this.times,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kText,
                      ),
                    ),
                    if (dose.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        dose,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: times
                .map(
                  (time) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 13),
          Text(
            instruction,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: kMuted,
            ),
          ),
        ],
      ),
    );
  }
}