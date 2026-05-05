import '../models/process.dart';
import '../models/gantt_block.dart';
import 'round_robin_simulator.dart'; // To reuse ProcessResult and SimulationResult

SimulationResult simulateSJF(List<Process> processes) {
  final List<GanttBlock> timeline = [];
  if (processes.isEmpty) {
    return SimulationResult(
      timeline: timeline,
      processResults: [],
      averageWaitingTime: 0,
      averageTurnaroundTime: 0,
    );
  }

  // Work on copies
  final procList = processes
      .map(
        (p) =>
            Process(id: p.id, arrival: p.arrival, burst: p.burst)
              ..remaining = p.burst,
      )
      .toList();

  // Sort by arrival time initially
  procList.sort((a, b) {
    if (a.arrival != b.arrival) return a.arrival.compareTo(b.arrival);
    return a.burst.compareTo(b.burst);
  });

  int time = 0;
  final queue = <Process>[];
  final results = <ProcessResult>[];
  double totalWT = 0;
  double totalTAT = 0;

  final remainingProcs = List<Process>.from(procList);

  while (remainingProcs.isNotEmpty || queue.isNotEmpty) {
    // Add all processes that have arrived up to 'time' to the queue
    remainingProcs.removeWhere((p) {
      if (p.arrival <= time) {
        queue.add(p);
        return true;
      }
      return false;
    });

    if (queue.isEmpty) {
      // If queue is empty, jump time to the next arrival
      remainingProcs.sort((a, b) => a.arrival.compareTo(b.arrival));
      time = remainingProcs.first.arrival;
      continue;
    }

    // SJF: Sort queue by burst time
    queue.sort((a, b) {
      if (a.burst != b.burst) return a.burst.compareTo(b.burst);
      return a.arrival.compareTo(b.arrival); // FCFS for tie breaker
    });

    final p = queue.removeAt(0);
    final start = time;
    final work = p.burst;
    time += work;
    final end = time;

    timeline.add(GanttBlock(processId: p.id, start: start, end: end));

    final ct = end;
    final tat = ct - p.arrival;
    final wt = tat - p.burst;
    totalWT += wt;
    totalTAT += tat;

    results.add(
      ProcessResult(
        pid: p.id,
        arrival: p.arrival,
        burst: p.burst,
        completion: ct,
        turnaround: tat,
        waiting: wt,
      ),
    );
  }

  final avgWT = results.isEmpty ? 0.0 : totalWT / results.length;
  final avgTAT = results.isEmpty ? 0.0 : totalTAT / results.length;

  // sort results back by PID or Arrival
  results.sort((a, b) => a.pid.compareTo(b.pid));

  return SimulationResult(
    timeline: timeline,
    processResults: results,
    averageWaitingTime: avgWT,
    averageTurnaroundTime: avgTAT,
  );
}
