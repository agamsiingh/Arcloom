// Service container. Production wires the real SDKs in main.dart; tests inject fakes.
import 'ads/ad_service.dart';
import 'audio.dart';
import 'haptics.dart';
import 'purchases.dart';
import 'storage.dart';

class Services {
  Services({
    required this.store,
    required this.audio,
    required this.haptics,
    required this.ads,
    required this.purchases,
  });

  final Store store;
  final GameAudio audio;
  final Haptics haptics;
  final AdService ads;
  final PurchaseService purchases;

  static late Services I;

  SaveData get data => store.data;

  /// Push persisted settings into audio / haptics.
  void applySettings() {
    audio.configure(data.settings);
    haptics.enabled = data.settings.haptics;
  }
}
