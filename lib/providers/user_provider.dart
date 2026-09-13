// lib/providers/user_provider.dart
//
// UserProvider holds the signed-in user for the widget tree. All session work —
// the API calls and the SharedPreferences writes — belongs to SessionRepository;
// this class is state plus delegation. See docs/adr/0005-session-repository.md.

import 'package:flutter/foundation.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/repositories/session_repository.dart';

class UserProvider extends ChangeNotifier {
  final SessionRepository _session;

  /// Injectable for tests; defaults to a real repository. See ADR-0004.
  UserProvider({SessionRepository? session})
      : _session = session ?? SessionRepository();

  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userProfile != null;
  String? get error => _error;

  // Initialize user on app start
  Future<void> initUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await _session.isLoggedIn()) {
        _userProfile = await _session.loadProfile();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load or refresh user profile
  Future<void> loadUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _session.loadProfile();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      _error = null;
      _userProfile = await _session.updateProfile(profile);
      notifyListeners();
      return _userProfile!;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Set user after login or onboarding
  Future<void> setUser(UserProfile profile) async {
    _userProfile = profile;
    await _session.startSession(profile.id, profile: profile);
    notifyListeners();
  }

  // Complete onboarding
  Future<String?> completeOnboarding(Map<String, dynamic> onboardingData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = await _session.completeOnboarding(onboardingData);
      // The account exists from here on. If the profile is unreadable the id is
      // still returned, because reporting failure would invite a retry that
      // re-registers the same email. Callers check [userProfile] to tell a
      // finished sign-up from a profile-pending one.
      _userProfile = await _session.loadProfile();
      return userId;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Throws SessionException when authentication fails — offline, bad
      // credentials, or a cold-start timeout — carrying the message the login
      // screen shows. A null result means the credentials were accepted but the
      // profile read failed; the session is real, so finish it with a load
      // rather than sending the user back to the login form.
      _userProfile = await _session.login(email, password);
      _userProfile ??= await _session.loadProfile();

      if (_userProfile == null) {
        // Authenticated, but the profile is unreadable. The session stays — a
        // retry will not need to re-authenticate — but every screen past here
        // requires a profile, so this is not a usable state to report as
        // success. The splash screen resolves the same case the same way.
        _error = 'Signed in, but your profile could not be loaded. '
            'Please try again in a moment.';
        return false;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout. Ends the session only: the theme, step baseline, chat cache and
  // supplement preferences survive. Account deletion is a different operation.
  Future<void> logout() async {
    await _session.endSession();
    _userProfile = null;
    _error = null;
    notifyListeners();
  }

  // Refresh profile from backend
  Future<void> refreshProfile() async {
    if (_userProfile == null) return;

    try {
      _error = null;
      final refreshed = await _session.loadProfile();
      if (refreshed != null) {
        _userProfile = refreshed;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
