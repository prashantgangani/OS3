import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../../models/process.dart';
import '../../models/simulation_history_entry.dart';
import '../../models/gantt_block.dart';
import '../../logic/sjf_simulator.dart';
import '../../logic/round_robin_simulator.dart'
    show ProcessResult, SimulationResult;
import '../../utils/history_storage.dart';
import '../history/history_screen.dart';

class SJFScreen extends StatefulWidget {
  static const routeName = '/sjf';
  const SJFScreen({super.key});

  @override
  State<SJFScreen> createState() => _SJFScreenState();
}

class _SJFScreenState extends State<SJFScreen> {
  final _pidCtrl = TextEditingController();
  final _atCtrl = TextEditingController();
  final _btCtrl = TextEditingController();

  final List<Process> _processes = [];

  List<GanttBlock> _timeline = [];
  List<ProcessResult> _results = [];
  double _avgWT = 0;
  double _avgTAT = 0;

  Timer? _timer;
  final ScrollController _timelineScrollCtrl = ScrollController();
  int _currentBlock = -1;
  bool _isRunning = false;
  bool _isPaused = false;

  static const double _blockWidth = 72;
  static const double _blockHorizontalPadding = 6;
  static const Duration _stepDuration = Duration(milliseconds: 700);

  @override
  void dispose() {
    _pidCtrl.dispose();
    _atCtrl.dispose();
    _btCtrl.dispose();
    _timelineScrollCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _addProcess() {
    final pid = int.tryParse(_pidCtrl.text);
    final at = int.tryParse(_atCtrl.text);
    final bt = int.tryParse(_btCtrl.text);
    if (pid == null || at == null || bt == null || bt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid PID, AT and BT')),
      );
      return;
    }

    if (_processes.any((p) => p.id == pid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A process with the same PID is already in the list'),
        ),
      );
      return;
    }

    setState(() {
      _processes.add(Process(id: pid, arrival: at, burst: bt));
      _pidCtrl.clear();
      _atCtrl.clear();
      _btCtrl.clear();
    });
  }

  void _deleteProcess(int pid) {
    setState(() {
      _processes.removeWhere((p) => p.id == pid);
    });
  }

  void _runSimulation() {
    if (_processes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one process')));
      return;
    }

    final sim = simulateSJF(_processes);
    _saveRunToHistory(sim);
    setState(() {
      _timeline = sim.timeline;
      _results = sim.processResults;
      _avgWT = sim.averageWaitingTime;
      _avgTAT = sim.averageTurnaroundTime;
      _currentBlock = -1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineScrollCtrl.hasClients) {
        _timelineScrollCtrl.jumpTo(0);
      }
    });

    _startAnimation();
  }

  Future<void> _saveRunToHistory(SimulationResult sim) async {
    final entry = SimulationHistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      quantum: 0, // Not applicable for SJF
      inputProcesses: _processes
          .map((p) => Process(id: p.id, arrival: p.arrival, burst: p.burst))
          .toList(),
      results: sim.processResults
          .map(
            (r) => HistoryProcessResult(
              pid: r.pid,
              completion: r.completion,
              turnaround: r.turnaround,
              waiting: r.waiting,
            ),
          )
          .toList(),
      averageWaitingTime: sim.averageWaitingTime,
      averageTurnaroundTime: sim.averageTurnaroundTime,
    );

    await HistoryStorage.saveEntry(entry);
  }

  void _startAnimation() {
    if (_timeline.isEmpty) return;
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
      if (_currentBlock < 0) _currentBlock = -1;
    });

    _timer = Timer.periodic(_stepDuration, (t) {
      if (!_isRunning) return;
      if (_isPaused) return;
      setState(() {
        _currentBlock++;
      });
      _scrollTimelineToCurrentBlock();
      if (_currentBlock >= _timeline.length) {
        t.cancel();
        setState(() {
          _isRunning = false;
          _currentBlock = _timeline.length - 1;
        });
        _scrollTimelineToCurrentBlock();
      }
    });
  }

  void _scrollTimelineToCurrentBlock() {
    if (_currentBlock < 0 || !_timelineScrollCtrl.hasClients) return;

    final double blockExtent = _blockWidth + (_blockHorizontalPadding * 2);
    final double target = (_currentBlock * blockExtent) - 24;
    final double max = _timelineScrollCtrl.position.maxScrollExtent;
    final double clamped = target.clamp(0, max).toDouble();

    _timelineScrollCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _pauseAnimation() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeAnimation() {
    if (!_isRunning) {
      _startAnimation();
      return;
    }
    setState(() {
      _isPaused = false;
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _timeline = [];
      _results = [];
      _avgWT = 0;
      _avgTAT = 0;
      _currentBlock = -1;
    });
    if (_timelineScrollCtrl.hasClients) {
      _timelineScrollCtrl.jumpTo(0);
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text('OS Scheduler Simulator - Shortest Job First'),
          ),
          pw.Header(level: 1, child: pw.Text('Input Processes')),
          pw.Table.fromTextArray(
            headers: ['PID', 'Arrival', 'Burst'],
            data: _processes
                .map(
                  (p) => [
                    p.id.toString(),
                    p.arrival.toString(),
                    p.burst.toString(),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Header(
            level: 1,
            child: pw.Text('Gantt Timeline (PID, Start, End)'),
          ),
          pw.Table.fromTextArray(
            headers: ['PID', 'Start', 'End'],
            data: _timeline
                .map(
                  (b) => [
                    b.processId.toString(),
                    b.start.toString(),
                    b.end.toString(),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('Results')),
          pw.Table.fromTextArray(
            headers: ['PID', 'CT', 'TAT', 'WT'],
            data: _results
                .map(
                  (r) => [
                    r.pid.toString(),
                    r.completion.toString(),
                    r.turnaround.toString(),
                    r.waiting.toString(),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Paragraph(
            text: 'Average Waiting Time: ${_avgWT.toStringAsFixed(2)}',
          ),
          pw.Paragraph(
            text: 'Average Turnaround Time: ${_avgTAT.toStringAsFixed(2)}',
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/os3.png', height: 28),
            const SizedBox(width: 8),
            const Text('SJF Simulator', style: TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'PID',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _atCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Arrival',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _btCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Burst',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _addProcess,
                  elevation: 2,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_processes.isNotEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: _processes.map((p) {
                      return ListTile(
                        leading: CircleAvatar(child: Text(p.id.toString())),
                        title: Text('AT: ${p.arrival}  |  BT: ${p.burst}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteProcess(p.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Simulate'),
                  onPressed: _runSimulation,
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: _reset,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_timeline.isNotEmpty) ...[
              const Text(
                'Animation Controls',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _isPaused || !_isRunning
                        ? null
                        : _pauseAnimation,
                    icon: const Icon(Icons.pause),
                    tooltip: 'Pause',
                  ),
                  IconButton(
                    onPressed:
                        (_isPaused ||
                            (!_isRunning &&
                                _currentBlock < _timeline.length - 1))
                        ? _resumeAnimation
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Resume',
                  ),
                  const Spacer(),
                  if (!_isRunning && _currentBlock == _timeline.length - 1)
                    const Text(
                      'Simulation Finished',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_timeline.isNotEmpty) ...[
              const Text(
                'Gantt Chart Timeline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  controller: _timelineScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  itemCount: _timeline.length,
                  itemBuilder: (ctx, i) {
                    final block = _timeline[i];
                    final isRevealed = i <= _currentBlock;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: isRevealed ? 1.0 : 0.0,
                      child: Container(
                        width: _blockWidth,
                        margin: const EdgeInsets.symmetric(
                          horizontal: _blockHorizontalPadding,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'P${block.processId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors
                                      .primaries[block.processId %
                                          Colors.primaries.length]
                                      .withOpacity(0.4),
                                  border: Border.all(
                                    color:
                                        Colors.primaries[block.processId %
                                            Colors.primaries.length],
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${block.end - block.start}'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  block.start.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  block.end.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_results.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Results',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    onPressed: _generatePdf,
                    tooltip: 'Download PDF',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  columns: const [
                    DataColumn(label: Text('PID')),
                    DataColumn(label: Text('AT')),
                    DataColumn(label: Text('BT')),
                    DataColumn(label: Text('CT')),
                    DataColumn(label: Text('TAT')),
                    DataColumn(label: Text('WT')),
                  ],
                  rows: _results.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text(r.pid.toString())),
                        DataCell(Text(r.arrival.toString())),
                        DataCell(Text(r.burst.toString())),
                        DataCell(Text(r.completion.toString())),
                        DataCell(Text(r.turnaround.toString())),
                        DataCell(Text(r.waiting.toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Avg Turnaround Time:'),
                          Text(
                            _avgTAT.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Avg Waiting Time:'),
                          Text(
                            _avgWT.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
