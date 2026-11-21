import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Centralized Auth State Manager (ChangeNotifier)
class AuthController extends ChangeNotifier {
  static final AuthController instance = AuthController._internal();
  factory AuthController() => instance;
  AuthController._internal();

  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Sign in with Real Supabase Email and Password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithPassword(
        email: email,
        password: password,
      );
      _currentUser = user;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      // Register device token with push notifications
      NotificationService().registerTokenOnLogin();
      return true;
    } catch (e) {
      _isLoading = false;
      // Strip "Exception: " if present for user-friendly UI display
      final msg = e.toString().replaceFirst('Exception: ', '');
      _errorMessage = msg;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await NotificationService().unregisterTokenOnLogout();
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
