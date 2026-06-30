import 'package:shared_preferences/shared_preferences.dart';

enum PlanType { free, monthly }

class PlanManager {
  static PlanType _currentPlan = PlanType.free;
  static DateTime? _expiry;

  // ऐप शुरू होते ही पिछला प्लान लोड करो
  static Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final planStr = prefs.getString('plan_type') ?? 'free';
    _currentPlan = planStr == 'monthly' ? PlanType.monthly : PlanType.free;
    final expiryMs = prefs.getInt('plan_expiry');
    _expiry = expiryMs != null ? DateTime.fromMillisecondsSinceEpoch(expiryMs) : null;
    checkExpiry();
  }

  static Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plan_type', _currentPlan == PlanType.monthly ? 'monthly' : 'free');
    await prefs.setInt('plan_expiry', _expiry?.millisecondsSinceEpoch ?? 0);
  }

  static PlanType get currentPlan => _currentPlan;

  static void setFreePlan() {
    _currentPlan = PlanType.free;
    _expiry = null;
    _saveToStorage();
  }

  static void setMonthlyPlan() {
    _currentPlan = PlanType.monthly;
    _expiry = DateTime.now().add(const Duration(days: 30)); // 30 दिन
    _saveToStorage();
  }

  static int get photoLimit {
    switch (_currentPlan) {
      case PlanType.free: return 1;
      case PlanType.monthly: return 200;
    }
  }

  static bool get isPro => _currentPlan != PlanType.free;

  static bool get isExpired {
    if (_currentPlan == PlanType.monthly && _expiry != null) {
      return DateTime.now().isAfter(_expiry!);
    }
    return false;
  }

  static void checkExpiry() {
    if (isExpired) {
      setFreePlan();
    }
  }

  // फ्री ट्रायल चेक (पहले से है, कोई बदलाव नहीं)
  static Future<bool> hasUsedFree() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('free_used') ?? false;
  }

  static Future<void> markUsedFree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('free_used', true);
  }
}