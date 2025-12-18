import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/screens/login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rsqdexzywegorsgmledp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzcWRleHp5d2Vnb3JzZ21sZWRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTY0NDEsImV4cCI6MjA4MTUzMjQ0MX0.4UpocbbB-OUiTPEw0BLwc1DzMhcX13VboP4USN8ZYR0',
  );
  await initializeDateFormatting('id_ID', null);
  // try {
  //   // Kita coba ambil data dari tabel 'categories'
  //   final data = await Supabase.instance.client.from('categories').select();
  //   print('✅✅✅ MANTAP! KONEKSI BERHASIL. INI DATANYA: $data');
  // } catch (e) {
  //   print('❌❌❌ WADUH! KONEKSI GAGAL: $e');
  // }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DompetKu',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      
      // 2. TAMBAHKAN BAGIAN INI (Delegate Bahasa)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // 3. DAFTARKAN BAHASA YANG DIDUKUNG
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia (Prioritas 1)
        Locale('en', 'US'), // Bahasa Inggris (Cadangan)
      ],
      // -----------------------------------------------------

      home: user != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}