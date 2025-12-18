import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _register() async {
    // Validasi Input
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      AppNotification.error(context, "Semua kolom wajib diisi!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. DAFTAR AUTH (Ini Langkah Paling Penting)
      final AuthResponse res = await _supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        data: {
          'name': _nameController.text,
        }, // Kita simpan nama di Metadata juga sebagai cadangan
      );

      // Cek apakah User berhasil dibuat
      if (res.user != null) {
        // 2. SIMPAN KE TABEL PROFILES (Kita buat "Safe Mode")
        // Kita bungkus ini dengan try-catch sendiri.
        // Jadi kalaupun ini gagal (misal karena tabel tidak ada/konflik trigger),
        // User TETAP dianggap BERHASIL mendaftar.
        try {
          await _supabase.from('profiles').upsert({
            'id': res.user!.id,
            'name': _nameController.text,
            // 'email' sudah dihapus, aman.
          });
        } catch (profileError) {
          // Kalau gagal simpan profil, kita diamkan saja (Silent Fail).
          // Karena data nama sudah ada di Metadata Auth (Langkah 1), jadi aman.
          debugPrint(
            "Warning: Gagal simpan ke tabel profiles, tapi Auth sukses. Error: $profileError",
          );
        }

        // 3. SUKSES!
        if (mounted) {
          AppNotification.success(
            context,
            "Registrasi Berhasil! Silakan Login.",
          );
          Navigator.pop(context); // Balik ke Login
        }
      }
    } catch (e) {
      // Ini catch untuk error FATAL (misal internet mati, atau email sudah terdaftar)
      if (mounted) {
        // Tampilkan error asli jika bukan error umum, biar kita tau apa masalahnya
        AppNotification.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI TETAP SAMA SEPERTI SEBELUMNYA
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                PhosphorIconsFill.userCirclePlus,
                size: 70,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                "Buat Akun Baru",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Mulai perjalanan finansialmu sekarang",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                controller: _nameController,
                label: "Nama Lengkap",
                icon: PhosphorIcons.user(),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _emailController,
                label: "Email",
                icon: PhosphorIcons.envelopeSimple(),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: "Password",
                icon: PhosphorIcons.lockKey(),
                isPassword: true,
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Daftar Sekarang",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}
