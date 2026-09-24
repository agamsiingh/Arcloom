// Player-friendly monetization: no interstitials, ever. Only opt-in rewarded ads
// (hints / continues) and a one-time "Supporter" unlock that skips ads entirely.
//
// Integration points for a native build (Capacitor / TWA):
//   window.ArcloomAds = { showRewarded(placement) => Promise<boolean> }   e.g. AdMob RewardedAd
//   window.ArcloomIAP = { purchase(sku) => Promise<boolean>, restore() => Promise<string[]> }
// Without them, a clearly-labelled demo ad / test store is used so the loop is playable.
import * as store from './storage.js';

export const AD_FREE_SKU = 'arcloom_supporter';
export const AD_FREE_PRICE = '$2.99';
export const SUPPORTER_BONUS_HINTS = 10;
export const REWARDED_DAILY_CAP = 10;

function today() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function rewardedLeft() {
  const s = store.get();
  if (s.adFree) return Infinity;
  if (s.rewardedToday.date !== today()) return REWARDED_DAILY_CAP;
  return Math.max(0, REWARDED_DAILY_CAP - s.rewardedToday.count);
}

/** Resolves true when the reward should be granted. */
export async function showRewarded(placement) {
  const s = store.get();
  if (s.adFree) return true;
  if (rewardedLeft() <= 0) return false;
  let ok;
  if (window.ArcloomAds?.showRewarded) {
    try { ok = await window.ArcloomAds.showRewarded(placement); } catch { ok = false; }
  } else {
    ok = await demoAd(placement);
  }
  if (ok) {
    if (s.rewardedToday.date !== today()) s.rewardedToday = { date: today(), count: 0 };
    s.rewardedToday.count++;
    store.save();
  }
  return ok;
}

function demoAd(placement) {
  return new Promise((resolve) => {
    const el = document.createElement('div');
    el.className = 'demo-ad';
    el.setAttribute('role', 'dialog');
    el.setAttribute('aria-label', 'Rewarded ad');
    el.innerHTML = `
      <div class="demo-ad-card">
        <div class="demo-ad-tag">Demo ad · ${placement === 'continue' ? 'Continue' : 'Hints'}</div>
        <div class="demo-ad-art"><span></span><span></span><span></span></div>
        <p>Rewarded ad placeholder. A real ad network plugs in here in the native build.</p>
        <div class="demo-ad-bar"><i></i></div>
        <div class="demo-ad-actions">
          <button class="btn ghost" data-x>Skip (no reward)</button>
          <button class="btn primary" data-claim disabled>Claim in 5s</button>
        </div>
      </div>`;
    document.body.appendChild(el);
    const claim = el.querySelector('[data-claim]');
    const bar = el.querySelector('.demo-ad-bar i');
    const start = performance.now();
    const DURATION = 5000;
    let raf;
    const step = (now) => {
      const p = Math.min(1, (now - start) / DURATION);
      bar.style.transform = `scaleX(${p})`;
      const left = Math.ceil((DURATION - (now - start)) / 1000);
      if (p < 1) {
        claim.textContent = `Claim in ${left}s`;
        raf = requestAnimationFrame(step);
      } else {
        claim.textContent = 'Claim reward';
        claim.disabled = false;
      }
    };
    raf = requestAnimationFrame(step);
    const done = (v) => {
      cancelAnimationFrame(raf);
      el.remove();
      resolve(v);
    };
    el.querySelector('[data-x]').onclick = () => done(false);
    claim.onclick = () => done(true);
  });
}

export async function purchaseAdFree() {
  let ok;
  if (window.ArcloomIAP?.purchase) {
    try { ok = await window.ArcloomIAP.purchase(AD_FREE_SKU); } catch { ok = false; }
  } else {
    ok = window.confirm(`Test store: buy "Arcloom Supporter" for ${AD_FREE_PRICE}?\n(No real payment in this build.)`);
  }
  if (ok) grantSupporter();
  return ok;
}

export async function restorePurchases() {
  if (window.ArcloomIAP?.restore) {
    try {
      const skus = await window.ArcloomIAP.restore();
      if (skus.includes(AD_FREE_SKU)) grantSupporter();
    } catch { /* ignore */ }
  }
  return store.get().adFree;
}

function grantSupporter() {
  const s = store.get();
  if (!s.adFree) s.hints += SUPPORTER_BONUS_HINTS;
  s.adFree = true;
  store.save();
}
