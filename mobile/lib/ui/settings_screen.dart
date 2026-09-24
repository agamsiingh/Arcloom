// Settings (port of the PWA's settingsScreen) + ad privacy options + data controls.
import 'package:flutter/material.dart';

import '../services/services.dart';
import 'theme.dart';
import 'widgets.dart';

const String appVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _privacyRequired = false;

  @override
  void initState() {
    super.initState();
    Services.I.ads.privacyOptionsRequired().then((v) {
      if (mounted) setState(() => _privacyRequired = v);
    });
  }

  void _set(void Function() f) {
    f();
    Services.I.applySettings();
    Services.I.store.save();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('Levels, stars, streaks and achievements will be erased. Settings and purchases are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.pal.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Services.I.store.resetProgress();
      if (mounted) showToast(context, 'Progress reset');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.I.store,
      builder: (context, _) {
        final p = context.pal;
        final st = Services.I.data.settings;
        Widget field(String label, Widget control) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [Text(label, style: TextStyle(color: p.text, fontWeight: FontWeight.w600)), control],
              ),
            );
        Widget slider(String label, double value, ValueChanged<double> onEnd) => Row(children: [
              SizedBox(width: 118, child: Text(label, style: TextStyle(color: p.muted))),
              Expanded(
                child: Slider(
                  value: value,
                  activeColor: p.accent,
                  onChanged: (v) => setState(() => onEnd(v)),
                  onChangeEnd: (v) => _set(() => onEnd(v)),
                  semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                ),
              ),
            ]);
        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              const TopBar(title: 'Settings'),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  ArcCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Play'),
                      field(
                        'Default mode',
                        Segmented<String>(
                          options: const [('challenge', 'Challenge'), ('zen', 'Zen')],
                          value: st.mode,
                          onChanged: (v) => _set(() => st.mode = v),
                        ),
                      ),
                      Text('Challenge gives you 3 hearts per level. Zen has unlimited retries.',
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                      ToggleTile(
                        title: 'Tap to confirm',
                        subtitle: 'First tap selects and previews the lane, second tap launches',
                        value: st.tapConfirm,
                        onChanged: (v) => _set(() => st.tapConfirm = v),
                      ),
                      ToggleTile(
                        title: 'Large touch targets',
                        subtitle: 'Even more generous invisible hitboxes',
                        value: st.largeHitboxes,
                        onChanged: (v) => _set(() => st.largeHitboxes = v),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  ArcCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Audio'),
                      ToggleTile(title: 'Sound effects', subtitle: 'Taps, slides, chains and chimes', value: st.sound, onChanged: (v) => _set(() => st.sound = v)),
                      slider('Effects volume', st.soundVolume, (v) => st.soundVolume = v),
                      ToggleTile(title: 'Music', subtitle: 'Calm generative ambience', value: st.music, onChanged: (v) => _set(() => st.music = v)),
                      slider('Music volume', st.musicVolume, (v) => st.musicVolume = v),
                      ToggleTile(title: 'Haptics', subtitle: 'Subtle vibration feedback', value: st.haptics, onChanged: (v) => _set(() => st.haptics = v)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  ArcCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Display & accessibility'),
                      field(
                        'Theme',
                        Segmented<String>(
                          options: const [('system', 'Auto'), ('light', 'Light'), ('dark', 'Dark'), ('amoled', 'AMOLED')],
                          value: st.theme,
                          onChanged: (v) => _set(() => st.theme = v),
                        ),
                      ),
                      field(
                        'Text size',
                        Segmented<double>(
                          options: const [(1.0, 'A'), (1.15, 'A+'), (1.3, 'A++')],
                          value: st.textScale,
                          onChanged: (v) => _set(() => st.textScale = v),
                        ),
                      ),
                      ToggleTile(title: 'Reduce motion', subtitle: 'Shorter animations, fewer particles', value: st.reducedMotion, onChanged: (v) => _set(() => st.reducedMotion = v)),
                      ToggleTile(title: 'High contrast', subtitle: 'Stronger colours and outlines', value: st.highContrast, onChanged: (v) => _set(() => st.highContrast = v)),
                      Text(
                        'Colour barriers always carry stripe / dot patterns and every special arrow has its own symbol, so no mechanic relies on colour alone.',
                        style: TextStyle(fontSize: 12.5, color: p.muted),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  ArcCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Privacy & data'),
                      Text('Your progress is saved on this device and the game works fully offline. Ads (if any) are served by Google AdMob.',
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                      const SizedBox(height: 10),
                      if (_privacyRequired) ...[
                        ArcButton(label: 'Ad privacy choices', icon: Icons.privacy_tip_outlined, onPressed: Services.I.ads.showPrivacyOptions),
                        const SizedBox(height: 10),
                      ],
                      Row(children: [
                        Expanded(
                          child: ArcButton(
                            label: 'Restore purchase',
                            icon: Icons.diamond_outlined,
                            onPressed: () async {
                              await Services.I.purchases.restore();
                              if (!context.mounted) return;
                              final err = Services.I.purchases.lastError;
                              showToast(context, err ?? 'Restore requested — purchases will be re-applied if found');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: ArcButton(label: 'Reset progress', icon: Icons.refresh_rounded, danger: true, onPressed: _confirmReset)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Center(child: Text('arcloom v$appVersion', style: TextStyle(fontSize: 12.5, color: p.muted))),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
