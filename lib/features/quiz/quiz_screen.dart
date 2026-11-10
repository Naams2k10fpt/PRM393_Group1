import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_router.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/api/api_exception.dart';
import '../auth/auth_controller.dart';
import 'quiz_content.dart';
import 'report_question_dialog.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.initialSubjectId, this.initialDeckId});
  final int? initialSubjectId, initialDeckId;

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
  bool resumeBlocked = false;
  bool loadingHistory = false;
  bool confirming = false;
  bool openingResult = false;
  Future<void> draftWrites = Future.value();
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
      subjectId = null;
      deck = null;
      decks = [];
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
      if (mounted &&
          attempt == null &&
          !resumeBlocked &&
          widget.initialSubjectId != null) {
        await _selectSubject(widget.initialSubjectId);
        if (mounted) {
          setState(() {
            deck = decks.where((d) => d.id == widget.initialDeckId).firstOrNull;
            if (deck != null) count = deck!.questionCount.clamp(1, 10);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resume() async {
    resumeBlocked = false;
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
        autoSubmitted = false;
      });
      _startTicker();
    } on ApiException catch (e) {
      if (e.code == 'attempt_not_found' || e.code == 'attempt_expired') {
        await prefs.remove(draftKey);
      } else if (mounted) {
        setState(() {
          resumeBlocked = true;
          error = 'Chưa thể khôi phục bài đang làm. ${e.message}';
        });
      }
    } catch (_) {
      await prefs.remove(draftKey);
    }
  }

  Future<void> _saveDraft() {
    final current = attempt;
    if (current == null) return Future.value();
    // Capture answers before awaiting storage; queue removal after every save.
    return _writeDraft(
      jsonEncode({
        'attemptId': current.id,
        'deckId': current.deckId,
        'answers': selected.map(
          (key, value) => MapEntry('$key', value.toList()),
        ),
      }),
    );
  }

  Future<void> _writeDraft(String? value) {
    final key = draftKey;
    final write = draftWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    });
    draftWrites = write.catchError((Object _) {});
    return write;
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
    if (deck == null || busy || resumeBlocked) return;
    await _begin(deck!.id, count);
  }

  Future<void> _begin(int deckId, int questionCount) async {
    if (busy || resumeBlocked) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final started = await repo.start(deckId, questionCount);
      if (!mounted) return;
      selected.clear();
      autoSubmitted = false;
      setState(() {
        attempt = started;
        result = null;
        questionIndex = 0;
      });
      _startTicker();
      await _saveDraft();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    if (attempt == null || submitting) return;
    if (confirming) Navigator.of(context).pop(false);
    setState(() => submitting = true);
    try {
      final finished = await repo.submit(attempt!, selected);
      ticker?.cancel();
      if (!mounted) return;
      setState(() {
        result = finished;
        attempt = null;
      });
      // A storage failure must not hide a result already accepted by the server.
      await _writeDraft(null).catchError(_showError);
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
    if (attempt == null || submitting || confirming) return;
    confirming = true;
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Tiếp tục làm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Nộp bài'),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
    confirming = false;
    if (yes == true && mounted) _submit();
  }

  Future<void> _moreHistory() async {
    if (loadingHistory) return;
    setState(() => loadingHistory = true);
    try {
      final page = await repo.history(historyPage + 1);
      if (mounted) {
        setState(() {
          history.addAll(page.items);
          historyPage++;
          historyTotal = page.totalCount;
        });
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => loadingHistory = false);
    }
  }

  Future<void> _openResult(int id) async {
    if (openingResult) return;
    setState(() => openingResult = true);
    try {
      final loaded = await repo.result(id);
      if (mounted) setState(() => result = loaded);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => openingResult = false);
    }
  }

  Future<void> _report(QuizResult data, QuizResultQuestion question) async {
    final sent = await showDialog<bool>(
      context: context,
      builder:
          (_) => ReportQuestionDialog(
            repo: repo,
            historyId: data.historyId,
            questionId: question.id,
          ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi báo cáo. Cảm ơn bạn đã đóng góp!'),
        ),
      );
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
        leading:
            result != null
                ? BackButton(onPressed: () => setState(() => result = null))
                : null,
        title: Text(
          result != null
              ? 'Kết quả'
              : attempt != null
              ? 'Làm bài'
              : 'Quiz cá nhân',
        ),
        actions: [
          if (attempt == null && result == null)
            TextButton(
              onPressed: () => context.push(AppRoutes.quizStatistics),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: const Text('Thống kê'),
            ),
        ],
      ),
      body: busy && attempt == null && result == null
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (error != null)
          TextButton(
            onPressed: busy ? null : _load,
            child: const Text('Thử lại'),
          ),
        const Text(
          'Bắt đầu bài thi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          isExpanded: true,
          value: subjectId,
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
          isExpanded: true,
          key: ValueKey(subjectId),
          value: deck?.id,
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
                busy ||
                        resumeBlocked ||
                        count < 1 ||
                        count > deck!.questionCount ||
                        count > 500
                    ? null
                    : _start,
            child: const Text('Bắt đầu'),
          ),
        ],
        const SizedBox(height: 32),
        if (openingResult) const LinearProgressIndicator(),
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
              onTap: openingResult ? null : () => _openResult(item.id),
            ),
          ),
        if (history.length < historyTotal)
          TextButton(
            onPressed: loadingHistory ? null : _moreHistory,
            child: const Text('Xem thêm'),
          ),
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
                        ? const Icon(LucideIcons.check, size: 16)
                        : null,
                onPressed: () => setState(() => questionIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 20),
        QuizContent(
          'Câu ${questionIndex + 1}/${quiz.questions.length}: ${question.content}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (question.multiple) const Text('Chọn nhiều đáp án'),
        const SizedBox(height: 12),
        for (final (i, answer) in question.answers.indexed)
          Card(
            child: CheckboxListTile(
              title: QuizContent(
                '${String.fromCharCode(65 + i)}. ${answer.content}',
              ),
              value: answers.contains(answer.id),
              onChanged:
                  submitting ||
                          (quiz.expiresAt != null && left == Duration.zero)
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
                        unawaited(_saveDraft().catchError(_showError));
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
        Text(
          data.percentage >= 50 ? 'Đạt' : 'Không đạt',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (data.createdAt != null)
          Text('Làm bài lúc: ${data.createdAt!.toLocal()}'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => result = null),
          child: const Text('Về danh sách'),
        ),
        if (data.deckId > 0)
          OutlinedButton.icon(
            onPressed: busy ? null : () => _begin(data.deckId, data.totalCount),
            icon: const Icon(LucideIcons.rotateCcw),
            label: Text(busy ? 'Đang tải...' : 'Làm lại bài quiz'),
          ),
        for (var i = 0; i < data.questions.length; i++)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: data.questions[i].isCorrect
                    ? const Color(0x5534D399)
                    : const Color(0x55F87171),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuizContent(
                    'Câu ${i + 1}: ${data.questions[i].content}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (data.questions[i].multiple) const Text('Nhiều đáp án'),
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
                              ? LucideIcons.circleCheck
                              : answer.wasSelected
                              ? LucideIcons.circleX
                              : LucideIcons.circle,
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
                          child: QuizContent(
                            '${answer.content}${answer.wasSelected ? ' (đã chọn)' : ''}',
                          ),
                        ),
                      ],
                    ),
                  if (data.questions[i].explanation?.isNotEmpty == true)
                    QuizContent('Giải thích: ${data.questions[i].explanation}'),
                  if (data.historyId > 0 && data.questions[i].id > 0)
                    Align(
                       alignment: Alignment.centerRight,
                       child: TextButton.icon(
                         onPressed: () => _report(data, data.questions[i]),
                         icon: const Icon(LucideIcons.flag),
                         label: const Text('Báo cáo câu hỏi'),
                       ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
