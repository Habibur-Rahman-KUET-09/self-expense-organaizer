import 'package:flutter/material.dart';

/// Temporary stand-in for the Reports tab, replaced in Step 4d.
class ReportsPlaceholderScreen extends StatelessWidget {
  const ReportsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(child: Text('Reports screen coming in Step 4d.')),
    );
  }
}
