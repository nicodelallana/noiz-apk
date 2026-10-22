import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transport mode toggle — determines whether the app shows Metro or Bus data.
enum TransportMode {
  metro('Metro', Icons.directions_subway_rounded, Color(0xFFE2001A)),
  bus('Bus', Icons.directions_bus_rounded, Color(0xFF00843D));

  const TransportMode(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Current transport mode state, defaults to Metro.
final transportModeProvider = StateProvider<TransportMode>(
  (ref) => TransportMode.metro,
);

/// Central FAB that toggles between Metro and Bus.
///
/// - Default: shows the active mode icon in a circular FAB.
/// - On tap: expands vertically to reveal both options.
/// - Selecting an option updates [transportModeProvider] and collapses.
class TransportModeFab extends ConsumerStatefulWidget {
  const TransportModeFab({super.key});

  @override
  ConsumerState<TransportModeFab> createState() => _TransportModeFabState();
}

class _TransportModeFabState extends ConsumerState<TransportModeFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _selectMode(TransportMode mode) {
    ref.read(transportModeProvider.notifier).state = mode;
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(transportModeProvider);

    return SizedBox(
      width: 64,
      height: 160,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // ── Expanded options (behind the main FAB) ──────────────────────
          ..._buildExpandedOptions(currentMode),

          // ── Main FAB ────────────────────────────────────────────────────
          SizedBox(
            width: 60,
            height: 60,
            child: FloatingActionButton(
              heroTag: 'transport_mode_fab',
              onPressed: _toggle,
              backgroundColor: currentMode.color,
              elevation: 6,
              shape: const CircleBorder(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  _isExpanded ? Icons.close : currentMode.icon,
                  key: ValueKey(_isExpanded ? 'close' : currentMode.name),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpandedOptions(TransportMode currentMode) {
    final options = TransportMode.values;

    return List.generate(options.length, (index) {
      final mode = options[index];
      // Offset each button upward from the main FAB
      final targetOffset = (index + 1) * 66.0;

      return AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          return Positioned(
            bottom: _expandAnimation.value * targetOffset,
            child: Opacity(
              opacity: _expandAnimation.value,
              child: Transform.scale(
                scale: 0.6 + (_expandAnimation.value * 0.4),
                child: child,
              ),
            ),
          );
        },
        child: SizedBox(
          width: 52,
          height: 52,
          child: FloatingActionButton(
            heroTag: 'transport_fab_${mode.name}',
            onPressed: () => _selectMode(mode),
            backgroundColor:
                mode == currentMode ? mode.color : mode.color.withOpacity(0.75),
            elevation: 3,
            shape: const CircleBorder(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(mode.icon, color: Colors.white, size: 22),
                Text(
                  mode.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Animated builder helper (wraps [ListenableBuilder]).
class AnimatedBuilder extends StatelessWidget {
  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: animation,
      builder: (context, _) => builder(context, child),
      child: child,
    );
  }
}
