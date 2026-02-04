import '../models/subscription_model.dart';

class NotificationIdHelper {
  /// Stable notification ID per subscription
  /// Uses hashCode (safe enough for local notifications)
  static int fromSubscription(Subscription sub) {
    return sub.id.hashCode;
  }
}
