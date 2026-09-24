// Board widget: 60 FPS painting + pointer input (port of js/game/input.js).
// Taps fire only when the finger barely moved and no second finger joined, so
// panning or pinching can never launch an arrow by accident. The board layout
// never shifts during play; only an explicit pinch changes the zoom.
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'board_view.dart';

const double _tapSlop = 10;
const int _tapMaxMs = 650;

/// Monotonic milliseconds shared by the board view and its animations.
final Stopwatch boardClock = Stopwatch()..start();
double boardNow() => boardClock.elapsedMicroseconds / 1000.0;

class BoardWidget extends StatefulWidget {
  const BoardWidget({super.key, required this.view, required this.onTap, this.onZoomChanged});

  final BoardView view;
  final void Function(Offset local) onTap;
  final VoidCallback? onZoomChanged;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  final Map<int, Offset> _pointers = {};
  ({int id, Offset pos, double t})? _tapCandidate;
  ({double dist, Offset mid})? _pinch;
  bool _panning = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _frame.value++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  BoardView get view => widget.view;

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _tapCandidate = (id: e.pointer, pos: e.localPosition, t: boardNow());
      _panning = false;
    } else if (_pointers.length == 2) {
      _tapCandidate = null;
      final [a, b] = _pointers.values.toList();
      _pinch = (dist: (a - b).distance, mid: (a + b) / 2);
    }
  }

  void _move(PointerMoveEvent e) {
    final prev = _pointers[e.pointer];
    if (prev == null) return;
    _pointers[e.pointer] = e.localPosition;
    final pinch = _pinch;
    if (_pointers.length >= 2 && pinch != null) {
      final pts = _pointers.values.toList();
      final dist = (pts[0] - pts[1]).distance;
      final mid = (pts[0] + pts[1]) / 2;
      if (view.canZoom) {
        view.zoomAt(mid, dist / (pinch.dist < 1 ? 1 : pinch.dist));
        view.pan(mid - pinch.mid);
        widget.onZoomChanged?.call();
      }
      _pinch = (dist: dist, mid: mid);
      return;
    }
    final cand = _tapCandidate;
    if (cand != null && (e.localPosition - cand.pos).distance > _tapSlop) {
      _tapCandidate = null;
      _panning = view.scale > 1;
    }
    if (_panning) {
      view.pan(e.localPosition - prev);
      widget.onZoomChanged?.call();
    }
  }

  void _up(PointerEvent e, {bool cancelled = false}) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinch = null;
    final cand = _tapCandidate;
    if (!cancelled && cand != null && cand.id == e.pointer) {
      final quick = boardNow() - cand.t < _tapMaxMs;
      if (quick && (e.localPosition - cand.pos).distance <= _tapSlop) widget.onTap(cand.pos);
    }
    if (_pointers.isEmpty) {
      _tapCandidate = null;
      _panning = false;
    }
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent && view.canZoom) {
      view.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
      widget.onZoomChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      view.layout(constraints.biggest);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: (e) => _up(e, cancelled: true),
        onPointerSignal: _signal,
        child: CustomPaint(
          size: constraints.biggest,
          painter: _BoardPainter(view, _frame),
          isComplex: true,
          willChange: true,
        ),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.view, this.frame) : super(repaint: frame);

  final BoardView view;
  final ValueNotifier<int> frame;
  double _last = -1;

  @override
  void paint(Canvas canvas, Size size) {
    final now = boardNow();
    final dt = _last < 0 ? 0.016 : ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    canvas.clipRect(Offset.zero & size);
    view.paint(canvas, now, dt);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.view != view;
}
