import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/login_screen.dart';
import 'package:catat_uang_app/screens/manage_category_screen.dart';
import 'package:catat_uang_app/screens/stats_screen.dart';
import 'package:catat_uang_app/screens/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; 
  // 0 = Home
  // 1 = Pemasukan (History Income)
  // 2 = Pengeluaran (History Expense)
  // 3 = Laporan (Stats)
  
  final SupabaseClient _supabase = Supabase.instance.client;

  String _userName = "Memuat...";
  List<TransactionModel> _recentTransactions = []; 
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserProfile();
    _fetchHomeData();
  }

  // 1. AMBIL PROFIL USER
  Future<void> _getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted) setState(() => _userName = data != null ? data['name'] : (user.userMetadata?['name'] ?? "User"));
    } catch (e) { debugPrint("Error user: $e"); }
  }

  // 2. AMBIL DATA HOME (Saldo & 5 Transaksi Terakhir)
  Future<void> _fetchHomeData() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Hitung Saldo Total (Tanpa Limit)
      final allTrxResponse = await _supabase.from('transactions').select('amount, categories(is_expense)').eq('user_id', userId);
      double income = 0;
      double expense = 0;
      for (var item in allTrxResponse) {
        final amount = (item['amount'] as num).toDouble();
        final isExpense = item['categories']['is_expense'] as bool;
        if (isExpense) {
          expense += amount;
        } else {
          income += amount;
        }
      }

      // Ambil 5 Transaksi Terbaru
      final recentResponse = await _supabase
          .from('transactions')
          .select('*, categories(*)') 
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _recentTransactions = (recentResponse as List).map((json) => TransactionModel.fromJson(json)).toList();
          _totalIncome = income;
          _totalExpense = expense;
          _totalBalance = income - expense;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. LOGOUT
  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  // 4. WIDGET HALAMAN HOME (Dashboard)
  Widget _buildHomeContent() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return SafeArea(
      child: Column(
        children: [
          // HEADER & CARD SALDO
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Halo, Bos!", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        Text(_userName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        // Tombol Kelola Kategori
                        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCategoryScreen())), child: CircleAvatar(backgroundColor: AppColors.background, child: Icon(PhosphorIcons.gear(), color: AppColors.primary))),
                        const SizedBox(width: 10),
                        // Tombol Logout
                        GestureDetector(onTap: _logout, child: CircleAvatar(backgroundColor: AppColors.background, child: Icon(PhosphorIcons.signOut(), color: AppColors.expense))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // KARTU BIRU
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Total Saldo", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 5),
                    Text(currencyFormat.format(_totalBalance), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(children: [
                      _buildSummaryItem(PhosphorIcons.arrowDown(PhosphorIconsStyle.bold), "Pemasukan", currencyFormat.format(_totalIncome), AppColors.income),
                      const Spacer(),
                      _buildSummaryItem(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold), "Pengeluaran", currencyFormat.format(_totalExpense), AppColors.expense),
                    ])
                  ]),
                ),
              ],
            ),
          ),
          
          // JUDUL LIST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Terbaru", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ]),
          ),
          
          // LIST 5 TERAKHIR
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _recentTransactions.isEmpty 
                ? const Center(child: Text("Belum ada transaksi"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _recentTransactions.length,
                    itemBuilder: (context, index) {
                      final trx = _recentTransactions[index];
                      final isExpense = trx.category?.isExpense ?? true;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(15)),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isExpense ? AppColors.expense.withOpacity(0.1) : AppColors.income.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isExpense ? PhosphorIcons.arrowUp() : PhosphorIcons.arrowDown(), color: isExpense ? AppColors.expense : AppColors.income)),
                          const SizedBox(width: 15),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trx.category?.name ?? "Umum", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)), Text(DateFormat('d MMM yyyy', 'id_ID').format(trx.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))])),
                          Text((isExpense ? "- " : "+ ") + currencyFormat.format(trx.amount), style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? AppColors.expense : AppColors.income)),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String amount, Color color) {
    return Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)), Text(amount, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))])]);
  }

  // --- BUILD UTAMA ---
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),     
      
      // Index 1: Pemasukan (Pakai Key biar direfresh saat pindah tab)
      const TransactionHistoryScreen(
        key: ValueKey('pemasukan'), 
        isExpense: false
      ), 
      
      // Index 2: Pengeluaran (Pakai Key biar direfresh saat pindah tab)
      const TransactionHistoryScreen(
        key: ValueKey('pengeluaran'), 
        isExpense: true
      ),  
      
      const StatsScreen(), // Index 3: Laporan
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      
      // TOMBOL (+) TENGAH
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const InputTransactionScreen()));
          if (result == true) {
            _fetchHomeData();
            setState(() {}); // Paksa refresh UI agar halaman history juga ikut ke-update
          }
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // NAVIGASI BAWAH
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: AppColors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. HOME
            IconButton(
              tooltip: "Home",
              icon: Icon(_selectedIndex == 0 ? PhosphorIcons.house(PhosphorIconsStyle.fill) : PhosphorIcons.house(), color: _selectedIndex == 0 ? AppColors.primary : AppColors.textSecondary),
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
            
            // 2. PEMASUKAN (ICON DOMPET)
            IconButton(
              tooltip: "Pemasukan",
              icon: Icon(
                _selectedIndex == 1 ? PhosphorIcons.wallet(PhosphorIconsStyle.fill) : PhosphorIcons.wallet(), 
                color: _selectedIndex == 1 ? AppColors.income : AppColors.textSecondary
              ),
              onPressed: () => setState(() => _selectedIndex = 1),
            ),
            
            const SizedBox(width: 20), // Spacer FAB

            // 3. PENGELUARAN (ICON STRUK)
            IconButton(
              tooltip: "Pengeluaran",
              icon: Icon(
                _selectedIndex == 2 ? PhosphorIcons.receipt(PhosphorIconsStyle.fill) : PhosphorIcons.receipt(), 
                color: _selectedIndex == 2 ? AppColors.expense : AppColors.textSecondary
              ),
              onPressed: () => setState(() => _selectedIndex = 2),
            ),

            // 4. LAPORAN
            IconButton(
              tooltip: "Laporan",
              icon: Icon(_selectedIndex == 3 ? PhosphorIcons.chartPieSlice(PhosphorIconsStyle.fill) : PhosphorIcons.chartPieSlice(), color: _selectedIndex == 3 ? AppColors.primary : AppColors.textSecondary),
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}