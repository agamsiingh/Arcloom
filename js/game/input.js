// Pointer input for the board: taps, one-finger pan (when zoomed), pinch & wheel zoom.
// Taps are only emitted when the finger barely moved and no second finger joined,
// so panning or pinching can never launch an arrow by accident.

const TAP_SLOP = 10; // px of movement still considered a tap
const TAP_MAX_MS = 650;

export function attachInput(canvas, view, { onTap, onZoomChange }) {
  const pointers = new Map();
  let tapCandidate = null;
  let pinch = null;
  let panning = false;

  const pos = (e) => {
    const r = canvas.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };

  function down(e) {
    canvas.setPointerCapture?.(e.pointerId);
    const p = pos(e);
    pointers.set(e.pointerId, p);
    if (pointers.size === 1) {
      tapCandidate = { id: e.pointerId, x: p.x, y: p.y, t: performance.now() };
      panning = false;
    } else if (pointers.size === 2) {
      tapCandidate = null;
      const [a, b] = [...pointers.values()];
      pinch = { dist: Math.hypot(a.x - b.x, a.y - b.y), mid: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 } };
    }
  }

  function move(e) {
    if (!pointers.has(e.pointerId)) return;
    const prev = pointers.get(e.pointerId);
    const p = pos(e);
    pointers.set(e.pointerId, p);
    if (pointers.size >= 2 && pinch) {
      const [a, b] = [...pointers.values()];
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
      if (view.canZoom()) {
        view.zoomAt(mid.x, mid.y, dist / Math.max(1, pinch.dist));
        view.pan(mid.x - pinch.mid.x, mid.y - pinch.mid.y);
        onZoomChange?.();
      }
      pinch = { dist, mid };
      return;
    }
    if (tapCandidate && Math.hypot(p.x - tapCandidate.x, p.y - tapCandidate.y) > TAP_SLOP) {
      tapCandidate = null;
      panning = view.scale > 1;
    }
    if (panning) {
      view.pan(p.x - prev.x, p.y - prev.y);
      onZoomChange?.();
    }
  }

  function up(e) {
    if (!pointers.has(e.pointerId)) return;
    const p = pos(e);
    pointers.delete(e.pointerId);
    if (pointers.size < 2) pinch = null;
    if (tapCandidate && tapCandidate.id === e.pointerId && e.type === 'pointerup') {
      const quick = performance.now() - tapCandidate.t < TAP_MAX_MS;
      if (quick && Math.hypot(p.x - tapCandidate.x, p.y - tapCandidate.y) <= TAP_SLOP) {
        onTap(tapCandidate.x, tapCandidate.y);
      }
    }
    if (!pointers.size) {
      tapCandidate = null;
      panning = false;
    }
  }

  function wheel(e) {
    if (!view.canZoom()) return;
    e.preventDefault();
    const p = pos(e);
    view.zoomAt(p.x, p.y, Math.exp(-e.deltaY * 0.0015));
    onZoomChange?.();
  }

  canvas.addEventListener('pointerdown', down);
  canvas.addEventListener('pointermove', move);
  canvas.addEventListener('pointerup', up);
  canvas.addEventListener('pointercancel', up);
  canvas.addEventListener('wheel', wheel, { passive: false });
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());

  return () => {
    canvas.removeEventListener('pointerdown', down);
    canvas.removeEventListener('pointermove', move);
    canvas.removeEventListener('pointerup', up);
    canvas.removeEventListener('pointercancel', up);
    canvas.removeEventListener('wheel', wheel);
  };
}
