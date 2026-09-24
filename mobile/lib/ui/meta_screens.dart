// Trophies (achievements + stats) and the Supporter shop.
import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../services/ads/ad_service.dart';
import '../services/progress.dart';
import '../services/purchases.dart';
import '../services/services.dart';
import 'theme.dart';
import 'widgets.dart';

class TrophiesScreen extends StatelessWidget {
  const TrophiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = Services.I.data;
    final st = s.stats;
    Widget stat(String v, String label) => Column(children: [
          Text(v, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: p.text)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.muted)),
        ]);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: 'Trophies', subtitle: '${s.achievements.length} / ${achievements.length} unlocked'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ArcCard(
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.6,
                    children: [
                      stat(st.totalScore.toString(), 'Total score'),
                      stat('${st.perfect}', 'Perfect clears'),
                      stat('×${st.maxCombo}', 'Best combo'),
                      stat('${st.maxChain}', 'Longest chain'),
                      stat('${st.launches}', 'Launches'),
                      stat('${s.daily.best}', 'Best streak'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final a in achievements) _achievement(context, a),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _achievement(BuildContext context, Achievement a) {
    final p = context.pal;
    final s = Services.I.data;
    final got = s.achievements.containsKey(a.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ArcCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: got ? p.gold.withValues(alpha: 0.16) : p.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(got ? Icons.emoji_events_outlined : Icons.lock_outline_rounded, color: got ? p.gold : p.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
              Text(a.desc, style: TextStyle(fontSize: 12.5, color: p.muted)),
              if (!got)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                        value: a.progress(s), minHeight: 5, backgroundColor: p.surface2, color: p.accent),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lightbulb_outline_rounded, size: 15, color: p.muted),
          Text('+${a.reward}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: p.muted)),
        ]),
      ),
    );
  }
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _watching = false;

  Future<void> _freeHint() async {
    final sv = Services.I;
    final d = sv.data;
    if (d.adFree) {
      // Ad-free supporters can claim a few instant hints per day (no ad shown).
      final today = dateKey();
      if (d.ads.rewardedDate == today && d.ads.rewardedCount >= 5) {
        showToast(context, "That's plenty for today — come back tomorrow");
        return;
      }
      if (d.ads.rewardedDate != today) {
        d.ads.rewardedDate = today;
        d.ads.rewardedCount = 0;
      }
      d.ads.rewardedCount++;
      d.hints += 1;
      await sv.store.save();
      if (mounted) showToast(context, '+1 hint', icon: Icons.lightbulb_outline_rounded);
      return;
    }
    setState(() => _watching = true);
    final out = await sv.ads.showRewarded(RewardPlacement.hint);
    if (!mounted) return;
    setState(() => _watching = false);
    if (out == RewardOutcome.earned) {
      d.hints += 1;
      await sv.store.save();
      if (mounted) showToast(context, '+1 hint', icon: Icons.lightbulb_outline_rounded);
    } else if (out == RewardOutcome.unavailable) {
      showToast(context, 'No ad available right now. Please try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sv = Services.I;
    return ListenableBuilder(
      listenable: Listenable.merge([sv.store, sv.purchases, sv.ads]),
      builder: (context, _) {
        final p = context.pal;
        final d = sv.data;
        final iap = sv.purchases;
        final left = sv.ads.rewardedLeftToday;
        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              TopBar(title: d.adFree ? 'Supporter' : 'Go ad-free'),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  ArcCard(
                    child: Column(children: [
                      Container(
                        width: 84,
                        height: 84,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(colors: [p.accent, p.gold]),
                        ),
                        child: const Icon(Icons.diamond_outlined, size: 44, color: Colors.white),
                      ),
                      Text('Arcloom Supporter', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: p.text)),
                      Text('One-time purchase. Yours forever.', style: TextStyle(color: p.muted)),
                      const SizedBox(height: 14),
                      for (final perk in const [
                        'No ads at all — no interstitials, and hint & continue rewards are instant',
                        '$supporterBonusHints bonus hints right away',
                        'Support an indie puzzle with no pay-walls',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.check_rounded, color: p.good, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(perk, style: TextStyle(color: p.text))),
                          ]),
                        ),
                      const SizedBox(height: 6),
                      if (d.adFree)
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_rounded, color: p.good),
                          const SizedBox(width: 6),
                          Text('Owned — thank you!', style: TextStyle(color: p.good, fontWeight: FontWeight.w800)),
                        ])
                      else ...[
                        ArcButton(
                          label: iap.pending ? 'Processing…' : 'Unlock for ${iap.price}',
                          primary: true,
                          big: true,
                          onPressed: iap.pending ? null : () => iap.buyAdFree(),
                        ),
                        TextButton(
                          onPressed: () async {
                            await iap.restore();
                            if (context.mounted && iap.lastError != null) showToast(context, iap.lastError!);
                          },
                          child: Text('Restore purchase', style: TextStyle(color: p.muted, decoration: TextDecoration.underline)),
                        ),
                        if (iap.lastError != null) Text(iap.lastError!, textAlign: TextAlign.center, style: TextStyle(color: p.danger, fontSize: 12.5)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 14),
                  ArcCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Free hints'),
                      Text('Hints are also earned by perfect clears, daily puzzles and trophies. You have ${d.hints}.',
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                      const SizedBox(height: 10),
                      ArcButton(
                        label: _watching ? 'Loading ad…' : (d.adFree ? 'Claim +1 hint' : 'Watch an ad · +1 hint'),
                        icon: d.adFree ? Icons.lightbulb_outline_rounded : Icons.ondemand_video_rounded,
                        onPressed: _watching || (!d.adFree && !sv.ads.canOfferRewarded) ? null : _freeHint,
                      ),
                      if (!d.adFree)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(left > 0 ? '$left left today' : 'Daily limit reached',
                              style: TextStyle(fontSize: 12.5, color: p.muted)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Rewarded ads are always optional. A short ad may appear between levels every few levels — never during play or right after a mistake. Supporters never see ads.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: p.muted),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
