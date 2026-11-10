import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/quiz_statistics.dart';
import '../../data/repositories/quiz_repository.dart';

class QuizStatisticsScreen extends StatefulWidget {
  const QuizStatisticsScreen({super.key});

  @override
  State<QuizStatisticsScreen> createState() => _QuizStatisticsScreenState();
}

class _QuizStatisticsScreenState extends State<QuizStatisticsScreen> {
  late Future<QuizStatistics> _statistics;

  @override
  void initState() {
    super.initState();
    _statistics = context.read<QuizRepository>().statistics();
  }

  Future<void> _reload() async {
    final request = context.read<QuizRepository>().statistics();
    setState(() {
      _statistics = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder displays the error with a retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<QuizStatistics>(
              future: _statistics,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data;
                if (data == null) {
                  final error = snapshot.error;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorBanner(
                      message: error is ApiException
                          ? error.message
                          : 'Không thể tải thống kê.',
                      action: TextButton(
                        onPressed: _reload,
                        child: const Text('Thử lại'),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Tiến trình học tập và hiệu suất theo môn/bộ đề',
                      ),
                      const SizedBox(height: 16),
                      _overview(context, data),
                      const SizedBox(height: 16),
                      _StatisticsSection(
                        title: 'Biểu đồ 12 lần làm gần nhất',
                        child: data.recentScores.length < 2
                            ? const Text(
                                'Cần ít nhất 2 lần làm bài để vẽ biểu đồ.',
                              )
                            : _ScoreChart(scores: data.recentScores),
                      ),
                      const SizedBox(height: 12),
                      _groupSection('Theo môn học', data.subjectStats),
                      const SizedBox(height: 12),
                      _groupSection(
                        'Theo bộ đề',
                        data.deckStats,
                        showLastAttempt: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(BuildContext context, QuizStatistics data) {
    final success = context.isDark
        ? AppDarkColors.success
        : AppLightColors.success;
    final theme = Theme.of(context);
    final metrics = [
      ('Số bài đã làm', '${data.totalAttempts}', context.accentColor),
      ('Điểm trung bình', _percent(data.averagePercentage), context.cyanColor),
      ('Tốt nhất', _percent(data.bestPercentage), success),
      (
        'Tỷ lệ đạt',
        _percent(data.passRate),
        data.passRate >= 50 ? success : theme.colorScheme.error,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 4 : (width >= 260 ? 2 : 1);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (label, value, color) in metrics)
              SizedBox(
                width: (width - (columns - 1) * spacing) / columns,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(value, style: theme.textTheme.headlineSmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _groupSection(
    String title,
    List<QuizPerformanceGroup> groups, {
    bool showLastAttempt = false,
  }) {
    return _StatisticsSection(
      title: title,
      child: groups.isEmpty
          ? const Text('Chưa có dữ liệu.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, group) in groups.indexed) ...[
                  if (index > 0) const Divider(height: 20),
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.attempts} lượt · TB ${_percent(group.averagePercentage)} · '
                    '${showLastAttempt ? 'Gần nhất ${_lastAttempt(group.lastAttemptAt)}' : 'Tốt nhất ${_percent(group.bestPercentage)}'}',
                  ),
                ],
              ],
            ),
    );
  }
}

String _percent(double value) =>
    '${value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%';

String _lastAttempt(DateTime date) {
  final vietnamTime = date.toUtc().add(const Duration(hours: 7));
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(vietnamTime.day)}/${twoDigits(vietnamTime.month)} '
      '${twoDigits(vietnamTime.hour)}:${twoDigits(vietnamTime.minute)}';
}

class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.scores});

  final List<QuizScorePoint> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = scores
        .map((point) => '${point.label} · ${_percent(point.percentage)}')
        .join('\n');
    return Tooltip(
      message: details,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _ScoreChartPainter(
                scores: scores,
                gridColor: theme.colorScheme.outlineVariant,
                lineColor: context.cyanColor,
                labelStyle: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(scores.first.label, style: theme.textTheme.labelSmall),
              Text(scores.last.label, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  const _ScoreChartPainter({
    required this.scores,
    required this.gridColor,
    required this.lineColor,
    required this.labelStyle,
    required this.textScaler,
  });

  final List<QuizScorePoint> scores;
  final Color gridColor;
  final Color lineColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final labels = [
      for (final percentage in [100, 75, 50, 25, 0])
        TextPainter(
          text: TextSpan(text: '$percentage%', style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(),
    ];
    final left = labels.first.width + 8;
    final right = size.width - 4;
    final top = labels.first.height / 2 + 4;
    final bottom = size.height - top;
    final grid = Paint()..color = gridColor;
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2;
    final dot = Paint()..color = lineColor;

    for (final (index, label) in labels.indexed) {
      final y = top + (bottom - top) * index / (labels.length - 1);
      label.paint(canvas, Offset(left - 8 - label.width, y - label.height / 2));
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
      label.dispose();
    }

    Offset? previous;
    for (final (index, score) in scores.indexed) {
      final point = Offset(
        left + (right - left) * index / (scores.length - 1),
        bottom - (bottom - top) * score.percentage.clamp(0, 100) / 100,
      );
      if (previous != null) canvas.drawLine(previous, point, line);
      canvas.drawCircle(point, 3, dot);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(_ScoreChartPainter oldDelegate) =>
      oldDelegate.scores != scores ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler;
}
