import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/events_provider.dart';
import '../services/cases_provider.dart';
import '../services/auth_provider.dart';
import '../models/index.dart';
import '../l10n/app_localizations.dart';

const uuid = Uuid();

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
        print(
          'CaseDetailScreen: Attempting WebSocket connection for case ${widget.case_.caseId}',
        );
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
          ContractionsAndEventsTab(caseId: widget.case_.caseId),
          DetailsTab(case_: widget.case_),
        ],
      ),
    );
  }
}

// Data class for parsed contractions
class _Contraction {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  _Contraction({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });
}

class ContractionsAndEventsTab extends StatelessWidget {
  final String caseId;

  const ContractionsAndEventsTab({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<EventsProvider>().fetchEvents(caseId),
      child: Consumer<EventsProvider>(
        builder: (context, eventsProvider, _) {
          final events = eventsProvider.getEvents(caseId);

          if (eventsProvider.isLoading && events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No events yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            );
          }

          // Separate contractions from other events
          final contractionEvents = events
              .where(
                (e) =>
                    e.type == 'contraction_start' ||
                    e.type == 'contraction_end',
              )
              .toList();

          final otherEvents =
              events
                  .where(
                    (e) =>
                        e.type != 'contraction_start' &&
                        e.type != 'contraction_end',
                  )
                  .toList()
                ..sort((a, b) => b.ts.compareTo(a.ts)); // Most recent first

          // Group similar events within a time window (5 minutes)
          final groupedEvents = _groupSimilarEvents(
            otherEvents,
            const Duration(minutes: 5),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContractionsTimeline(contractionEvents: contractionEvents),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Other Events',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (groupedEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No other events',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ...groupedEvents.map(
                    (group) => _EventGroupCard(events: group),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Groups similar events within a time window to reduce spam
  List<List<Event>> _groupSimilarEvents(List<Event> events, Duration window) {
    if (events.isEmpty) return [];

    final groups = <List<Event>>[];
    List<Event> currentGroup = [events.first];

    for (int i = 1; i < events.length; i++) {
      final prev = currentGroup.last;
      final curr = events[i];

      // Group if same type+kind and within time window
      final sameType = prev.type == curr.type;
      final sameKind = prev.payload['kind'] == curr.payload['kind'];
      final withinWindow = prev.ts.difference(curr.ts).abs() <= window;

      if (sameType && sameKind && withinWindow) {
        currentGroup.add(curr);
      } else {
        groups.add(currentGroup);
        currentGroup = [curr];
      }
    }
    groups.add(currentGroup);

    return groups;
  }
}

class _ContractionsTimeline extends StatefulWidget {
  final List<Event> contractionEvents;

  const _ContractionsTimeline({required this.contractionEvents});

  @override
  State<_ContractionsTimeline> createState() => _ContractionsTimelineState();
}

class _ContractionsTimelineState extends State<_ContractionsTimeline> {
  int _selectedHours = 8;

  List<_Contraction> _parseContractions(List<Event> events) {
    final contractions = <_Contraction>[];

    for (final event in events) {
      if (event.type == 'contraction_end') {
        final duration = event.payload['duration_s'] as int?;
        if (duration != null) {
          final startTime = event.ts.subtract(Duration(seconds: duration));
          contractions.add(
            _Contraction(
              startTime: startTime,
              endTime: event.ts,
              durationSeconds: duration,
            ),
          );
        }
      }
    }

    contractions.sort((a, b) => a.startTime.compareTo(b.startTime));
    return contractions;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contractions = _parseContractions(widget.contractionEvents);
    final now = DateTime.now();
    final selectedPeriod = now.subtract(Duration(hours: _selectedHours));
    final recentContractions = contractions
        .where((c) => c.startTime.isAfter(selectedPeriod))
        .toList();
    final recentCount = recentContractions.length;

    // Calculate vital stats
    final vitalStats = _calculateVitalStats(recentContractions);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  l10n.contractions,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: recentCount > 12
                        ? Colors.orange.shade100
                        : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l10n.inLastHours(_selectedHours),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: recentCount > 12
                          ? Colors.orange.shade900
                          : Colors.purple.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Timeframe selector
            _TimeframeSelector(
              selectedHours: _selectedHours,
              onChanged: (hours) => setState(() => _selectedHours = hours),
            ),
            const SizedBox(height: 16),

            // Timeline Graph
            if (recentContractions.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _ContractionsGraphPainter(
                    contractions: recentContractions,
                    timeWindowHours: _selectedHours,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Time axis labels
              _TimeAxisLabels(hours: _selectedHours),
              const SizedBox(height: 16),

              // Vital Stats Cards
              _VitalStatsRow(
                stats: vitalStats,
                periodLabel: '${_selectedHours}h',
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    l10n.noContractionsInPeriod,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _VitalStats _calculateVitalStats(List<_Contraction> contractions) {
    if (contractions.isEmpty) {
      return _VitalStats(
        avgDuration: 0,
        avgGapMinutes: 0,
        count: 0,
        durationTrend: 0,
        gapTrend: 0,
      );
    }

    // Calculate averages
    final totalDuration = contractions.fold<int>(
      0,
      (sum, c) => sum + c.durationSeconds,
    );
    final avgDuration = totalDuration ~/ contractions.length;

    // Calculate gaps between contractions
    final gaps = <int>[];
    for (int i = 1; i < contractions.length; i++) {
      final gap = contractions[i].startTime
          .difference(contractions[i - 1].endTime)
          .inSeconds;
      if (gap > 0) gaps.add(gap);
    }
    final avgGapSeconds = gaps.isEmpty
        ? 0
        : gaps.fold<int>(0, (sum, g) => sum + g) ~/ gaps.length;
    final avgGapMinutes = (avgGapSeconds / 60).round();

    // Calculate trends (compare first half vs second half)
    double durationTrend = 0;
    double gapTrend = 0;

    if (contractions.length >= 4) {
      final midpoint = contractions.length ~/ 2;
      final firstHalf = contractions.sublist(0, midpoint);
      final secondHalf = contractions.sublist(midpoint);

      final firstHalfAvgDuration =
          firstHalf.fold<int>(0, (sum, c) => sum + c.durationSeconds) /
          firstHalf.length;
      final secondHalfAvgDuration =
          secondHalf.fold<int>(0, (sum, c) => sum + c.durationSeconds) /
          secondHalf.length;
      durationTrend = secondHalfAvgDuration - firstHalfAvgDuration;

      // Gap trends
      final firstHalfGaps = <int>[];
      for (int i = 1; i < firstHalf.length; i++) {
        firstHalfGaps.add(
          firstHalf[i].startTime.difference(firstHalf[i - 1].endTime).inSeconds,
        );
      }
      final secondHalfGaps = <int>[];
      for (int i = 1; i < secondHalf.length; i++) {
        secondHalfGaps.add(
          secondHalf[i].startTime
              .difference(secondHalf[i - 1].endTime)
              .inSeconds,
        );
      }

      if (firstHalfGaps.isNotEmpty && secondHalfGaps.isNotEmpty) {
        final firstHalfAvgGap =
            firstHalfGaps.fold<int>(0, (sum, g) => sum + g) /
            firstHalfGaps.length;
        final secondHalfAvgGap =
            secondHalfGaps.fold<int>(0, (sum, g) => sum + g) /
            secondHalfGaps.length;
        gapTrend = secondHalfAvgGap - firstHalfAvgGap;
      }
    }

    return _VitalStats(
      avgDuration: avgDuration,
      avgGapMinutes: avgGapMinutes,
      count: contractions.length,
      durationTrend: durationTrend,
      gapTrend: gapTrend,
    );
  }
}

class _VitalStats {
  final int avgDuration;
  final int avgGapMinutes;
  final int count;
  final double durationTrend;
  final double gapTrend;

  _VitalStats({
    required this.avgDuration,
    required this.avgGapMinutes,
    required this.count,
    required this.durationTrend,
    required this.gapTrend,
  });
}

class _VitalStatsRow extends StatelessWidget {
  final _VitalStats stats;
  final String periodLabel;

  const _VitalStatsRow({required this.stats, this.periodLabel = '8h'});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer,
            label: l10n.avgDuration,
            value: '${stats.avgDuration}s',
            trend: stats.durationTrend,
            trendPositiveIsBad:
                false, // Longer contractions are normal progression
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.swap_vert,
            label: l10n.avgGap,
            value: '${stats.avgGapMinutes}min',
            trend: stats.gapTrend / 60, // Convert to minutes
            trendPositiveIsBad: true, // Gaps getting shorter = intensifying
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.repeat,
            label: l10n.frequency,
            value: '${stats.count}',
            subtitle: l10n.inPeriod(periodLabel),
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final double? trend;
  final bool trendPositiveIsBad;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.trend,
    this.trendPositiveIsBad = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget? trendWidget;
    if (trend != null && trend!.abs() > 1) {
      final isUp = trend! > 0;
      final trendColor = (isUp == trendPositiveIsBad)
          ? Colors.orange
          : Colors.green;
      trendWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: trendColor,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.9),
                ),
              ),
              if (subtitle != null)
                Text(
                  ' $subtitle',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              if (trendWidget != null) ...[
                const SizedBox(width: 4),
                trendWidget,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ContractionsGraphPainter extends CustomPainter {
  final List<_Contraction> contractions;
  final int timeWindowHours;

  _ContractionsGraphPainter({
    required this.contractions,
    this.timeWindowHours = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(hours: timeWindowHours));
    final windowDuration = Duration(
      hours: timeWindowHours,
    ).inMilliseconds.toDouble();

    // Draw baseline
    final baselinePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 10),
      Offset(size.width, size.height - 10),
      baselinePaint,
    );

    // Draw hour markers
    for (int i = 0; i <= timeWindowHours; i++) {
      final x = (i / timeWindowHours) * size.width;
      canvas.drawLine(
        Offset(x, size.height - 10),
        Offset(x, size.height - 5),
        baselinePaint,
      );
    }

    // Draw contractions as bars
    for (final contraction in contractions) {
      final startOffset = contraction.startTime
          .difference(windowStart)
          .inMilliseconds
          .toDouble();
      final x = (startOffset / windowDuration) * size.width;

      // Skip if outside visible window
      if (x < 0 || x > size.width) continue;

      // Height based on duration (scale: 30s = 20px, 90s = 60px)
      final maxHeight = size.height - 15;
      final normalizedDuration = contraction.durationSeconds.clamp(20, 120);
      final barHeight = (normalizedDuration / 120) * maxHeight;

      // Color based on duration
      Color barColor;
      if (contraction.durationSeconds >= 60) {
        barColor = Colors.red.shade600;
      } else if (contraction.durationSeconds >= 45) {
        barColor = Colors.orange.shade600;
      } else {
        barColor = Colors.blue.shade600;
      }

      final barPaint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      // Draw bar (width of 4px, centered on x)
      final barRect = Rect.fromLTWH(
        x - 2,
        size.height - 10 - barHeight,
        4,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Widget that displays a group of similar events (clumped within time window)
class _EventGroupCard extends StatelessWidget {
  final List<Event> events;

  const _EventGroupCard({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    // If only one event, show regular card
    if (events.length == 1) {
      return _HumanReadableEventCard(event: events.first);
    }

    // Multiple events - show grouped card
    final first = events.first;
    final dateFormatter = DateFormat('MMM d, HH:mm');

    // Get icon and color from first event
    final icon = _getIconForEvent(first);
    final color = _getIconColorForEvent(first);
    final description = _getDescriptionForEvent(first);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Icon(icon, color: color, size: 24),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${events.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$description (${events.length}x)',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormatter.format(events.last.ts)} - ${dateFormatter.format(first.ts)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  if (_getSeverityForEvent(first) != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getSeverityColorForEvent(first),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getSeverityForEvent(first)!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForEvent(Event event) {
    if (event.type == 'labor_event') {
      final kind = event.payload['kind'];
      switch (kind) {
        case 'waters_breaking':
          return Icons.water_drop;
        case 'bleeding':
        case 'postpartum_bleeding':
          return Icons.bloodtype;
        case 'reduced_fetal_movement':
          return Icons.child_care;
        case 'headache_vision':
          return Icons.visibility_off;
        case 'fever_chills':
          return Icons.thermostat;
        case 'breastfeeding_issues':
          return Icons.child_care;
        case 'mood_changes':
          return Icons.mood_bad;
        case 'wound_pain':
          return Icons.healing;
        case 'leg_pain_swelling':
          return Icons.directions_walk;
        case 'urination_issues':
          return Icons.local_hospital;
        default:
          return Icons.warning_amber;
      }
    }

    switch (event.type) {
      case 'postpartum_checkin':
        return Icons.health_and_safety;
      case 'note':
        return Icons.note;
      default:
        return Icons.event;
    }
  }

  Color _getIconColorForEvent(Event event) {
    final severity = _getSeverityForEvent(event);
    if (severity == 'high') return Colors.red;
    if (severity == 'medium') return Colors.orange;
    if (event.type.contains('postpartum')) return Colors.teal;
    if (event.type.contains('labor')) return Colors.purple;
    return Colors.blue;
  }

  String? _getSeverityForEvent(Event event) {
    if (event.type == 'labor_event') {
      return event.payload['severity'] as String?;
    }
    return null;
  }

  Color _getSeverityColorForEvent(Event event) {
    switch (_getSeverityForEvent(event)) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.blue.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getDescriptionForEvent(Event event) {
    switch (event.type) {
      case 'labor_event':
        final kind = event.payload['kind'] ?? 'unknown';
        return _formatLaborEventKind(kind);
      case 'postpartum_checkin':
        return 'Postpartum check-in';
      case 'note':
        return 'Note';
      default:
        return event.type.replaceAll('_', ' ');
    }
  }

  String _formatLaborEventKind(String kind) {
    switch (kind) {
      case 'waters_breaking':
        return '💧 Waters breaking';
      case 'bleeding':
        return '🩸 Bleeding';
      case 'postpartum_bleeding':
        return '🩸 Heavy bleeding';
      case 'mucus_plug':
        return 'Mucus plug';
      case 'reduced_fetal_movement':
        return '👶 Reduced movement';
      case 'belly_lowering':
        return 'Belly lowering';
      case 'nausea':
        return 'Nausea';
      case 'urge_to_push':
        return '⚠️ Urge to push';
      case 'headache_vision':
        return '👁️ Headache/vision issues';
      case 'fever_chills':
        return '🌡️ Fever/chills';
      case 'breastfeeding_issues':
        return '🍼 Breastfeeding issues';
      case 'mood_changes':
        return '😢 Mood changes';
      case 'wound_pain':
        return '🩹 Wound pain';
      case 'leg_pain_swelling':
        return '🦵 Leg pain/swelling';
      case 'urination_issues':
        return '🚿 Urination issues';
      default:
        return kind.replaceAll('_', ' ');
    }
  }
}

class _HumanReadableEventCard extends StatelessWidget {
  final Event event;

  const _HumanReadableEventCard({required this.event});

  String _getHumanReadableDescription() {
    switch (event.type) {
      case 'labor_event':
        final kind = event.payload['kind'] ?? 'unknown';
        final note = event.payload['note'];
        final kindText = _formatLaborEventKind(kind);
        return note != null && note != 'Reported via app'
            ? '$kindText — $note'
            : kindText;

      case 'postpartum_checkin':
        final items = event.payload['items'] as Map<String, dynamic>?;
        if (items != null) {
          final concerns = <String>[];
          if (items['bleeding'] == 'heavy' || items['bleeding'] == 'moderate') {
            concerns.add('bleeding: ${items['bleeding']}');
          }
          if (items['fever'] == 'yes') concerns.add('fever');
          if (items['headache_vision'] == 'yes') concerns.add('vision issues');
          if (items['pain'] == 'severe' || items['pain'] == 'moderate') {
            concerns.add('pain: ${items['pain']}');
          }

          if (concerns.isEmpty) {
            return 'Postpartum check-in: All good ✓';
          } else {
            return 'Postpartum check-in: ${concerns.join(', ')}';
          }
        }
        return 'Postpartum check-in';

      case 'note':
        return 'Note: ${event.payload['text'] ?? '(empty)'}';

      case 'set_labor_active':
        final active = event.payload['active'] == true;
        return active ? '🔴 Labor started' : '⚪ Labor ended';

      case 'set_postpartum_active':
        final active = event.payload['active'] == true;
        return active
            ? '🟣 Postpartum period started'
            : '⚪ Postpartum period ended';

      case 'alert_ack':
        return '✓ Alert acknowledged';

      case 'alert_resolve':
        return '✓ Alert resolved';

      default:
        return event.type.replaceAll('_', ' ');
    }
  }

  String _formatLaborEventKind(String kind) {
    switch (kind) {
      case 'waters_breaking':
        return '💧 Waters breaking';
      case 'mucus_plug':
        return 'Mucus plug';
      case 'bleeding':
        return '🩸 Bleeding';
      case 'reduced_fetal_movement':
        return '👶 Reduced fetal movement';
      case 'belly_lowering':
        return 'Belly lowering';
      case 'nausea':
        return 'Nausea';
      case 'urge_to_push':
        return '⚠️ Urge to push';
      case 'headache_vision':
        return '👁️ Headache/vision issues';
      case 'fever_chills':
        return '🌡️ Fever/chills';
      default:
        return kind.replaceAll('_', ' ');
    }
  }

  String? _getSeverity() {
    if (event.type == 'labor_event') {
      return event.payload['severity'] as String?;
    }
    return null;
  }

  Color _getSeverityColor() {
    switch (_getSeverity()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.blue.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon() {
    if (event.type == 'labor_event') {
      final kind = event.payload['kind'];
      switch (kind) {
        case 'waters_breaking':
          return Icons.water_drop;
        case 'bleeding':
          return Icons.bloodtype;
        case 'reduced_fetal_movement':
          return Icons.child_care;
        case 'headache_vision':
          return Icons.visibility_off;
        case 'fever_chills':
          return Icons.thermostat;
        case 'urge_to_push':
          return Icons.warning;
        default:
          return Icons.warning_amber;
      }
    }

    switch (event.type) {
      case 'postpartum_checkin':
        return Icons.health_and_safety;
      case 'note':
        return Icons.note;
      case 'set_labor_active':
        return Icons.play_circle;
      case 'set_postpartum_active':
        return Icons.favorite;
      default:
        return Icons.event;
    }
  }

  Color _getIconColor() {
    final severity = _getSeverity();
    if (severity == 'high') return Colors.red;
    if (severity == 'medium') return Colors.orange;

    if (event.type.contains('postpartum')) return Colors.pink;
    if (event.type.contains('labor')) return Colors.purple;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, HH:mm');
    final description = _getHumanReadableDescription();
    final severity = _getSeverity();

    // Check if this event already has a reaction
    final eventsProvider = context.watch<EventsProvider>();
    final allEvents = eventsProvider.getEvents(event.caseId);
    final hasReaction = allEvents.any((e) =>
        e.type == 'midwife_reaction' &&
        e.payload['event_id'] == event.eventId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_getIcon(), color: _getIconColor(), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateFormatter.format(event.ts),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          if (severity != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getSeverityColor(),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                severity.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Add reaction buttons if patient event
            if (_shouldShowReactions() && !hasReaction) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              _ReactionButtons(event: event),
            ],
            // Show existing reaction
            if (hasReaction) ...[
              const SizedBox(height: 8),
              _ExistingReaction(
                reaction: allEvents.firstWhere((e) =>
                    e.type == 'midwife_reaction' &&
                    e.payload['event_id'] == event.eventId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _shouldShowReactions() {
    // Only show reactions for patient-reported events
    return event.source == 'woman' &&
        (event.type == 'labor_event' || event.type == 'postpartum_checkin');
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
      onRefresh: () =>
          context.read<EventsProvider>().fetchEvents(widget.caseId),
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
                  Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
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

class DetailsTab extends StatefulWidget {
  final Case case_;

  const DetailsTab({super.key, required this.case_});

  @override
  State<DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<DetailsTab> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final casesProvider = context.watch<CasesProvider>();

    // Get latest case data from provider
    final case_ =
        casesProvider.getCaseById(widget.case_.caseId) ?? widget.case_;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailCard(context, 'Case ID', case_.caseId),
          const SizedBox(height: 12),

          // Mode selector card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.caseMode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeButton(
                          label: l10n.laborMode,
                          icon: Icons.pregnant_woman,
                          isActive: case_.laborActive,
                          color: Colors.purple,
                          isLoading: _isUpdating,
                          onTap: () => _switchToLabor(case_),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModeButton(
                          label: l10n.postpartumMode,
                          icon: Icons.child_friendly,
                          isActive: case_.postpartumActive,
                          color: Colors.teal,
                          isLoading: _isUpdating,
                          onTap: () => _switchToPostpartum(case_),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _buildDetailCard(
            context,
            'Active Alerts',
            case_.activeAlerts.toString(),
          ),
          const SizedBox(height: 24),

          // Close case button
          if (!case_.isClosed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCloseConfirmation(context, case_),
                icon: const Icon(Icons.close),
                label: Text(l10n.closeCase),
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

  Future<void> _switchToLabor(Case case_) async {
    if (case_.laborActive) return; // Already in labor mode

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.switchToLabor),
        content: Text(l10n.switchToLaborConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isUpdating = true);
      final casesProvider = context.read<CasesProvider>();

      // Disable postpartum and enable labor
      if (case_.postpartumActive) {
        await casesProvider.setPostpartumMode(case_.caseId, false);
      }
      await casesProvider.setLaborMode(case_.caseId, true);

      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _switchToPostpartum(Case case_) async {
    if (case_.postpartumActive) return; // Already in postpartum mode

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.switchToPostpartum),
        content: Text(l10n.switchToPostpartumConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isUpdating = true);
      final casesProvider = context.read<CasesProvider>();

      // Disable labor and enable postpartum
      if (case_.laborActive) {
        await casesProvider.setLaborMode(case_.caseId, false);
      }
      await casesProvider.setPostpartumMode(case_.caseId, true);

      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showCloseConfirmation(BuildContext context, Case case_) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.closeCase),
        content: Text(l10n.closeCaseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CasesProvider>().closeCase(case_.caseId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (isLoading)
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )
            else
              Icon(icon, size: 32, color: isActive ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? color : Colors.grey.shade700,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeframeSelector extends StatelessWidget {
  final int selectedHours;
  final ValueChanged<int> onChanged;

  const _TimeframeSelector({
    required this.selectedHours,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = [1, 2, 4, 8];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((hours) {
        final isSelected = hours == selectedHours;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text('${hours}h'),
            selected: isSelected,
            onSelected: (_) => onChanged(hours),
            selectedColor: Colors.purple.shade100,
            labelStyle: TextStyle(
              color: isSelected ? Colors.purple.shade900 : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeAxisLabels extends StatelessWidget {
  final int hours;

  const _TimeAxisLabels({required this.hours});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    List<String> labels;
    switch (hours) {
      case 1:
        labels = ['60m', '45m', '30m', '15m', l10n.now];
        break;
      case 2:
        labels = ['2h', '1.5h', '1h', '30m', l10n.now];
        break;
      case 4:
        labels = ['4h', '3h', '2h', '1h', l10n.now];
        break;
      case 8:
      default:
        labels = ['8h', '6h', '4h', '2h', l10n.now];
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((label) {
        final isNow = label == l10n.now;
        return Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}

class _ReactionButtons extends StatelessWidget {
  final Event event;

  const _ReactionButtons({required this.event});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _ReactionChip(
          label: '✓ Ack',
          reaction: 'ack',
          event: event,
          color: Colors.blue,
        ),
        _ReactionChip(
          label: '🚗 Coming',
          reaction: 'coming',
          event: event,
          color: Colors.orange,
        ),
        _ReactionChip(
          label: '👍 OK',
          reaction: 'ok',
          event: event,
          color: Colors.green,
        ),
        _ReactionChip(
          label: '👁 Seen',
          reaction: 'seen',
          event: event,
          color: Colors.grey,
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String label;
  final String reaction;
  final Event event;
  final Color color;

  const _ReactionChip({
    required this.label,
    required this.reaction,
    required this.event,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _sendReaction(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _sendReaction(BuildContext context) async {
    final eventsProvider = context.read<EventsProvider>();

    // Create reaction event
    final reactionEvent = Event(
      eventId: uuid.v4(),
      caseId: event.caseId,
      type: 'midwife_reaction',
      ts: DateTime.now().toUtc(),
      serverTs: DateTime.now().toUtc(),
      track: 'meta',
      source: 'midwife',
      payloadVersion: 1,
      payload: {
        'event_id': event.eventId,
        'reaction': reaction,
      },
    );

    // Send via WebSocket
    eventsProvider.sendMessage(event.caseId, {
      'type': 'event',
      'event': reactionEvent.toJson(),
    });
  }
}

class _ExistingReaction extends StatelessWidget {
  final Event reaction;

  const _ExistingReaction({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final reactionType = reaction.payload['reaction'] as String?;
    final emoji = _getReactionEmoji(reactionType);
    final label = _getReactionLabel(reactionType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Text(
            'Midwife: $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }

  String _getReactionEmoji(String? reaction) {
    switch (reaction) {
      case 'ack':
        return '✓';
      case 'coming':
        return '🚗';
      case 'ok':
        return '👍';
      case 'seen':
        return '👁';
      default:
        return '✓';
    }
  }

  String _getReactionLabel(String? reaction) {
    switch (reaction) {
      case 'ack':
        return 'Acknowledged';
      case 'coming':
        return "I'm coming";
      case 'ok':
        return "It's OK";
      case 'seen':
        return 'Seen';
      default:
        return 'Acknowledged';
    }
  }
}
