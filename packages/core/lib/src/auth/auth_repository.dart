import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../config/supabase_config.dart';
import 'auth_state.dart' as app_auth;

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;
  final _authStateController = StreamController<app_auth.AuthState>.broadcast();

  Stream<app_auth.AuthState> get authStateChanges => _authStateController.stream;
  app_auth.AuthState _currentState = const app_auth.AuthState();
  app_auth.AuthState get currentState => _currentState;

  AuthRepository() {
    _init();
  }

  void _init() {
    // Restore session on app start — emit immediately
    final session = _client.auth.currentSession;
    if (session != null) {
      _loadProfile(session.user.id);
    }

    _client.auth.onAuthStateChange.listen((data) async {
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
        await _loadProfile(session.user.id);
      }
    });
  }

  /// Loads profile from DB. If missing, creates one automatically.
  Future<void> _loadProfile(String userId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      var response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // Auto-create profile if missing (trigger was removed)
      if (response == null) {
        await _client.from('profiles').upsert({
          'id': userId,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ??
              (user.email?.split('@').first ?? 'مستخدم'),
          'role': 'data_entry',
          'is_active': true,
        });

        // Re-fetch after creation
        response = await _client
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
        // Profile still null after creation — authenticate anyway
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
        email: _client.auth.currentUser?.email,
        error: e.toString(),
      );
      _authStateController.add(_currentState);
    }
  }

  app_auth.UserRole? _parseRole(String? role) {
    if (role == null) return null;
    return app_auth.UserRole.values.cast<app_auth.UserRole?>().firstWhere(
      (r) => r?.name == role,
      orElse: () => null,
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    _currentState = _currentState.copyWith(isLoading: true, error: null);
    _authStateController.add(_currentState);

    try {
      final response = await _client.auth.signInWithPassword(
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
    await _client.auth.signOut();
  }

  Future<void> refreshSession() async {
    await _client.auth.refreshSession();
  }

  bool get isAdmin => _currentState.role == app_auth.UserRole.admin;
  bool get isAuthenticated => _client.auth.currentUser != null;
  String? get userId => _client.auth.currentUser?.id;
  String? get accessToken => _client.auth.currentSession?.accessToken;

  void dispose() {
    _authStateController.close();
  }
}
