import 'package:flutter/material.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/quiz_repository.dart';

class ReportQuestionDialog extends StatefulWidget {
  const ReportQuestionDialog({
    super.key,
    required this.repo,
    required this.historyId,
    required this.questionId,
  });
  final QuizRepository repo;
  final int historyId, questionId;
  @override
  State<ReportQuestionDialog> createState() => _ReportQuestionDialogState();
}

class _ReportQuestionDialogState extends State<ReportQuestionDialog> {
  final note = TextEditingController();
  String reason = 'WrongAnswer';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.report(
        widget.historyId,
        widget.questionId,
        reason,
        note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e is ApiException
                      ? e.message
                      : 'Không thể gửi báo cáo. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Báo cáo câu hỏi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lý do'),
              items: const [
                DropdownMenuItem(
                  value: 'WrongAnswer',
                  child: Text('Đáp án sai'),
                ),
                DropdownMenuItem(
                  value: 'UnclearQuestion',
                  child: Text('Câu hỏi không rõ ràng'),
                ),
                DropdownMenuItem(
                  value: 'DuplicateQuestion',
                  child: Text('Câu hỏi trùng lặp'),
                ),
                DropdownMenuItem(value: 'Other', child: Text('Khác')),
              ],
              onChanged: busy ? null : (v) => setState(() => reason = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              enabled: !busy,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : _send,
          child: Text(busy ? 'Đang gửi...' : 'Gửi báo cáo'),
        ),
      ],
    ),
  );
}
