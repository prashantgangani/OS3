// lib/widgets/process_list.dart

import 'package:flutter/material.dart';
import '../models/process.dart';

class ProcessList extends StatelessWidget {
  final List<Process> processes;
  const ProcessList({super.key, this.processes = const []});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: processes.map((p) => ListTile(title: Text('P\${p.id}'), subtitle: Text('Burst: \${p.burst}'))).toList(),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}
