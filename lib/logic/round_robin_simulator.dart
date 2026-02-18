import '../models/process.dart';
import '../models/gantt_block.dart';

class SimulationResult {
  final List<GanttBlock> timeline;
  final List<ProcessResult> processResults;
  final double averageWaitingTime;
  final double averageTurnaroundTime;

  SimulationResult({
    required this.timeline,
    required this.processResults,
    required this.averageWaitingTime,
    required this.averageTurnaroundTime,
  });
}

class ProcessResult {
  final int pid;
  final int arrival;
  final int burst;
  final int completion;
  final int turnaround;
  final int waiting;

  ProcessResult({
    required this.pid,
    required this.arrival,
    required this.burst,
    required this.completion,
    required this.turnaround,
    required this.waiting,
  });
}

SimulationResult simulateRoundRobin(List<Process> processes, int quantum) {
  final List<GanttBlock> timeline = [];
  if (processes.isEmpty || quantum <= 0) {
    return SimulationResult(
      timeline: timeline,
      processResults: [],
      averageWaitingTime: 0,
      averageTurnaroundTime: 0,
    );
  }

  // Work on copies
  final procList = processes
      .map((p) => Process(id: p.id, arrival: p.arrival, burst: p.burst)..remaining = p.burst)
      .toList();
  procList.sort((a, b) {
    if (a.arrival != b.arrival) return a.arrival.compareTo(b.arrival);
    return a.id.compareTo(b.id);
  });

  int time = procList.first.arrival;
  final queue = <Process>[];
  int idx = 0;

  void enqueueArrived() {
    while (idx < procList.length && procList[idx].arrival <= time) {
      queue.add(procList[idx]);
      idx++;
    }
  }

  enqueueArrived();

  while (queue.isNotEmpty || idx < procList.length) {
    if (queue.isEmpty) {
      // jump to next arrival
      time = procList[idx].arrival;
      enqueueArrived();
      continue;
    }

    final p = queue.removeAt(0);
    final work = (p.remaining >= quantum) ? quantum : p.remaining;
    final start = time;
    time += work;
    p.remaining -= work;
    final end = time;
    timeline.add(GanttBlock(processId: p.id, start: start, end: end));

    // Enqueue any new arrivals that happened during execution
    enqueueArrived();

    if (p.remaining > 0) queue.add(p);
  }

  // Compute completion times
  final Map<int, int> completion = {};
  for (final b in timeline) {
    completion[b.processId] = b.end; // last assignment will be final completion
  }

  final results = <ProcessResult>[];
  double totalWT = 0;
  double totalTAT = 0;

  for (final p in procList) {
    final ct = completion[p.id]!;
    final tat = ct - p.arrival;
    final wt = tat - p.burst;
    totalWT += wt;
    totalTAT += tat;
    results.add(ProcessResult(pid: p.id, arrival: p.arrival, burst: p.burst, completion: ct, turnaround: tat, waiting: wt));
  }

  final avgWT = results.isEmpty ? 0.0 : totalWT / results.length;
  final avgTAT = results.isEmpty ? 0.0 : totalTAT / results.length;

  return SimulationResult(
    timeline: timeline,
    processResults: results,
    averageWaitingTime: avgWT,
    averageTurnaroundTime: avgTAT,
  );
}
