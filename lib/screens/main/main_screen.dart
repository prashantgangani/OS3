// lib/screens/main/main_screen.dart

import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scheduler'),
          bottom: const TabBar(tabs: [Tab(text: 'Input'), Tab(text: 'Simulation'), Tab(text: 'Results')]),
        ),
        body: const TabBarView(children: [Center(child: Text('Input tab')), Center(child: Text('Simulation tab')), Center(child: Text('Results tab'))]),
      ),
    );
  }
}
