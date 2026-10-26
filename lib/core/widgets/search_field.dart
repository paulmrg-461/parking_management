import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Search input used by list screens. On web/desktop it takes focus
/// automatically (type-to-search) and `Esc` clears it; on touch devices it
/// behaves like a normal field so the keyboard does not pop up uninvited.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.label,
    required this.onChanged,
    this.fieldKey,
    this.hint,
    this.textCapitalization = TextCapitalization.characters,
  });

  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final TextCapitalization textCapitalization;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();

  static bool get _desktop =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => true,
        _ => false,
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _clear,
      },
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: _desktop,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: const Icon(Icons.clear),
                  onPressed: _clear,
                ),
        ),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
      ),
    );
  }
}
