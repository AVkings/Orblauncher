import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Centralised haptics so every interaction "feels" consistent.
/// Silently degrades on devices/emulators without a vibrator.
class HapticUtil {
  HapticUtil._();

  static bool _available = false;
  static bool get enabled => _available;

  static Future<void> init() async {
    try {
      final bool? has = await Vibration.hasVibrator();
      _available = has ?? false;
    } catch (_) {
      _available = false;
    }
  }

  /// Light tick — page snap, small toggles.
  static void selection() {
    if (_available) {
      HapticFeedback.selectionClick();
    }
  }

  /// Medium impact — sphere released / settling.
  static void impact() {
    if (_available) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy confirmation — app launched, drawer opened.
  static void confirm() {
    if (_available) {
      HapticFeedback.heavyImpact();
    }
  }
}
