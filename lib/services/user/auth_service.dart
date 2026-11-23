import '../../models/app_user.dart';
import 'storage_service.dart';

/// Exposes a locally cached user only while its account generation remains current.
class AuthService {
  AppUser? _currentUser;
  int _revision = -1;

  /// Cached profile for the current generation, or null after logout or an account switch.
  AppUser? get currentUser =>
      _revision == StorageService.revision ? _currentUser : null;

  /// Persists the profile and publishes it only if its original session is still active.
  Future<void> saveUserLocally(AppUser user) async {
    final owner = StorageService.requireSession();
    await StorageService.saveUserProfile(user);
    owner.check();
    _currentUser = user;
    _revision = owner.revision;
  }

  /// Restores the owning account’s profile and rejects a delayed result after logout.
  Future<void> loadCachedUser() async {
    final owner = StorageService.requireSession();
    final user = await StorageService.getUserProfile();
    owner.check();
    _currentUser = user;
    _revision = owner.revision;
  }

  /// Clears the in-memory profile and signs out without erasing account-specific disk caches.
  Future<void> logout() async {
    _currentUser = null;
    await StorageService.deleteAll();
  }
}
