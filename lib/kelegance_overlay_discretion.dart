import 'package:flutter/material.dart';

/// Voile plein écran — masque les données sensibles quand l'app passe en arrière-plan.
/// Web · APK Android · iPhone (PWA ou natif).
class KeleganceOverlayDiscretion extends StatefulWidget {
  const KeleganceOverlayDiscretion({super.key, required this.child});

  final Widget child;

  @override
  State<KeleganceOverlayDiscretion> createState() => _KeleganceOverlayDiscretionState();
}

class _KeleganceOverlayDiscretionState extends State<KeleganceOverlayDiscretion>
    with WidgetsBindingObserver {
  bool _masqueVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final doitMasquer = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    if (_masqueVisible == doitMasquer) return;
    setState(() => _masqueVisible = doitMasquer);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_masqueVisible,
            child: AnimatedOpacity(
              opacity: _masqueVisible ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: const _RideauDiscretion(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RideauDiscretion extends StatelessWidget {
  const _RideauDiscretion();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF141414),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.35)),
              ),
              child: Image.asset('assets/images/kelegance_logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 22),
            Text(
              'KELEGANCE',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 22,
                fontWeight: FontWeight.w400,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
