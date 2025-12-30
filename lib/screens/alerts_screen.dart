import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/alert.dart';
import '../services/alerts_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AlertsProvider>().fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Inbox'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AlertsProvider>().fetchAlerts(),
        child: Consumer<AlertsProvider>(
          builder: (context, alertsProvider, _) {
            final alerts = alertsProvider.activeAlerts;

            if (alertsProvider.isLoading && alerts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (alerts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active alerts',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All cases are in good standing',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: alerts.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return AlertCard(alert: alert);
              },
            );
          },
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final Alert alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, HH:mm');
    final severityColor = _getSeverityColor(alert.severity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: severityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.alertCode,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Chip(
                  label: Text(alert.severity.toUpperCase()),
                  backgroundColor: severityColor,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.explain.summary,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  dateFormatter.format(alert.event.ts),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const Spacer(),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<AlertsProvider>().acknowledgeAlert(
                            alert.event.caseId,
                            alert.event.eventId,
                          );
                    },
                    icon: const Icon(Icons.done, size: 16),
                    label: const Text('Ack'),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<AlertsProvider>().resolveAlert(
                            alert.event.caseId,
                            alert.event.eventId,
                          );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Resolve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
