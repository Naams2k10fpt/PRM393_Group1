import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/quiz_repository.dart';
import '../../data/api/api_exception.dart';
import '../auth/auth_controller.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final QuizRepository repo = context.read<QuizRepository>();
  late final String draftKey =
      'quiz_draft_${context.read<AuthController>().user!.id}';
  List<QuizSubject> subjects = [];
  List<QuizDeck> decks = [];
  List<QuizHistoryItem> history = [];
  int? subjectId;
  QuizDeck? deck;
  int count = 10;
  int historyPage = 1;
  int historyTotal = 0;
  bool busy = false;
  bool submitting = false;
  bool autoSubmitted = false;
  String? error;
  QuizAttempt? attempt;
  QuizResult? result;
  int questionIndex = 0;
  final selected = <int, Set<int>>{};
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final values = await Future.wait([repo.subjects(), repo.history(1)]);
      if (!mounted) return;
      final page = values[1] as QuizHistoryPage;
      setState(() {
        subjects = values[0] as List<QuizSubject>;
        history = page.items;
        historyTotal = page.totalCount;
        historyPage = 1;
      });
      await _resume();
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resume() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final resumed = await repo.resume(
        saved['attemptId'] as String,
        saved['deckId'] as int,
      );
      if (!mounted) return;
      selected.clear();
      for (final entry in (saved['answers'] as Map<String, dynamic>).entries) {
        selected[int.parse(entry.key)] =
            (entry.value as List).cast<int>().toSet();
      }
      setState(() {
        attempt = resumed;
        result = null;
        questionIndex = 0;
      });
      _startTicker();
    } on ApiException catch (e) {
      if (e.code == 'attempt_not_found' || e.code == 'attempt_expired') {
        await prefs.remove(draftKey);
      } else if (mounted) {
        setState(() => error = e.message);
      }
    } catch (_) {
      await prefs.remove(draftKey);
    }
  }

  Future<void> _saveDraft() async {
    final current = attempt;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      draftKey,
      jsonEncode({
        'attemptId': current.id,
        'deckId': current.deckId,
        'answers': selected.map(
          (key, value) => MapEntry('$key', value.toList()),
        ),
      }),
    );
  }

  void _startTicker() {
    ticker?.cancel();
    if (attempt?.expiresAt == null) return;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || attempt == null || result != null) return;
      setState(() {});
      if (_remaining == Duration.zero && !autoSubmitted) {
        autoSubmitted = true;
        _submit();
      }
    });
  }

  Duration get _remaining {
    final expiry = attempt?.expiresAt;
    if (expiry == null) return Duration.zero;
    final left = expiry.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _selectSubject(int? id) async {
    setState(() {
      subjectId = id;
      deck = null;
      decks = [];
    });
    if (id == null) return;
    try {
      final loaded = await repo.decks(id);
      if (mounted && subjectId == id) setState(() => decks = loaded);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _start() async {
    if (deck == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final started = await repo.start(deck!.id, count);
      if (!mounted) return;
      selected.clear();
      autoSubmitted = false;
      setState(() {
        attempt = started;
        result = null;
        questionIndex = 0;
      });
      await _saveDraft();
      _startTicker();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    if (attempt == null || submitting) return;
    setState(() => submitting = true);
    try {
      final finished = await repo.submit(attempt!, selected);
      await (await SharedPreferences.getInstance()).remove(draftKey);
      ticker?.cancel();
      if (!mounted) return;
      setState(() {
        result = finished;
        attempt = null;
      });
      final page = await repo.history(1);
      if (mounted) {
        setState(() {
          history = page.items;
          historyPage = 1;
          historyTotal = page.totalCount;
        });
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _confirmSubmit() async {
    final unanswered =
        attempt!.questions.where((q) => selected[q.id]?.isEmpty ?? true).length;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nộp bài?'),
            content: Text(
              unanswered == 0
                  ? 'Bạn muốn nộp bài bây giờ?'
                  : 'Còn $unanswered câu chưa trả lời. Vẫn nộp bài?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tiếp tục làm'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Nộp bài'),
              ),
            ],
          ),
    );
    if (yes == true) _submit();
  }

  Future<void> _moreHistory() async {
    try {
      final page = await repo.history(historyPage + 1);
      if (mounted) {
        setState(() {
          history.addAll(page.items);
          historyPage++;
        });
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openResult(int id) async {
    try {
      final loaded = await repo.result(id);
      if (mounted) setState(() => result = loaded);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          result != null
              ? 'Kết quả'
              : attempt != null
              ? 'Làm bài'
              : 'Quiz cá nhân',
        ),
      ),
      body:
          busy && attempt == null && result == null
              ? const Center(child: CircularProgressIndicator())
              : result != null
              ? _resultView()
              : attempt != null
              ? _attemptView()
              : _entryView(),
    );
  }

  Widget _entryView() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const Text(
          'Bắt đầu bài thi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: subjectId,
          decoration: const InputDecoration(labelText: 'Môn học'),
          items:
              subjects
                  .map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  )
                  .toList(),
          onChanged: _selectSubject,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(subjectId),
          initialValue: deck?.id,
          decoration: const InputDecoration(labelText: 'Bộ đề'),
          items:
              decks
                  .where((d) => d.questionCount > 0)
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text('${d.name} · ${d.questionCount} câu'),
                    ),
                  )
                  .toList(),
          onChanged:
              (id) => setState(() {
                deck = decks.where((d) => d.id == id).firstOrNull;
                count =
                    deck == null
                        ? 10
                        : (deck!.questionCount < 10 ? deck!.questionCount : 10);
              }),
        ),
        if (deck != null) ...[
          const SizedBox(height: 12),
          Text(
            'Thời gian: ${deck!.timeLimitMinutes == null || deck!.timeLimitMinutes == 0 ? 'Không giới hạn' : '${deck!.timeLimitMinutes} phút'}',
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(deck!.id),
            initialValue: '$count',
            decoration: InputDecoration(
              labelText:
                  'Số câu (1–${deck!.questionCount < 500 ? deck!.questionCount : 500})',
            ),
            keyboardType: TextInputType.number,
            onChanged:
                (value) => setState(() => count = int.tryParse(value) ?? 0),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                busy || count < 1 || count > deck!.questionCount || count > 500
                    ? null
                    : _start,
            child: const Text('Bắt đầu'),
          ),
        ],
        const SizedBox(height: 32),
        const Text(
          'Lịch sử làm bài',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có bài làm.'),
          ),
        for (final item in history)
          Card(
            child: ListTile(
              title: Text(item.deckName),
              subtitle: Text(
                '${item.subjectName} · ${item.createdAt.toLocal().day}/${item.createdAt.toLocal().month}/${item.createdAt.toLocal().year}',
              ),
              trailing: Text('${item.percentage.toStringAsFixed(0)}%'),
              onTap: () => _openResult(item.id),
            ),
          ),
        if (history.length < historyTotal)
          TextButton(onPressed: _moreHistory, child: const Text('Xem thêm')),
      ],
    ),
  );

  Widget _attemptView() {
    final quiz = attempt!;
    final question = quiz.questions[questionIndex];
    final answers = selected[question.id] ?? <int>{};
    final left = _remaining;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          quiz.deckName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (quiz.expiresAt != null)
          Text(
            'Còn ${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color:
                  left.inSeconds < 60
                      ? Theme.of(context).colorScheme.error
                      : null,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < quiz.questions.length; i++)
              ActionChip(
                label: Text('${i + 1}'),
                backgroundColor:
                    i == questionIndex
                        ? Theme.of(context).colorScheme.primary
                        : null,
                avatar:
                    selected[quiz.questions[i].id]?.isNotEmpty == true
                        ? const Icon(Icons.check, size: 16)
                        : null,
                onPressed: () => setState(() => questionIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Câu ${questionIndex + 1}/${quiz.questions.length}: ${question.content}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (question.multiple) const Text('Chọn nhiều đáp án'),
        const SizedBox(height: 12),
        for (final (i, answer) in question.answers.indexed)
          Card(
            child: CheckboxListTile(
              title: Text('${String.fromCharCode(65 + i)}. ${answer.content}'),
              value: answers.contains(answer.id),
              onChanged:
                  submitting
                      ? null
                      : (checked) {
                        setState(() {
                          if (!question.multiple) answers.clear();
                          if (checked == true) {
                            answers.add(answer.id);
                          } else {
                            answers.remove(answer.id);
                          }
                          selected[question.id] = answers;
                        });
                        _saveDraft();
                      },
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    questionIndex == 0
                        ? null
                        : () => setState(() => questionIndex--),
                child: const Text('Trước'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    questionIndex == quiz.questions.length - 1
                        ? null
                        : () => setState(() => questionIndex++),
                child: const Text('Tiếp'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: submitting ? null : _confirmSubmit,
          child: Text(submitting ? 'Đang nộp...' : 'Nộp bài'),
        ),
      ],
    );
  }

  Widget _resultView() {
    final data = result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          data.deckName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          '${data.subjectName} · ${data.score.toStringAsFixed(1)}/10 điểm · ${data.correctCount}/${data.totalCount} câu đúng · ${data.percentage.toStringAsFixed(0)}%',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => result = null),
          child: const Text('Về danh sách'),
        ),
        for (var i = 0; i < data.questions.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Câu ${i + 1}: ${data.questions[i].content}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data.questions[i].isCorrect ? 'Đúng' : 'Sai',
                    style: TextStyle(
                      color:
                          data.questions[i].isCorrect
                              ? Colors.greenAccent
                              : Colors.redAccent,
                    ),
                  ),
                  for (final answer in data.questions[i].answers)
                    Row(
                      children: [
                        Icon(
                          answer.isCorrect
                              ? Icons.check_circle
                              : answer.wasSelected
                              ? Icons.cancel
                              : Icons.circle_outlined,
                          size: 18,
                          color:
                              answer.isCorrect
                                  ? Colors.greenAccent
                                  : answer.wasSelected
                                  ? Colors.redAccent
                                  : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${answer.content}${answer.wasSelected ? ' (đã chọn)' : ''}',
                          ),
                        ),
                      ],
                    ),
                  if (data.questions[i].explanation?.isNotEmpty == true)
                    Text('Giải thích: ${data.questions[i].explanation}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
