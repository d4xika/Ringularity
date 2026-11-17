import '../../models/app_user.dart';
import 'storage_service.dart';

class AuthService {
  AppUser? _currentUser;
  int _revision = -1;

  AppUser? get currentUser =>
      _revision == StorageService.revision ? _currentUser : null;

  Future<void> saveUserLocally(AppUser user) async {
    final owner = StorageService.requireSession();
    await StorageService.saveUserProfile(user);
    owner.check();
    _currentUser = user;
    _revision = owner.revision;
  }

  Future<void> loadCachedUser() async {
    final owner = StorageService.requireSession();
    final user = await StorageService.getUserProfile();
    owner.check();
    _currentUser = user;
    _revision = owner.revision;
  }

  Future<void> logout() async {
    _currentUser = null;
    await StorageService.deleteAll();
  }
}
