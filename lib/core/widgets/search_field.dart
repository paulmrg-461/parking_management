import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The search field currently on screen (`null` when the page has none), so
/// the global Ctrl/Cmd+K shortcut knows where to send focus.
_SearchFieldState? _activeSearchField;

/// Focuses the visible search field. Returns `true` when there was one, so the
/// shortcut can let the platform handle the key otherwise.
bool focusActiveSearchField() {
  final field = _activeSearchField;
  if (field == null) {
    return false;
  }
  field._focus.requestFocus();
  return true;
}

/// Empties the visible search field and reports `''` (the next check-out after
/// a receipt starts from a clean list).
bool resetActiveSearchField() {
  final field = _activeSearchField;
  if (field == null) {
    return false;
  }
  field._clear();
  field._focus.requestFocus();
  return true;
}

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
    this.initialValue,
    this.controller,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.characters,
  });

  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final String? initialValue;

  /// Optional external controller (e.g. a scanned plate fills the field).
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  static bool get _desktop =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    // The last field mounted wins; go_router keeps one page alive at a time.
    _activeSearchField = this;
    final initial = widget.initialValue?.trim();
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
    }
  }

  @override
  void dispose() {
    if (identical(_activeSearchField, this)) {
      _activeSearchField = null;
    }
    _focus.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
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
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        focusNode: _focus,
        autofocus: _desktop,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  icon: const Icon(Icons.clear),
                  onPressed: _clear,
                ),
        ),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
