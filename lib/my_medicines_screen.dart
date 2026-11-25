import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const kPrimary = Color(0xFF2563EB);
const kBackground = Color(0xFFF7F9FC);
const kText = Color(0xFF111827);
const kMuted = Color(0xFF6B7280);
const kBorder = Color(0xFFE5E7EB);

class MyMedicinesScreen extends StatefulWidget {
  const MyMedicinesScreen({super.key});

  @override
  State<MyMedicinesScreen> createState() => _MyMedicinesScreenState();
}

class _MyMedicinesScreenState extends State<MyMedicinesScreen> {
  List<Map<String, dynamic>> medicines = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_medicines') ?? <String>[];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) result.add(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      medicines = result;
      loading = false;
    });
  }

  Future<void> _delete(int index) async {
    final name = (medicines[index]['name'] ?? 'Medicine').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove medicine?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove $name from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    medicines.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'saved_medicines',
      medicines.map(jsonEncode).toList(),
    );
    await NotificationService.scheduleMedicines(medicines);

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name removed and reminders updated')),
    );
  }

  Future<void> _clearAll() async {
    if (medicines.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all medicines?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will remove all saved medicines from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)), child: const Text('Clear all')),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_medicines');
    await NotificationService.cancelAll();

    if (!mounted) return;
    setState(() => medicines = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('My Medicines', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [if (!loading && medicines.isNotEmpty) IconButton(onPressed: _clearAll, tooltip: 'Clear all', icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFDC2626)))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : medicines.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    children: [
                      const Text('Your medicines', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: kText, letterSpacing: -0.6)),
                      const SizedBox(height: 6),
                      Text('${medicines.length} medicine${medicines.length == 1 ? '' : 's'} saved on this device', style: const TextStyle(fontSize: 14, color: kMuted)),
                      const SizedBox(height: 18),
                      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD1FAE5))), child: const Row(children: [Icon(Icons.phone_android_rounded, color: Color(0xFF059669)), SizedBox(width: 10), Expanded(child: Text('Your medicine information is stored locally on this device.', style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF047857))))])),
                      const SizedBox(height: 18),
                      ...medicines.asMap().entries.map((entry) => _MedicineCard(medicine: entry.value, onDelete: () => _delete(entry.key))),
                    ],
                  ),
                ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 88, height: 88, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(26)), child: const Icon(Icons.medication_outlined, size: 42, color: kPrimary)),
              const SizedBox(height: 22),
              const Text('No medicines saved', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
              const SizedBox(height: 8),
              const Text('Scan a prescription and save the detected medicines to see them here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.45, color: kMuted)),
              const SizedBox(height: 22),
              FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.document_scanner_rounded), label: const Text('Scan prescription')),
            ],
          ),
        ),
      );
}

class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback onDelete;
  const _MedicineCard({required this.medicine, required this.onDelete});

  String _value(String key, [String fallback = 'As prescribed']) => (medicine[key] ?? fallback).toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.medication_rounded, color: kPrimary, size: 27)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_value('name', 'Medicine'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)), const SizedBox(height: 4), Text(_value('dosage'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary))])),
          PopupMenuButton<String>(onSelected: (value) { if (value == 'remove') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)), SizedBox(width: 9), Text('Remove')]))]),
        ]),
        const SizedBox(height: 17),
        _Info(icon: Icons.description_outlined, label: 'Instruction', value: _value('instruction')),
        const SizedBox(height: 11),
        _Info(icon: Icons.repeat_rounded, label: 'Frequency', value: _value('frequency')),
        const SizedBox(height: 11),
        _Info(icon: Icons.calendar_today_outlined, label: 'Duration', value: _value('duration')),
        const SizedBox(height: 11),
        _Info(icon: Icons.access_time_rounded, label: 'Timing', value: _value('timing')),
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Info({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: kMuted),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
