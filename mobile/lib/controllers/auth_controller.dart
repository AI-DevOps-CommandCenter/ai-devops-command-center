import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Centralized Auth State Manager (ChangeNotifier)
/// Matches Gayathri's ThemeController.instance design pattern
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

  /// Sign in with Email and Password
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
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Authentication failed. Please check credentials.';
      notifyListeners();
      return false;
    }
  }

  /// One-click Demo Mode Login for presentations
  Future<bool> enterDemoMode() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final user = await _authService.signInDemo();
    _currentUser = user;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Sign out
  void signOut() {
    _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
