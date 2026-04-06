import 'package:flutter/material.dart';

import '../../models/simulation_history_entry.dart';
import '../../utils/history_storage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SimulationHistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await HistoryStorage.readAll();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear History'),
          content: const Text('Delete all saved simulation history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await HistoryStorage.clear();
    await _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared')),
    );
  }

  void _showDetails(SimulationHistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                    'Run Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Time Quantum: ${entry.quantum}'),
                  Text('Saved: ${entry.createdAt.toLocal()}'),
                  const SizedBox(height: 12),
                  Text(
                    'Input Processes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('PID')),
                        DataColumn(label: Text('AT')),
                        DataColumn(label: Text('BT')),
                      ],
                      rows: entry.inputProcesses
                          .map(
                            (p) => DataRow(
                              cells: [
                                DataCell(Text(p.id.toString())),
                                DataCell(Text(p.arrival.toString())),
                                DataCell(Text(p.burst.toString())),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Results',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('PID')),
                        DataColumn(label: Text('CT')),
                        DataColumn(label: Text('TAT')),
                        DataColumn(label: Text('WT')),
                      ],
                      rows: entry.results
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
                  Text(
                    'Average Waiting Time: ${entry.averageWaitingTime.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Average Turnaround Time: ${entry.averageTurnaroundTime.toStringAsFixed(2)}',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
            const Text('Simulation History'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear History',
            onPressed: _entries.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Text('No history yet. Run a simulation to save results.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            'Run #${_entries.length - index}  •  QT ${entry.quantum}',
                          ),
                          subtitle: Text(
                            'Avg WT: ${entry.averageWaitingTime.toStringAsFixed(2)}  |  Avg TAT: ${entry.averageTurnaroundTime.toStringAsFixed(2)}\n'
                            '${entry.inputProcesses.length} processes  •  ${entry.createdAt.toLocal()}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showDetails(entry),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}