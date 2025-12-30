import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/cases_provider.dart';
import '../services/alerts_provider.dart';
import '../services/auth_provider.dart';
import '../models/index.dart';
import 'claim_case_screen.dart';

class CasesListScreen extends StatefulWidget {
  const CasesListScreen({super.key});

  @override
  State<CasesListScreen> createState() => _CasesListScreenState();
}

class _CasesListScreenState extends State<CasesListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<CasesProvider>().fetchCases();
      context.read<AlertsProvider>().fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Cases'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).pushNamed('/alerts');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout().then((_) {
                Navigator.of(context).pushReplacementNamed('/login');
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<CasesProvider>().fetchCases(),
        child: Consumer<CasesProvider>(
          builder: (context, casesProvider, _) {
            if (casesProvider.isLoading && casesProvider.cases.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (casesProvider.cases.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active cases',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new case to get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: casesProvider.cases.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                final case_ = casesProvider.cases[index];
                return CaseCard(case_: case_);
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClaimCaseScreen()),
              );
            },
            tooltip: 'Claim patient case',
            heroTag: 'claim',
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              context.read<CasesProvider>().createCase();
            },
            tooltip: 'Create new case',
            heroTag: 'create',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class CaseCard extends StatelessWidget {
  final Case case_;

  const CaseCard({super.key, required this.case_});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, HH:mm');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: case_.laborActive ? Colors.red : Colors.orange,
          ),
        ),
        title: Text(case_.displayLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              case_.lastEventTs != null
                  ? 'Last event: ${dateFormatter.format(case_.lastEventTs!)}'
                  : 'No events yet',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (case_.laborActive) _buildStatusChip('Labor', Colors.red),
                const SizedBox(width: 4),
                if (case_.postpartumActive) _buildStatusChip('Postpartum', Colors.orange),
                if (!case_.laborActive && !case_.postpartumActive)
                  _buildStatusChip('Closed', Colors.grey),
                const Spacer(),
                if (case_.activeAlerts > 0)
                  Badge(
                    label: Text(case_.activeAlerts.toString()),
                    backgroundColor: Colors.red,
                  ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).pushNamed('/case-detail', arguments: case_);
        },
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}
