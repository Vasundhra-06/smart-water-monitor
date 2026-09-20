import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/tank.dart';

class AddTankScreen extends ConsumerStatefulWidget {
  const AddTankScreen({super.key});

  @override
  ConsumerState<AddTankScreen> createState() => _AddTankScreenState();
}

class _AddTankScreenState extends ConsumerState<AddTankScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController(text: '5000');
  final _deviceIdController = TextEditingController(text: 'TANK_005');

  void _submit() {
    if (_nameController.text.isEmpty) return;
    final now = DateTime.now();
    final newTank = Tank(
      id: 'tank-${now.millisecondsSinceEpoch}',
      tankName: _nameController.text,
      location: _locationController.text.isEmpty ? 'Campus Building' : _locationController.text,
      capacity: double.tryParse(_capacityController.text) ?? 5000.0,
      description: 'Institutional storage tank',
      status: TankStatus.online,
      deviceId: _deviceIdController.text,
      installationDate: now,
      lastCleanedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    ref.read(tankRepositoryProvider).addTank(newTank);
    ref.invalidate(tanksProvider);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: const Text('Add Institutional Storage Tank')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Tank Name', prefixIcon: Icon(Icons.water_rounded)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Location / Building', prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Capacity (Liters)', prefixIcon: Icon(Icons.line_weight_rounded)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deviceIdController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Paired Device ID (ESP32)', prefixIcon: Icon(Icons.router_outlined)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save & Initialize Tank Monitoring'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
