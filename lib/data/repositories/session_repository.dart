// lib/data/repositories/session_repository.dart
//
// SessionRepository: the one owner of "who is signed in". It hides AuthApi and
// SharedPreferences behind a single interface, in the same shape ADR-0001 kept
// for StepRepository and SleepRepository. See docs/adr/0005-session-repository.md.
//
// It replaces two overlapping owners — DataManager's session half and the whole
// of UserManager — which declared the same keys and wrote them differently. The
// invariant "a cached profile implies is_logged_in" used to be upheld by every
// call site remembering to pair two calls; here it is structural, because the
// three write operations below are the only ways the keys change.
//
// Collaborators are injected as normalized function typedefs with real defaults,
// matching DailySnapshot (ADR-0002). SharedPreferences is deliberately NOT
// abstracted: setMockInitialValues already gives tests full control, so a seam
// there would be depth for its own sake.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/auth_api.dart';
import 'package:user_onboarding/data/services/connectivity_service.dart';
import 'package:user_onboarding/utils/profile_update_notifier.dart';

typedef LoginCaller = Future<Map<String, dynamic>> Function(
    String email, String password);
typedef ProfileFetcher = Future<UserProfile?> Function(String userId);
typedef ProfileUpdater = Future<UserProfile> Function(UserProfile profile);
typedef OnboardingSubmitter = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> onboardingData);
typedef ConnectivityCheck = Future<bool> Function();

/// Thrown when a session operation cannot complete. [message] is user-facing:
/// the cold-start wording in particular is the text the login screen shows.
class SessionException implements Exception {
  final String message;
  const SessionException(this.message);
  @override
  String toString() => message;
}

class SessionRepository {
  /// The session's keys. This class is their only writer.
  static const String userIdKey = 'user_id';
  static const String userProfileKey = 'user_profile';
  static const String isLoggedInKey = 'is_logged_in';

  final LoginCaller _login;
  final ProfileFetcher _fetchProfile;
  final ProfileUpdater _pushProfile;
  final OnboardingSubmitter _submitOnboarding;
  final ConnectivityCheck _isConnected;

  SessionRepository({
    LoginCaller? login,
    ProfileFetcher? fetchProfile,
    ProfileUpdater? pushProfile,
    OnboardingSubmitter? submitOnboarding,
    ConnectivityCheck? isConnected,
  })  : _login = login ?? AuthApi().loginUser,
        _fetchProfile = fetchProfile ?? AuthApi().getUserProfileById,
        _pushProfile = pushProfile ?? AuthApi().updateUserProfile,
        _submitOnboarding = submitOnboarding ?? AuthApi().completeOnboarding,
        _isConnected = isConnected ?? ConnectivityService().isConnected;

  // --- Session state -------------------------------------------------------

  /// Writes the full session: the user is now signed in. Used by login and by
  /// onboarding, the only two ways a session begins.
  ///
  /// [profile] is optional because authenticating and holding a profile are two
  /// steps, not one: the server can accept the credentials and then fail the
  /// follow-up profile read. The session is real either way, and [loadProfile]
  /// will fill the gap. When there is no profile, any cached one is dropped
  /// rather than left behind — it may belong to the previous user.
  Future<void> startSession(String userId, {UserProfile? profile}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userIdKey, userId);
    if (profile != null) {
      await prefs.setString(userProfileKey, jsonEncode(profile.toMap()));
    } else {
      await prefs.remove(userProfileKey);
    }
    await prefs.setBool(isLoggedInKey, true);
  }

  /// [profile] with [userId] filled in when the server omitted it.
  UserProfile _withId(UserProfile profile, String userId) =>
      (profile.id.isEmpty)
          ? profile.copyWith(id: userId)
          : profile;

  /// Refreshes the cached profile without asserting anything about sign-in.
  /// Used when an already-signed-in user's profile changes.
  Future<void> cacheProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userIdKey, profile.id);
    await prefs.setString(userProfileKey, jsonEncode(profile.toMap()));
  }

  /// Ends the session and nothing more.
  ///
  /// The predecessor was `prefs.clear()`, which also destroyed the theme
  /// setting, the step-accrual baseline, the chat cache and supplement
  /// preferences. Deleting an *account* still wipes everything — that is
  /// settings_page's job, not this one's. See ADR-0005, change 2.
  Future<void> endSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userIdKey);
    await prefs.remove(userProfileKey);
    await prefs.setBool(isLoggedInKey, false);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isLoggedInKey) ?? false;
  }

  Future<String?> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  /// The cached profile, or null when nobody is signed in.
  Future<UserProfile?> currentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(isLoggedInKey) ?? false)) return null;
    return _decodeCached(prefs);
  }

  // --- Operations ----------------------------------------------------------

  /// Signs in, returning the profile when it could be read.
  ///
  /// Throws [SessionException] only when *authentication* fails — offline, bad
  /// credentials, or a cold-start timeout. The backend spins down when idle, so
  /// a first request after a quiet period can take 30–50s; the 60s budget
  /// matches AuthApi.loginUser, and the login screen fires a warm-up ping on
  /// open.
  ///
  /// Returns null when the credentials were accepted but the follow-up profile
  /// read failed. The session is still started, because it is real: making the
  /// user authenticate again over a transient blip on a cold-starting backend
  /// would be the wrong answer. Callers finish with [loadProfile].
  Future<UserProfile?> login(String email, String password) async {
    if (!await _isConnected()) {
      throw const SessionException('No internet connection');
    }

    late final Map<String, dynamic> result;
    try {
      result = await _login(email, password).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw const SessionException(
          'The server is taking longer than usual to respond (it may be '
          'waking up). Please try again in a moment.',
        ),
      );
    } on SessionException {
      await _markSignedOut();
      rethrow;
    } catch (e) {
      await _markSignedOut();
      throw SessionException('Login failed: $e');
    }

    if (result['success'] != true || result['user'] == null) {
      await _markSignedOut();
      throw SessionException(result['message']?.toString() ?? 'Login failed');
    }

    final userId = result['user']['id']?.toString();
    if (userId == null || userId.isEmpty) {
      await _markSignedOut();
      throw const SessionException('Login failed: no user id returned');
    }

    // Authentication succeeded, so the session begins here regardless of what
    // the profile read does next.
    UserProfile? profile;
    try {
      final fetched = await _fetchProfile(userId);
      profile = fetched == null ? null : _withId(fetched, userId);
    } catch (_) {
      profile = null;
    }

    await startSession(userId, profile: profile);
    return profile;
  }

  /// The current profile, preferring the server and falling back to the cache.
  ///
  /// The fallback is a *read* cache: it never invents data the server does not
  /// have. It matters because the backend cold-starts, and an empty profile
  /// while it wakes up would be a worse answer than a slightly stale one.
  Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(userIdKey);

    if (userId != null && userId.isNotEmpty && await _isConnected()) {
      try {
        var profile = await _fetchProfile(userId);
        if (profile != null) {
          if (profile.id.isEmpty) {
            profile = profile.copyWith(id: userId);
          }
          await cacheProfile(profile);
          return profile;
        }
      } catch (_) {
        // Fall through to the cache.
      }
    }

    return _decodeCached(prefs, fallbackId: userId);
  }

  /// Pushes a profile change to the server (when reachable) and caches the
  /// result either way, then notifies listeners.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    var updated = profile;

    if (await _isConnected()) {
      try {
        updated = await _pushProfile(profile);
      } catch (_) {
        // Keep the local edit; the server copy will reconcile on next load.
      }
    }

    await cacheProfile(updated);
    ProfileUpdateNotifier().notifyProfileUpdate(updated);
    return updated;
  }

  /// Completes onboarding and starts the session. Returns the new user id.
  ///
  /// Requires connectivity, exactly as [login] does. The predecessor invented a
  /// timestamp id offline and built a profile from a stub that kept only name
  /// and email, producing an account no backend row matched and nothing ever
  /// synced. See ADR-0005, change 3.
  Future<String> completeOnboarding(Map<String, dynamic> onboardingData) async {
    if (!await _isConnected()) {
      throw const SessionException(
        'Finishing setup needs an internet connection. Please reconnect and '
        'try again.',
      );
    }

    final Map<String, dynamic> response;
    try {
      response = await _submitOnboarding(onboardingData);
    } catch (e) {
      throw SessionException('Could not complete setup: $e');
    }

    final userId =
        response['success'] == true ? response['userId']?.toString() : null;
    if (userId == null || userId.isEmpty) {
      throw SessionException(
        response['message']?.toString() ?? 'Could not complete setup',
      );
    }

    // The account now exists. Everything past this point is best-effort: a
    // failed profile read must not be reported as a failed sign-up, or the
    // dialog offers "Try Again" and the retry collides with the email that was
    // just registered.
    UserProfile? profile;
    try {
      final fetched = await _fetchProfile(userId);
      profile = fetched == null ? null : _withId(fetched, userId);
    } catch (_) {
      profile = null;
    }

    await startSession(userId, profile: profile);
    return userId;
  }

  // --- Internals -----------------------------------------------------------

  UserProfile? _decodeCached(SharedPreferences prefs, {String? fallbackId}) {
    final json = prefs.getString(userProfileKey);
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final id = fallbackId ?? prefs.getString(userIdKey);
      if (id != null && id.isNotEmpty) map['id'] = id;
      return UserProfile.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _markSignedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(isLoggedInKey, false);
    } catch (_) {
      // Best effort; a failed write here must not mask the original error.
    }
  }
}
