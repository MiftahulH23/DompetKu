import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Fungsi Daftar (Register)
  Future<AuthResponse> signUp(String email, String password, String name) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name}, // Kita kirim nama sebagai metadata (ditangkap Trigger SQL tadi)
    );
  }

  // 2. Fungsi Masuk (Login)
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // 3. Fungsi Keluar (Logout)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // 4. Cek User yang sedang login
  User? get currentUser => _supabase.auth.currentUser;
  
  // 5. Cek apakah ada sesi aktif
  bool get isLoggedIn => _supabase.auth.currentSession != null;
}