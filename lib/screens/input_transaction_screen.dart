import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  const InputTransactionScreen({super.key, this.transactionToEdit});

  @override
  State<InputTransactionScreen> createState() => _InputTransactionScreenState();
}

class _InputTransactionScreenState extends State<InputTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];
  bool _isExpense = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    if (widget.transactionToEdit != null) {
      final trx = widget.transactionToEdit!;
      _amountController.text = _currencyFormat.format(trx.amount);
      _noteController.text = trx.note ?? '';
      _selectedDate = trx.date;
      _selectedCategoryId = trx.categoryId;
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('makan') || name.contains('minum'))
      return PhosphorIcons.bowlFood(PhosphorIconsStyle.fill);
    if (name.contains('transport') || name.contains('bensin'))
      return PhosphorIcons.bus(PhosphorIconsStyle.fill);
    if (name.contains('belanja') || name.contains('mart'))
      return PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill);
    if (name.contains('hiburan') || name.contains('nonton'))
      return PhosphorIcons.gameController(PhosphorIconsStyle.fill);
    if (name.contains('kesehatan') || name.contains('obat'))
      return PhosphorIcons.firstAid(PhosphorIconsStyle.fill);
    if (name.contains('tagihan') || name.contains('listrik'))
      return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
    if (name.contains('gaji'))
      return PhosphorIcons.money(PhosphorIconsStyle.fill);
    if (name.contains('bonus'))
      return PhosphorIcons.gift(PhosphorIconsStyle.fill);
    return PhosphorIcons.tag(PhosphorIconsStyle.fill);
  }

  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .or('user_id.eq.$userId,user_id.is.null');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);

          // LOGIKA PENTING: Set Toggle (Pengeluaran/Pemasukan) sesuai kategori yang diedit
          if (widget.transactionToEdit != null && _selectedCategoryId != null) {
            // Cari kategori yang ID-nya cocok
            final selectedCat = _categories.firstWhere(
              (e) => e['id'] == _selectedCategoryId,
              orElse: () => {},
            );

            // Kalau ketemu, sesuaikan toggle-nya (biar gak salah kamar)
            if (selectedCat.isNotEmpty) {
              _isExpense = selectedCat['is_expense'];
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error cat: $e");
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
      AppNotification.error(context, "Jumlah dan Kategori wajib diisi!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final cleanAmount = _amountController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final amount = int.parse(cleanAmount);

      final data = {
        'user_id': userId,
        'category_id': _selectedCategoryId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'note': _noteController.text,
      };

      if (widget.transactionToEdit == null) {
        await _supabase.from('transactions').insert(data);
        if (mounted) {
          AppNotification.success(context, "Transaksi berhasil disimpan!");
          Navigator.pop(context, true);
        }
      } else {
        await _supabase
            .from('transactions')
            .update(data)
            .eq('id', widget.transactionToEdit!.id);
        if (mounted) {
          AppNotification.success(context, "Transaksi berhasil diperbarui!");
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories
        .where((c) => c['is_expense'] == _isExpense)
        .toList();

    // HAPUS LOGIKA RESET DISINI AGAR DATA TIDAK HILANG SAAT LOADING
    // Biarkan logic validasi ditangani oleh properti 'value' di DropdownButton saja

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          widget.transactionToEdit == null
              ? "Tambah Transaksi"
              : "Edit Transaksi",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOGGLE
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _buildToggleBtn("Pengeluaran", true),
                  _buildToggleBtn("Pemasukan", false),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 2. NOMINAL
            Text(
              "Nominal",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 5, top: 2),
                  child: Text(
                    "Rp",
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                hintText: "0",
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade300),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (string) {
                string = string.replaceAll(RegExp(r'[^0-9]'), '');
                if (string.isNotEmpty) {
                  final formatted = _currencyFormat.format(int.parse(string));
                  if (_amountController.text != formatted) {
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 30),

            // 3. KATEGORI (BUG FIX DISINI)
            Text(
              "Kategori",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  // FIX: Cek dulu apakah ID ada di list. Kalau ada tampilkan, kalau loading/gak ada kasih null SEMENTARA.
                  // Jangan ubah variabel _selectedCategoryId-nya.
                  value:
                      filteredCategories.any(
                        (cat) => cat['id'] == _selectedCategoryId,
                      )
                      ? _selectedCategoryId
                      : null,

                  hint: Text(
                    // Kalau loading list masih kosong, kasih teks Loading...
                    _categories.isEmpty ? "Memuat..." : "Pilih Kategori",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  items: filteredCategories.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'] as int,
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(cat['name']),
                            color: _isExpense
                                ? AppColors.expense
                                : AppColors.income,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cat['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCategoryId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. TANGGAL
            Text(
              "Tanggal",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsFill.calendarBlank,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat(
                        'EEEE, d MMMM yyyy',
                        'id_ID',
                      ).format(_selectedDate),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. CATATAN
            Text(
              "Catatan (Opsional)",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 1,
              style: GoogleFonts.poppins(),
              decoration: InputDecoration(
                hintText: "Contoh: Beli Nasi Padang",
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.white)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    "Simpan Transaksi",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String title, bool isExpenseBtn) {
    final bool isSelected = _isExpense == isExpenseBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpense = isExpenseBtn;
            // Reset kategori HANYA jika user yang klik tombol ganti tab
            // Jangan reset otomatis di build()
            _selectedCategoryId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isExpenseBtn ? AppColors.expense : AppColors.income)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
