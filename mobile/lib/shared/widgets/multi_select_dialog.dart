import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';

class MultiSelectDialog extends StatefulWidget {
  const MultiSelectDialog({
    super.key,
    required this.title,
    required this.options,
    required this.labels,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final List<String> labels;
  final Set<String> selected;

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late Set<String> _current;

  @override
  void initState() {
    super.initState();
    _current = Set<String>.from(widget.selected);
  }

  void _apply() {
    Navigator.of(context).pop(_current.toList());
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 400 ||
        MediaQuery.of(context).size.height < 500;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isNarrow ? MediaQuery.of(context).size.width * 0.9 : 520,
          maxHeight: isNarrow ? 300 : 480,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: ValueKey(_current.hashCode),
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.options.length, (i) {
              final opt = widget.options[i];
              final isOn = _current.contains(opt);
              return CheckboxListTile(
                key: ValueKey('$i-$opt-$isOn'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                title: Text(
                  widget.labels[i],
                  style: const TextStyle(fontSize: 15),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
                value: isOn,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _current.add(opt);
                    } else {
                      _current.remove(opt);
                    }
                  });
                },
              );
            }),
          ),
        ),
      ),
      actions: [
        (isNarrow || MediaQuery.of(context).size.width < 500)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _apply,
                    child: Text(AppStrings.t('apply', LocaleNotifier.current)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _current.clear()),
                        child: Text(AppStrings.t('clear', LocaleNotifier.current)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _current = Set<String>.from(widget.options);
                          });
                        },
                        child: Text(AppStrings.t('all', LocaleNotifier.current)),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _current.clear()),
                    child: Text(AppStrings.t('clear', LocaleNotifier.current)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _current = Set<String>.from(widget.options);
                      });
                    },
                    child: Text(AppStrings.t('all', LocaleNotifier.current)),
                  ),
                  FilledButton(
                    onPressed: _apply,
                    child: Text(AppStrings.t('apply', LocaleNotifier.current)),
                  ),
                ],
              ),
      ],
    );
  }
}
