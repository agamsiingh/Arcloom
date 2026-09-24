// Subtle haptics. Uses the Capacitor Haptics plugin when wrapped natively,
// otherwise the Vibration API (Android browsers). Silently no-ops elsewhere.

let enabled = true;

export function setEnabled(v) {
  enabled = v;
}

const PATTERNS = {
  light: 8,
  select: 12,
  medium: 18,
  error: [28, 40, 28],
  success: [12, 30, 12, 30, 40],
  chain: [10, 20, 10],
};

export function buzz(kind = 'light') {
  if (!enabled || navigator.userActivation?.hasBeenActive === false) return;
  const cap = window.Capacitor?.Plugins?.Haptics;
  try {
    if (cap) {
      if (kind === 'error') cap.notification({ type: 'ERROR' });
      else if (kind === 'success') cap.notification({ type: 'SUCCESS' });
      else cap.impact({ style: kind === 'medium' ? 'MEDIUM' : 'LIGHT' });
      return;
    }
    if (navigator.vibrate) navigator.vibrate(PATTERNS[kind] ?? 8);
  } catch {
    // Haptics are optional.
  }
}
