import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../config/supabase_config.dart';
import 'auth_state.dart' as app_auth;

class AuthRepository {
  SupabaseClient? _client;
  bool _isConfigured = false;
  Timer? _sessionRefreshTimer;
  final _authStateController = StreamController<app_auth.AuthState>.broadcast();

  Stream<app_auth.AuthState> get authStateChanges => _authStateController.stream;
  app_auth.AuthState _currentState = const app_auth.AuthState();
  app_auth.AuthState get currentState => _currentState;

  AuthRepository() {
    _init();
  }

  void _init() {
    // Safe initialization — don't crash if Supabase is not set up
    try {
      if (!SupabaseConfig.isConfigured) {
        _isConfigured = false;
        _currentState = const app_auth.AuthState(
          error: 'Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY.',
        );
        _authStateController.add(_currentState);
        return;
      }

      _client = Supabase.instance.client;
      _isConfigured = true;
    } catch (e) {
      _isConfigured = false;
      _currentState = app_auth.AuthState(
        error: 'Supabase initialization failed: $e',
      );
      _authStateController.add(_currentState);
      return;
    }

    // Restore session on app start — emit immediately
    try {
      final session = _client!.auth.currentSession;
      if (session != null) {
        _loadProfile(session.user.id);
      }
    } catch (e) {
      // Session restore failed — user will need to login
    }

    _client!.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if ((event == AuthChangeEvent.signedIn ||
               event == AuthChangeEvent.initialSession) &&
              session != null) {
        await _loadProfile(session.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _currentState = const app_auth.AuthState();
        _authStateController.add(_currentState);
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        // Token was refreshed — reload profile to keep state in sync
        await _loadProfile(session.user.id);
      } else if (event == AuthChangeEvent.passwordRecovery && session != null) {
        await _loadProfile(session.user.id);
      }
    });

    // Proactive session refresh: check every 4 minutes if token is near expiry
    _sessionRefreshTimer = Timer.periodic(const Duration(minutes: 4), (_) async {
      try {
        final session = _client?.auth.currentSession;
        if (session == null) return;
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        if (DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 10)))) {
          await _client?.auth.refreshSession();
        }
      } catch (_) {
        // Silent fail — the next API call will trigger a retry
      }
    });
  }

  /// Loads profile from DB. If missing, creates one automatically.
  /// Uses upsert with onConflict to avoid race conditions with the DB trigger.
  Future<void> _loadProfile(String userId) async {
    if (!_isConfigured || _client == null) return;
    try {
      final user = _client!.auth.currentUser;
      if (user == null) return;

      // First attempt — fetch existing profile
      var response = await _client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Profile missing — the DB trigger (handle_new_user) may still be
        // creating it. Use upsert so a concurrent trigger insert is harmless.
        try {
          await _client!.from('profiles').upsert({
            'id': userId,
            'email': user.email,
            'full_name': user.userMetadata?['full_name'] ??
                (user.email?.split('@').first ?? 'مستخدم'),
            'role': 'data_entry',
            'is_active': true,
          }, onConflict: 'id');
        } catch (_) {
          // Ignore — trigger may have inserted first
        }

        // Re-fetch after potential creation
        response = await _client!
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
      }

      if (response != null) {
        _currentState = app_auth.AuthState(
          isAuthenticated: true,
          userId: userId,
          email: response['email'],
          role: _parseRole(response['role']),
          governorateId: response['governorate_id'],
          districtId: response['district_id'],
          fullName: response['full_name'],
          avatarUrl: response['avatar_url'],
        );
      } else {
        // Profile still null — authenticate anyway so user isn't stuck
        _currentState = app_auth.AuthState(
          isAuthenticated: true,
          userId: userId,
          email: user.email,
          fullName: user.email?.split('@').first,
        );
      }
      _authStateController.add(_currentState);
    } catch (e) {
      // On error, still mark as authenticated so user isn't logged out
      _currentState = app_auth.AuthState(
        isAuthenticated: true,
        userId: userId,
        email: _client?.auth.currentUser?.email,
        error: e.toString(),
      );
      _authStateController.add(_currentState);
    }
  }

  /// Safely parse a role string from the DB into [UserRole].
  /// Handles both snake_case (data_entry) and camelCase (dataEntry) values.
  static app_auth.UserRole? _parseRole(String? role) {
    if (role == null) return null;
    // Direct snake_case mapping
    const snakeMap = {
      'data_entry': app_auth.UserRole.dataEntry,
      'admin': app_auth.UserRole.admin,
      'central': app_auth.UserRole.central,
      'governorate': app_auth.UserRole.governorate,
      'district': app_auth.UserRole.district,
    };
    if (snakeMap.containsKey(role)) return snakeMap[role];
    // Fallback: try enum name match
    for (final r in app_auth.UserRole.values) {
      if (r.name == role) return r;
    }
    return null;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    if (!_isConfigured || _client == null) {
      throw StateError('Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY.');
    }

    _currentState = _currentState.copyWith(isLoading: true, error: null);
    _authStateController.add(_currentState);

    try {
      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      _currentState = _currentState.copyWith(isLoading: false, error: e.toString());
      _authStateController.add(_currentState);
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_isConfigured || _client == null) return;
    await _client!.auth.signOut();
  }

  Future<void> refreshSession() async {
    if (!_isConfigured || _client == null) return;
    await _client!.auth.refreshSession();
  }

  bool get isConfigured => _isConfigured;
  bool get isAdmin => _currentState.role == app_auth.UserRole.admin;
  bool get isAuthenticated => _client?.auth.currentUser != null;
  String? get userId => _client?.auth.currentUser?.id;
  String? get accessToken => _client?.auth.currentSession?.accessToken;

  void dispose() {
    _sessionRefreshTimer?.cancel();
    _authStateController.close();
  }
}
