import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/events_provider.dart';
import '../services/cases_provider.dart';
import '../services/auth_provider.dart';
import '../models/index.dart';

class CaseDetailScreen extends StatefulWidget {
  final Case case_;

  const CaseDetailScreen({super.key, required this.case_});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _token;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      context.read<EventsProvider>().fetchEvents(widget.case_.caseId);
      
      // Get the midwife token and connect to WebSocket
      final auth = context.read<AuthProvider>();
      _token = auth.token ?? '';
      print('CaseDetailScreen: Token available: ${_token.isNotEmpty}');
      if (_token.isNotEmpty) {
        print('CaseDetailScreen: Attempting WebSocket connection for case ${widget.case_.caseId}');
        try {
          await context.read<EventsProvider>().connectWebSocket(
            widget.case_.caseId,
            _token,
          );
          print('CaseDetailScreen: WebSocket connection initiated');
        } catch (e) {
          print('CaseDetailScreen: WebSocket connection failed: $e');
        }
      } else {
        print('CaseDetailScreen: No token available for WebSocket connection');
      }
    });
  }

  @override
  void dispose() {
    context.read<EventsProvider>().disconnectWebSocket(widget.case_.caseId);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final ws = eventsProvider.getWebSocketFor(widget.case_.caseId);
    final wsConnected = ws?.isConnected ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.case_.displayLabel),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    wsConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: wsConnected ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wsConnected ? 'Live' : 'Offline',
                    style: TextStyle(
                      color: wsConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Events'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          EventsTab(caseId: widget.case_.caseId),
          DetailsTab(case_: widget.case_),
        ],
      ),
    );
  }
}

class EventsTab extends StatefulWidget {
  final String caseId;

  const EventsTab({super.key, required this.caseId});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  late ScrollController _scrollController;
  int _lastEventCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<EventsProvider>().fetchEvents(widget.caseId),
      child: Consumer<EventsProvider>(
        builder: (context, eventsProvider, _) {
          final events = eventsProvider.getEvents(widget.caseId);

          // Auto-scroll to bottom when new events arrive
          if (events.length > _lastEventCount) {
            _lastEventCount = events.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }

          if (eventsProvider.isLoading && events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_note,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No events yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            itemCount: events.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final event = events[index];
              return EventCard(event: event);
            },
          );
        },
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, HH:mm:ss');
    final color = _getColorForEventType(event.type);

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
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.type,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  dateFormatter.format(event.ts),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (event.payload.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.payload.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Source: ${event.source} | Track: ${event.track}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForEventType(String type) {
    if (type.contains('contraction')) return Colors.purple;
    if (type.contains('labor')) return Colors.red;
    if (type.contains('postpartum')) return Colors.orange;
    if (type.contains('alert')) return Colors.yellow[700]!;
    return Colors.blue;
  }
}

class DetailsTab extends StatelessWidget {
  final Case case_;

  const DetailsTab({super.key, required this.case_});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailCard(
            context,
            'Case ID',
            case_.caseId,
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            context,
            'Status',
            case_.isClosed
                ? 'Closed'
                : '${case_.laborActive ? 'Labor' : ''} ${case_.postpartumActive ? 'Postpartum' : ''}'.trim(),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            context,
            'Active Alerts',
            case_.activeAlerts.toString(),
          ),
          const SizedBox(height: 24),
          if (!case_.isClosed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showCloseConfirmation(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('Close Case'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  void _showCloseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Case'),
        content: const Text('Are you sure you want to close this case?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CasesProvider>().closeCase(case_.caseId);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
