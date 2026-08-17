import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final BiometricService _biometricService = BiometricService();

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  BiometricService get biometricService => _biometricService;

  // Check if user is logged in
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Verify token by fetching user data
      final response = await ApiService.get(ApiConstants.me);
      
      if (response['success'] == true && response['data'] != null) {
        _user = User.fromJson(response['data']['user']);
        _status = AuthStatus.authenticated;
      } else {
        await ApiService.deleteToken();
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    double? monthlyBudget,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        ApiConstants.register,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'monthlyBudget': monthlyBudget ?? 0,
        },
        requiresAuth: false,
      );

      if (response['success'] == true && response['data'] != null) {
        await ApiService.saveToken(response['data']['token']);
        _user = User.fromJson(response['data']['user']);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Registration failed';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
    bool saveForBiometric = false,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        ApiConstants.login,
        body: {
          'email': email,
          'password': password,
        },
        requiresAuth: false,
      );

      if (response['success'] == true && response['data'] != null) {
        await ApiService.saveToken(response['data']['token']);
        _user = User.fromJson(response['data']['user']);
        _status = AuthStatus.authenticated;
        
        // Save credentials for biometric login if requested
        if (saveForBiometric) {
          await _biometricService.saveCredentials(email: email, password: password);
        }
        
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Login failed';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Login with biometric/device credentials
  Future<bool> loginWithBiometric() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // First authenticate with biometrics/PIN
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to access Finzo',
      );
      
      if (!authenticated) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Authentication cancelled';
        notifyListeners();
        return false;
      }

      // Get saved credentials
      final credentials = await _biometricService.getSavedCredentials();
      if (credentials == null) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'No saved credentials found';
        notifyListeners();
        return false;
      }

      // Login with saved credentials
      return await login(
        email: credentials['email']!,
        password: credentials['password']!,
        saveForBiometric: false,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Update profile
  Future<bool> updateProfile({String? name, double? monthlyBudget, double? savingsTarget, String? profilePicture, String? upiId}) async {
    try {
      Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (monthlyBudget != null) body['monthlyBudget'] = monthlyBudget;
      if (savingsTarget != null) body['savingsTarget'] = savingsTarget;
      if (profilePicture != null) body['profilePicture'] = profilePicture;
      if (upiId != null) body['upiId'] = upiId;

      final response = await ApiService.put(
        ApiConstants.updateProfile,
        body: body,
      );

      if (response['success'] == true && response['data'] != null) {
        _user = User.fromJson(response['data']['user']);
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Update failed';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await ApiService.deleteToken();
    await _storage.delete(key: StorageKeys.user);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}


