import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class QuizContent extends StatelessWidget {
  const QuizContent(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'[*_`#\[\]~>|]|\n').hasMatch(text)) {
      return Text(text, style: style);
    }
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(
        Theme.of(context),
      ).copyWith(p: style),
      imageBuilder:
          (uri, title, alt) =>
              uri.scheme == 'https' || uri.scheme == 'http'
                  ? Image.network(
                    uri.toString(),
                    errorBuilder:
                        (_, _, _) => Text(alt ?? 'Không tải được ảnh'),
                  )
                  : Text(alt ?? 'Ảnh không được hỗ trợ'),
      onTapLink: (text, href, title) async {
        if (href == null) return;
        await Clipboard.setData(ClipboardData(text: href));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép địa chỉ liên kết.')),
          );
        }
      },
    );
  }
}
