import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';

class RecordCleaningScreen extends ConsumerStatefulWidget {
  const RecordCleaningScreen({super.key});

  @override
  ConsumerState<RecordCleaningScreen> createState() => _RecordCleaningScreenState();
}

class _RecordCleaningScreenState extends ConsumerState<RecordCleaningScreen> {
  final _technicianController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedTankId = 'tank-main';
  String _method = 'High-pressure Jet Wash & Chlorine Treatment';
  DateTime _cleanedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final selectedTank = ref.read(selectedTankProvider);
    if (selectedTank != null) {
      _selectedTankId = selectedTank.id;
    }
  }

  @override
  void dispose() {
    _technicianController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final tech = _technicianController.text.trim().isEmpty
        ? 'Facility Operator'
        : _technicianController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? 'Routine sanitization and sediment inspection completed.'
        : _notesController.text.trim();

    ref.read(cleaningRepositoryProvider).recordCleaning(
          _selectedTankId,
          tech,
          notes,
          _method,
        );

    // Reset simulation scenario to normal if deteriorating
    ref.read(simulationScenarioProvider.notifier).state = SimulationScenario.normal;
    MockSensorService.instance.setScenario(SimulationScenario.normal);

    // Invalidate providers so UI instantly reflects the real cleaning record
    ref.invalidate(cleaningHistoryProvider(_selectedTankId));
    ref.invalidate(cleaningHistoryProvider('all'));
    ref.invalidate(tanksProvider);
    ref.invalidate(aiAnalysisProvider(_selectedTankId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F2646),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tank cleaning recorded successfully! Historical log updated.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final allTanks = ref.watch(tanksProvider).value ?? MockSensorService.instance.getTanks();

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Record Tank Cleaning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informative Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, color: AppConstants.accentCyan, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Log genuine tank sanitization, pressure jetting, or filter replacement events. Records are saved permanently.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tank Selector
            Text('SELECT STORAGE TANK', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTankId,
              dropdownColor: const Color(0xFF0F1B33),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppConstants.darkCardBackground,
                prefixIcon: const Icon(Icons.water_rounded, color: AppConstants.accentCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
              ),
              items: allTanks.map((tank) {
                return DropdownMenuItem<String>(
                  value: tank.id,
                  child: Text('${tank.tankName} (${tank.capacity.toStringAsFixed(0)}L)'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedTankId = val);
              },
            ),
            const SizedBox(height: 20),

            // Technician / Operator Name
            Text('TECHNICIAN / OPERATOR NAME', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            TextField(
              controller: _technicianController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Ramesh Kumar / Self',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppConstants.darkCardBackground,
                prefixIcon: const Icon(Icons.person_outline, color: AppConstants.accentCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
              ),
            ),
            const SizedBox(height: 20),

            // Cleaning Method
            Text('CLEANING & SANITIZATION METHOD', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _method,
              dropdownColor: const Color(0xFF0F1B33),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppConstants.darkCardBackground,
                prefixIcon: const Icon(Icons.sanitizer_rounded, color: AppConstants.accentCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
              ),
              items: const [
                DropdownMenuItem(value: 'High-pressure Jet Wash & Chlorine Treatment', child: Text('High-pressure Jet & Chlorine Wash')),
                DropdownMenuItem(value: 'Manual Scrubbing & Sediment Removal', child: Text('Manual Scrubbing & Sediment Removal')),
                DropdownMenuItem(value: 'Chemical Sanitization & UV Replacement', child: Text('Chemical Sanitization & UV Bulb Replacement')),
                DropdownMenuItem(value: 'Complete Drain, Disinfection & Refill', child: Text('Complete Drain, Disinfection & Refill')),
              ],
              onChanged: (val) => setState(() => _method = val ?? _method),
            ),
            const SizedBox(height: 20),

            // Date of Cleaning
            Text('DATE OF CLEANING', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _cleanedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _cleanedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppConstants.darkCardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppConstants.darkCardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppConstants.accentCyan, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('d MMMM yyyy').format(_cleanedDate),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Text('Change', style: TextStyle(color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Inspection & Cleaning Notes
            Text('INSPECTION & MAINTENANCE NOTES', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Sediment drained, baffles cleaned, chlorine residual tested 0.2 ppm.',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
                filled: true,
                fillColor: AppConstants.darkCardBackground,
                prefixIcon: const Icon(Icons.notes_outlined, color: AppConstants.accentCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text('Confirm & Save Cleaning Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
