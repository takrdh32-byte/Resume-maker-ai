import 'dart:async';

enum PlanType { free, daily, monthly }

class PlanManager {
  static PlanType _currentPlan = PlanType.free;
  static DateTime? _dailyExpiry;

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

  /// स्कैन में कितनी फोटो दिखानी हैं (अधिकतम)
  static int get photoLimit {
    switch (_currentPlan) {
      case PlanType.free: return 1;
      case PlanType.daily: return 50;
      case PlanType.monthly: return 200;
    }
  }

  /// क्या यूजर प्रो है (डेली या मंथली)
  static bool get isPro => _currentPlan != PlanType.free;

  /// डेली प्लान एक्सपायर तो नहीं हो गया
  static bool get isDailyExpired {
    if (_currentPlan == PlanType.daily && _dailyExpiry != null) {
      return DateTime.now().isAfter(_dailyExpiry!);
    }
    return false;
  }

  /// समय-समय पर एक्सपायरी चेक करके फ्री में गिराना
  static void checkExpiry() {
    if (isDailyExpired) {
      setFreePlan();
    }
  }
}