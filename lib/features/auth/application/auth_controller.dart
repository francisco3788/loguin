import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._client) {
    _session = _client.auth.currentSession;
    _subscription = _client.auth.onAuthStateChange.listen((event) {
      _session = event.session;
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;

  Session? _session;
  bool _isLoading = false;

  Session? get session => _session;
  bool get isLoading => _isLoading;

  Future<void> signIn(String email, String password) {
    return _guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    });
  }

  Future<void> signUp(String email, String password) {
    return _guard(() async {
      await _client.auth.signUp(email: email, password: password);
    });
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> _guard(Future<void> Function() action) async {
    _setLoading(true);
    try {
      await action();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
