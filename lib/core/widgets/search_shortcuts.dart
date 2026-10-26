import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'search_field.dart';

/// App-level keyboard shortcut: `Ctrl+K` (or `Cmd+K` on macOS) focuses the
/// search field of the current screen. When the screen has none, the key is
/// left to the platform, so the browser shortcut still works.
class SearchShortcuts extends StatefulWidget {
  const SearchShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<SearchShortcuts> createState() => _SearchShortcutsState();
}

class _SearchShortcutsState extends State<SearchShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    if (event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      return false;
    }
    return focusActiveSearchField();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
