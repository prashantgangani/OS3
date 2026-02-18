// lib/widgets/process_form.dart

import 'package:flutter/material.dart';

class ProcessForm extends StatefulWidget {
  const ProcessForm({super.key});

  @override
  State<ProcessForm> createState() => _ProcessFormState();
}

class _ProcessFormState extends State<ProcessForm> {
  final _idCtrl = TextEditingController();
  final _arrivalCtrl = TextEditingController();
  final _burstCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _arrivalCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  void _onAdd() {
    // placeholder: wire this up to parent via callback when adding logic
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add process (stub)')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'ID')),
        TextField(controller: _arrivalCtrl, decoration: const InputDecoration(labelText: 'Arrival')),
        TextField(controller: _burstCtrl, decoration: const InputDecoration(labelText: 'Burst')),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _onAdd, child: const Text('Add Process')),
      ],
    );
  }
}
