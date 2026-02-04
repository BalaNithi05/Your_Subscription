import '../models/subscription_model.dart';
import '../services/supabase_service.dart';

class SubscriptionRepository {
  final SupabaseService _service = SupabaseService();

  Future<List<Subscription>> getAll() async {
    return await _service.fetchSubscriptions();
  }

  Future<void> add(Subscription sub) async {
    await _service.addSubscription(sub);
  }

  Future<void> update(Subscription sub) async {
    await _service.updateSubscription(sub);
  }

  Future<void> delete(String id) async {
    await _service.deleteSubscription(id);
  }

  Future<void> pause(String id, bool pause) async {
    await _service.setPause(id, pause);
  }

  Future<int> count() async {
    return await _service.subscriptionCount();
  }
}
