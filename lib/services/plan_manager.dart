import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

enum PlanType { free, daily, monthly }

class PlanManager {
  static PlanType _currentPlan = PlanType.free;
  static DateTime? _dailyExpiry;

  // नए यूज़र का फ्री ट्रायल चेक
  static Future<bool> hasUsedFree() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('free_used') ?? false;
  }

  static Future<void> markUsedFree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('free_used', true);
  }

  static PlanType get currentPlan => _currentPlan;

  static void setFreePlan() {
    _currentPlan = PlanType.free;
    _dailyExpiry = null;
  }

  static void setDailyPlan() {
    _currentPlan = PlanType.daily;
    _dailyExpiry = DateTime.now().add(const Duration(days: 1));
  }

  static void setMonthlyPlan() {
    _currentPlan = PlanType.monthly;
    _dailyExpiry = null;
  }

  static int get photoLimit {
    switch (_currentPlan) {
      case PlanType.free: return 1;
      case PlanType.daily: return 50;
      case PlanType.monthly: return 200;
    }
  }

  static bool get isPro => _currentPlan != PlanType.free;

  static bool get isDailyExpired {
    if (_currentPlan == PlanType.daily && _dailyExpiry != null) {
      return DateTime.now().isAfter(_dailyExpiry!);
    }
    return false;
  }

  static void checkExpiry() {
    if (isDailyExpired) {
      setFreePlan();
    }
  }
}