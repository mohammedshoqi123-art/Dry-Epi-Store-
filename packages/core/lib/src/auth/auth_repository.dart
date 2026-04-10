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
    _client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        await _loadProfile(session.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _currentState = const app_auth.AuthState();
        _authStateController.add(_currentState);
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        await _loadProfile(session.user.id);
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

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
        _authStateController.add(_currentState);
      }
    } catch (e) {
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
