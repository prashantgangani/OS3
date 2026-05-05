import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../../models/process.dart';
import '../../models/simulation_history_entry.dart';
import '../../models/gantt_block.dart';
import '../../logic/round_robin_simulator.dart';
import '../../utils/history_storage.dart';
import '../history/history_screen.dart';

class RoundRobinScreen extends StatefulWidget {
  static const routeName = '/round-robin';
  const RoundRobinScreen({super.key});

  @override
  State<RoundRobinScreen> createState() => _RoundRobinScreenState();
}

class _RoundRobinScreenState extends State<RoundRobinScreen> {
  final _pidCtrl = TextEditingController();
  final _atCtrl = TextEditingController();
  final _btCtrl = TextEditingController();
  final _qtCtrl = TextEditingController();

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
    _qtCtrl.dispose();
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

    // ensure PID uniqueness
    if (_processes.any((p) => p.id == pid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('the process with same name already in list'),
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
    final qt = int.tryParse(_qtCtrl.text);
    if (qt == null || qt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Time Quantum')),
      );
      return;
    }
    if (_processes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one process')));
      return;
    }

    final sim = simulateRoundRobin(_processes, qt);
    _saveRunToHistory(sim, qt);
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

  Future<void> _saveRunToHistory(SimulationResult sim, int quantum) async {
    final entry = SimulationHistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      quantum: quantum,
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
            child: pw.Text('OS Scheduler Simulator - Round Robin'),
          ),
          pw.Paragraph(text: 'Time Quantum: ${_qtCtrl.text}'),

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
            const Text('Round Robin Simulator', style: TextStyle(fontSize: 18)),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Input',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pidCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'PID'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _atCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Arrival Time (AT)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _btCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Burst Time (BT)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Time Quantum (QT)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addProcess,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Process'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Processes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 140,
                      child: Card(
                        color: Colors.grey[50],
                        child: _processes.isEmpty
                            ? const Center(child: Text('No processes added'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemBuilder: (ctx, i) {
                                  final p = _processes[i];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            Colors.primaries[p.id %
                                                Colors.primaries.length],
                                        child: Text(
                                          p.id.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        'Process ${p.id}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Arrival: ${p.arrival}  |  Burst: ${p.burst}',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => _deleteProcess(p.id),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemCount: _processes.length,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Simulation card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Simulation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _runSimulation,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _timeline.isNotEmpty
                                    ? () {
                                        if (_isRunning && !_isPaused) {
                                          _pauseAnimation();
                                        } else {
                                          _resumeAnimation();
                                        }
                                      }
                                    : null,
                                icon: Icon(
                                  _isRunning && !_isPaused
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                                label: Text(
                                  _isRunning && !_isPaused ? 'Pause' : 'Resume',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _reset,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: _generatePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generate PDF'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'CPU Timeline',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: _timeline.isEmpty
                          ? Center(
                              child: Text(
                                'No timeline yet. Run simulation to see CPU timeline.',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : SingleChildScrollView(
                              controller: _timelineScrollCtrl,
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(_timeline.length, (i) {
                                  final block = _timeline[i];
                                  final isRevealed = i <= _currentBlock;
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: isRevealed ? 1.0 : 0.0,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: _blockHorizontalPadding,
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: _blockWidth,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: Colors
                                                  .primaries[block.processId %
                                                      Colors.primaries.length]
                                                  .withOpacity(0.3),
                                              border: Border.all(
                                                color:
                                                    Colors.primaries[block
                                                            .processId %
                                                        Colors
                                                            .primaries
                                                            .length],
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'P${block.processId}',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${block.start} - ${block.end}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Results
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _results.isEmpty
                        ? const Text('No results yet. Run simulation.')
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('PID')),
                                DataColumn(label: Text('CT')),
                                DataColumn(label: Text('TAT')),
                                DataColumn(label: Text('WT')),
                              ],
                              rows: _results
                                  .map(
                                    (r) => DataRow(
                                      cells: [
                                        DataCell(Text(r.pid.toString())),
                                        DataCell(Text(r.completion.toString())),
                                        DataCell(Text(r.turnaround.toString())),
                                        DataCell(Text(r.waiting.toString())),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                    const SizedBox(height: 8),
                    if (_results.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Average Waiting Time: ${_avgWT.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Average Turnaround Time: ${_avgTAT.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
