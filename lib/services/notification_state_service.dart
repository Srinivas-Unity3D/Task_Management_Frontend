import 'package:flutter/foundation.dart';

class NotificationStateService extends ChangeNotifier {
  static final NotificationStateService _instance = NotificationStateService._internal();
  factory NotificationStateService() => _instance;

  bool _hasUnreadNotifications = false;
  bool _notificationShown = false;

  NotificationStateService._internal();

  bool get hasUnreadNotifications => _hasUnreadNotifications;
  bool get notificationShown => _notificationShown;

  void setUnreadNotifications(bool value) {
    if (_hasUnreadNotifications != value) {
      _hasUnreadNotifications = value;
      notifyListeners();
    }
  }

  void markNotificationShown() {
    _notificationShown = true;
    notifyListeners();
  }

  void clearNotifications() {
    if (_hasUnreadNotifications) {
      _hasUnreadNotifications = false;
      _notificationShown = false;
      notifyListeners();
    }
  }
} 