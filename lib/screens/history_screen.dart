import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];

  // STATE FILTER
  String _filterType = 'Bulanan'; // Pilihan: Harian, Bulanan, Tahunan
  DateTime _selectedDate = DateTime.now(); // Tanggal yang dipilih user

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  // 1. LOGIKA TARIK DATA DENGAN FILTER
  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. QUERY DASAR (JANGAN PAKAI .order DULU DISINI)
      // Tipe datanya masih "FilterBuilder", jadi masih bisa ditambahin .eq, .gte, dll.
      var query = _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId);

      // 2. TERAPKAN FILTER TANGGAL
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (_filterType == 'Harian') {
        // Filter Harian
        query = query.eq('date', dateStr);
      } else if (_filterType == 'Bulanan') {
        // Filter Bulanan
        final startMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final nextMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          1,
        );

        query = query
            .gte('date', DateFormat('yyyy-MM-dd').format(startMonth))
            .lt('date', DateFormat('yyyy-MM-dd').format(nextMonth));
      } else if (_filterType == 'Tahunan') {
        // Filter Tahunan
        final startYear = DateTime(_selectedDate.year, 1, 1);
        final nextYear = DateTime(_selectedDate.year + 1, 1, 1);

        query = query
            .gte('date', DateFormat('yyyy-MM-dd').format(startYear))
            .lt('date', DateFormat('yyyy-MM-dd').format(nextYear));
      }

      // 3. BARU KITA ORDER (URUTKAN) DI AKHIR SEBELUM EKSEKUSI (await)
      // .order() ditaruh disini biar tidak error
      final response = await query.order('date', ascending: false);

      final List<dynamic> data = response;

      if (mounted) {
        setState(() {
          _transactions = data
              .map((json) => TransactionModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error history: $e");
    }
  }

  // 2. FUNGSI HAPUS (Sama kayak di Home)
  Future<void> _deleteTransaction(int id) async {
    try {
      await _supabase.from('transactions').delete().eq('id', id);
      _fetchTransactions(); // Refresh
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Dihapus!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // 3. PICKER TANGGAL
  Future<void> _pickDate() async {
    // Kalau tahunan, kita pakai DatePicker biasa tapi nanti cuma ambil tahunnya
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _fetchTransactions(); // Langsung refresh data pas ganti tanggal
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Label Tanggal Dinamis (Biar user tau lagi liat data apa)
    String dateLabel = "";
    if (_filterType == 'Harian') {
      dateLabel = DateFormat(
        'EEEE, d MMMM yyyy',
        'id_ID',
      ).format(_selectedDate);
    } else if (_filterType == 'Bulanan') {
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    } else {
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER FILTER ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Riwayat Transaksi",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 1. TOMBOL PILIH TIPE FILTER
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("Harian"),
                        const SizedBox(width: 10),
                        _buildFilterChip("Bulanan"),
                        const SizedBox(width: 10),
                        _buildFilterChip("Tahunan"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 2. TOMBOL PILIH TANGGAL
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                dateLabel,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- LIST TRANSAKSI ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                  ? Center(
                      child: Text(
                        "Tidak ada transaksi di periode ini",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final trx = _transactions[index];
                        final isExpense = trx.category?.isExpense ?? true;

                        return Dismissible(
                          key: Key(trx.id.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Hapus?"),
                                content: const Text(
                                  "Data akan hilang permanen.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Batal"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      "Hapus",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (d) => _deleteTransaction(trx.id),
                          child: GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InputTransactionScreen(
                                    transactionToEdit: trx,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _fetchTransactions(); // Refresh setelah edit
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isExpense
                                          ? AppColors.expense.withOpacity(0.1)
                                          : AppColors.income.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isExpense
                                          ? PhosphorIcons.arrowUp()
                                          : PhosphorIcons.arrowDown(),
                                      color: isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trx.category?.name ?? "Umum",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        // Tampilkan Tanggal Lengkap disini karena ini History
                                        Text(
                                          DateFormat(
                                            'd MMM yyyy • HH:mm',
                                            'id_ID',
                                          ).format(trx.date),
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (trx.note != null &&
                                            trx.note!.isNotEmpty)
                                          Text(
                                            trx.note!,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    (isExpense ? "- " : "+ ") +
                                        currencyFormat.format(trx.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET CHIP FILTER
  Widget _buildFilterChip(String label) {
    final bool isSelected = _filterType == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _filterType = label;
            _fetchTransactions(); // Refresh data saat ganti tipe filter
          });
        }
      },
    );
  }
}
