// lib/logic/round_robin.dart

import '../models/process.dart';
import '../models/gantt_block.dart';

List<GanttBlock> roundRobin(List<Process> processes, int quantum) {
  final List<GanttBlock> timeline = [];
  final queue = List<Process>.from(processes);
  int time = 0;

  while (queue.isNotEmpty) {
    final p = queue.removeAt(0);
    final work = p.remaining >= quantum ? quantum : p.remaining;
    final start = time;
    time += work;
    p.remaining -= work;
    final end = time;
    timeline.add(GanttBlock(processId: p.id, start: start, end: end));
    if (p.remaining > 0) queue.add(p);
  }
  return timeline;
}
