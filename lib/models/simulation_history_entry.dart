import 'process.dart';

class HistoryProcessResult {
  final int pid;
  final int completion;
  final int turnaround;
  final int waiting;

  const HistoryProcessResult({
    required this.pid,
    required this.completion,
    required this.turnaround,
    required this.waiting,
  });

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'completion': completion,
      'turnaround': turnaround,
      'waiting': waiting,
    };
  }

  factory HistoryProcessResult.fromJson(Map<String, dynamic> json) {
    return HistoryProcessResult(
      pid: json['pid'] as int,
      completion: json['completion'] as int,
      turnaround: json['turnaround'] as int,
      waiting: json['waiting'] as int,
    );
  }
}

class SimulationHistoryEntry {
  final String id;
  final DateTime createdAt;
  final int quantum;
  final List<Process> inputProcesses;
  final List<HistoryProcessResult> results;
  final double averageWaitingTime;
  final double averageTurnaroundTime;

  const SimulationHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.quantum,
    required this.inputProcesses,
    required this.results,
    required this.averageWaitingTime,
    required this.averageTurnaroundTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'quantum': quantum,
      'inputProcesses': inputProcesses
          .map(
            (p) => {
              'id': p.id,
              'arrival': p.arrival,
              'burst': p.burst,
            },
          )
          .toList(),
      'results': results.map((r) => r.toJson()).toList(),
      'averageWaitingTime': averageWaitingTime,
      'averageTurnaroundTime': averageTurnaroundTime,
    };
  }

  factory SimulationHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SimulationHistoryEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      quantum: json['quantum'] as int,
      inputProcesses: (json['inputProcesses'] as List<dynamic>)
          .map(
            (p) => Process(
              id: p['id'] as int,
              arrival: p['arrival'] as int,
              burst: p['burst'] as int,
            ),
          )
          .toList(),
      results: (json['results'] as List<dynamic>)
          .map(
            (r) => HistoryProcessResult.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList(),
      averageWaitingTime: (json['averageWaitingTime'] as num).toDouble(),
      averageTurnaroundTime: (json['averageTurnaroundTime'] as num).toDouble(),
    );
  }
}