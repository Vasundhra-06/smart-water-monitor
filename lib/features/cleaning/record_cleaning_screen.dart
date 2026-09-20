import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';

class RecordCleaningScreen extends ConsumerStatefulWidget {
  const RecordCleaningScreen({super.key});

  @override
  ConsumerState<RecordCleaningScreen> createState() => _RecordCleaningScreenState();
}

class _RecordCleaningScreenState extends ConsumerState<RecordCleaningScreen> {
  final _technicianController = TextEditingController(text: 'Rajesh Kumar (Technician)');
  final _notesController = TextEditingController(text: 'Scrubbed tank walls, drained sediment, treated with 5ppm chlorine solution.');
  String _method = 'High-pressure Jet Wash & Chlorine Treatment';

  void _submit() {
    final selectedTank = ref.read(selectedTankProvider);
    final tankId = selectedTank?.id ?? 'tank-main';

    ref.read(cleaningRepositoryProvider).recordCleaning(
          tankId,
          _technicianController.text,
          _notesController.text,
          _method,
        );

    // Reset simulation scenario to normal if deteriorating
    ref.read(simulationScenarioProvider.notifier).state = SimulationScenario.normal;
    MockSensorService.instance.setScenario(SimulationScenario.normal);

    ref.refresh(cleaningHistoryProvider(tankId));
    ref.refresh(aiAnalysisProvider(tankId));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tank cleaning recorded successfully! AI trend baseline reset.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTank = ref.watch(selectedTankProvider);

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: Text('Record Tank Cleaning (${selectedTank?.tankName ?? "Main Tank"})')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _technicianController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Technician / Inspector Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _method,
                dropdownColor: AppConstants.darkSurface,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Cleaning Method', prefixIcon: Icon(Icons.cleaning_services)),
                items: const [
                  DropdownMenuItem(value: 'High-pressure Jet Wash & Chlorine Treatment', child: Text('High-pressure Jet & Chlorine Wash')),
                  DropdownMenuItem(value: 'Manual Scrubbing & Sediment Removal', child: Text('Manual Scrubbing & Sediment Draining')),
                  DropdownMenuItem(value: 'Chemical Sanitization & UV Replacement', child: Text('Chemical Sanitization & UV Bulb Replacement')),
                ],
                onChanged: (val) => setState(() => _method = val ?? _method),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Inspection & Cleaning Notes', prefixIcon: Icon(Icons.notes_outlined)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppConstants.colorGood.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppConstants.colorGood, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Recording cleaning will reset the AI water quality baseline for continuous trend monitoring.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Confirm & Save Cleaning Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
