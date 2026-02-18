// lib/models/process.dart

class Process {
  final int id;
  final int arrival;
  final int burst;
  int remaining;

  Process({
    required this.id,
    this.arrival = 0,
    required this.burst,
  }) : remaining = burst;

  Process copyWith({int? remaining}) => Process(id: id, arrival: arrival, burst: burst)..remaining = remaining ?? this.remaining;
}
