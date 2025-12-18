import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _name = "Memuat...";
  String _email = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        setState(() => _email = user.email ?? "-");
        
        final data = await _supabase
            .from('profiles')
            .select('name')
            .eq('id', user.id)
            .single();
            
        if (mounted) {
          setState(() {
            _name = data['name'] ?? "User";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _name = "User");
    }
  }

  Future<void> _logout() async {
    // Tampilkan konfirmasi dulu biar gak kepencet
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Keluar Akun?"),
        content: const Text("Apakah kamu yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Keluar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        // Kembali ke Login Screen dan hapus semua history navigasi
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text("Profil Saya", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isLoading 
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AVATAR BESAR
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(PhosphorIconsFill.user, size: 50, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),

                  // NAMA & EMAIL
                  Text(_name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(_email, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),

                  const SizedBox(height: 50),

                  // TOMBOL LOGOUT
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2), // Merah Muda soft
                        foregroundColor: Colors.red, // Teks Merah
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsFill.signOut, size: 20),
                          const SizedBox(width: 10),
                          Text("Keluar Akun", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}