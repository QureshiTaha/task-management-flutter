import 'package:flutter/material.dart';

class AnimatedFab extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  const AnimatedFab({super.key, required this.onPressed, required this.text});

  @override
  State<AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<AnimatedFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  bool showLabel = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _widthAnimation = Tween<double>(
      begin: 56.0,
      end: 160.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _startFabAnimation();
  }

  void _startFabAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => showLabel = true);
    await _controller.forward();

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    await _controller.reverse();
    setState(() => showLabel = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return SizedBox(
          width: _widthAnimation.value,
          height: 56.0,
          child: FloatingActionButton(
            backgroundColor: colorScheme.primary,
            onPressed: widget.onPressed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.text,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
