import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

/// Custom Windows-style title bar with drag-to-move, min/max/close buttons.
///
/// Sits above the FScaffold in the app shell. Uses window_manager's built-in
/// [DragToMoveArea] for drag + double-click maximize, and [WindowCaptionButton]
/// for native Windows 11 caption buttons.
class DesktopTitleBar extends StatefulWidget {
  /// Optional left-side widgets (e.g., app logo, breadcrumb).
  final List<Widget> leftChildren;

  const DesktopTitleBar({super.key, this.leftChildren = const []});

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final brightness = MediaQuery.platformBrightnessOf(context);
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(
          bottom: BorderSide(color: theme.colors.border, width: theme.style.borderWidth),
        ),
      ),
      child: DragToMoveArea(
        child: Row(
          children: [
            const SizedBox(width: 12),
            ...widget.leftChildren,
            const Spacer(),
            WindowCaptionButton.minimize(
              brightness: brightness,
              onPressed: windowManager.minimize,
            ),
            if (_isMaximized)
              WindowCaptionButton.unmaximize(
                brightness: brightness,
                onPressed: windowManager.unmaximize,
              )
            else
              WindowCaptionButton.maximize(
                brightness: brightness,
                onPressed: windowManager.maximize,
              ),
            WindowCaptionButton.close(
              brightness: brightness,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}
