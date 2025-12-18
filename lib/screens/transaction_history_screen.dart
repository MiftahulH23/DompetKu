import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final bool isExpense; // True = Pengeluaran, False = Pemasukan

  const TransactionHistoryScreen({super.key, required this.isExpense});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];

  // FILTER STATE
  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Query Dasar
      var query = _supabase
          .from('transactions')
          .select('*, categories!inner(*)')
          .eq('user_id', userId)
          .eq(
            'categories.is_expense',
            widget.isExpense,
          ); // Filter sesuai Tab (Masuk/Keluar)

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Logika Filter Waktu
      if (_filterType == 'Harian') {
        query = query.eq('date', dateStr);
      } else if (_filterType == 'Bulanan') {
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
        final startYear = DateTime(_selectedDate.year, 1, 1);
        final nextYear = DateTime(_selectedDate.year + 1, 1, 1);
        query = query
            .gte('date', DateFormat('yyyy-MM-dd').format(startYear))
            .lt('date', DateFormat('yyyy-MM-dd').format(nextYear));
      }

      final response = await query.order(
        'date',
        ascending: false,
      ); // Urutkan dari yang terbaru
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
    }
  }

  Future<void> _deleteTransaction(int id) async {
    try {
      await _supabase.from('transactions').delete().eq('id', id);
      _fetchTransactions();
      if (mounted) AppNotification.success(context, "Transaksi dihapus!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal hapus: $e");
    }
  }

  Future<void> _pickSmartDate() async {
    // Logic Date Picker
    if (_filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('id', 'ID'),
      );
      if (picked != null) setState(() => _selectedDate = picked);
    } else if (_filterType == 'Tahunan') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Pilih Tahun"),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              selectedDate: _selectedDate,
              onChanged: (dt) {
                setState(() => _selectedDate = dt);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ).then((_) => _fetchTransactions());
    } else {
      final months = [
        "Januari",
        "Februari",
        "Maret",
        "April",
        "Mei",
        "Juni",
        "Juli",
        "Agustus",
        "September",
        "Oktober",
        "November",
        "Desember",
      ];
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Pilih Bulan (${_selectedDate.year})"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
              ),
              itemCount: months.length,
              itemBuilder: (ctx, index) {
                return InkWell(
                  onTap: () {
                    setState(
                      () => _selectedDate = DateTime(
                        _selectedDate.year,
                        index + 1,
                        1,
                      ),
                    );
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedDate.month == (index + 1)
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      months[index],
                      style: TextStyle(
                        color: _selectedDate.month == (index + 1)
                            ? Colors.white
                            : Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Ganti Tahun"),
                    content: SizedBox(
                      width: 300,
                      height: 300,
                      child: YearPicker(
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        selectedDate: _selectedDate,
                        onChanged: (dt) {
                          setState(
                            () => _selectedDate = DateTime(
                              dt.year,
                              _selectedDate.month,
                              1,
                            ),
                          );
                          Navigator.pop(context);
                          _fetchTransactions();
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Text("Ganti Tahun (${_selectedDate.year})"),
            ),
          ],
        ),
      ).then((_) => _fetchTransactions());
    }
    if (_filterType == 'Harian') _fetchTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final String pageTitle = widget.isExpense ? "Pengeluaran" : "Pemasukan";
    final Color themeColor = widget.isExpense
        ? AppColors.expense
        : AppColors.income;

    String dateLabel = "";
    if (_filterType == 'Harian')
      dateLabel = DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate);
    else if (_filterType == 'Bulanan')
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    else
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER FILTER
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
                    "Riwayat $pageTitle",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _buildFilterBtn("Harian", themeColor),
                      const SizedBox(width: 10),
                      _buildFilterBtn("Bulanan", themeColor),
                      const SizedBox(width: 10),
                      _buildFilterBtn("Tahunan", themeColor),
                    ],
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: _pickSmartDate,
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
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: themeColor,
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

            // LIST TRANSAKSI
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                  ? Center(
                      child: Text(
                        "Belum ada data $pageTitle",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final trx = _transactions[index];

                        // LOGIKA NOTE
                        final String noteText =
                            (trx.note != null && trx.note!.isNotEmpty)
                            ? trx.note!
                            : "Tidak ada catatan";
                        final Color noteColor =
                            (trx.note != null && trx.note!.isNotEmpty)
                            ? Colors.grey.shade600
                            : Colors.grey.shade400;

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
                          confirmDismiss: (d) async => await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Hapus?"),
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
                          ),
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
                              if (result == true) _fetchTransactions();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ICON
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: themeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      widget.isExpense
                                          ? PhosphorIcons.arrowUp()
                                          : PhosphorIcons.arrowDown(),
                                      color: themeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 15),

                                  // TEXT CENTER (Kategori & Catatan)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // JUDUL KATEGORI
                                        Text(
                                          trx.category?.name ?? "Umum",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // CATATAN
                                        Text(
                                          noteText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: noteColor,
                                            fontSize: 12,
                                            fontStyle:
                                                (trx.note == null ||
                                                    trx.note!.isEmpty)
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // KOLOM KANAN (Nominal & Tanggal)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end, // Rata Kanan
                                    children: [
                                      // JUMLAH UANG
                                      Text(
                                        currencyFormat.format(trx.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: themeColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // TANGGAL (Sekarang di bawah Nominal)
                                      Text(
                                        DateFormat(
                                          'd MMM yyyy',
                                          'id_ID',
                                        ).format(trx.date),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
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

  Widget _buildFilterBtn(String label, Color themeColor) {
    final bool isSelected = _filterType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() {
              _filterType = label;
              _fetchTransactions();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.textPrimary : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
