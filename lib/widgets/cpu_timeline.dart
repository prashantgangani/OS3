// lib/widgets/cpu_timeline.dart

import 'package:flutter/material.dart';
import '../models/gantt_block.dart';

class CpuTimeline extends StatelessWidget {
  final List<GanttBlock> blocks;
  const CpuTimeline({super.key, this.blocks = const []});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: blocks.map((b) => Container(
          width: (b.end - b.start) * 20.0,
          color: Colors.blueAccent,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(child: Text('P\${b.processId}')),
        )).toList(),
      ),
    );
  }
}
