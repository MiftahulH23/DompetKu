import 'package:catat_uang_app/core/app_notification.dart'; // Import Notifikasi Keren
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageCategoryScreen extends StatefulWidget {
  const ManageCategoryScreen({super.key});

  @override
  State<ManageCategoryScreen> createState() => _ManageCategoryScreenState();
}

class _ManageCategoryScreenState extends State<ManageCategoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isExpense = true;
  List<CategoryModel> _categories = [];
  bool _isLoadingList = true; // Rename biar jelas bedanya sama loading dialog

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  // 1. AMBIL DATA
  Future<void> _fetchCategories() async {
    setState(() => _isLoadingList = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', _isExpense)
          .or('user_id.is.null,user_id.eq.$userId')
          .order('id', ascending: true);

      final data = response as List<dynamic>;

      if (mounted) {
        setState(() {
          _categories = data
              .map((json) => CategoryModel.fromJson(json))
              .toList();
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  // 2. TAMBAH BARU (Logic Only)
  Future<void> _addCategoryLogic(String name) async {
    await _supabase.from('categories').insert({
      'name': name,
      'is_expense': _isExpense,
      'user_id': _supabase.auth.currentUser!.id,
      'icon_name': 'star',
    });
  }

  // 3. EDIT KATEGORI (Logic Only)
  Future<void> _editCategoryLogic(int id, String newName) async {
    await _supabase.from('categories').update({'name': newName}).eq('id', id);
  }

  // 4. HAPUS KATEGORI
  Future<void> _deleteCategory(int id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      _fetchCategories();
      // GANTI PAKE NOTIFIKASI ATAS
      if (mounted) {
        AppNotification.success(context, "Kategori berhasil dihapus!");
      }
    } catch (e) {
      // GANTI PAKE NOTIFIKASI ATAS
      if (mounted) {
        AppNotification.error(
          context,
          "Gagal hapus. Kategori sedang digunakan di transaksi.",
        );
      }
    }
  }

  // DIALOG PINTAR (DENGAN LOADING STATE)
  void _showInputDialog({CategoryModel? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final controller = TextEditingController(
      text: isEditing ? categoryToEdit.name : '',
    );

    // Kita butuh GlobalKey form kalau mau validasi, tapi pake controller check aja cukup.

    showDialog(
      context: context,
      barrierDismissible:
          false, // User gak bisa klik luar untuk tutup paksa saat loading
      builder: (ctx) {
        // STATEFUL BUILDER: Ini rahasianya biar Dialog bisa punya loading sendiri
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Variable lokal khusus untuk dialog ini
            bool isSaving = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                isEditing
                    ? "Edit Kategori"
                    : (_isExpense ? "Tambah Pengeluaran" : "Tambah Pemasukan"),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Nama Kategori",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                enabled: !isSaving, // Disable input pas lagi loading
              ),
              actions: [
                // TOMBOL BATAL
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(
                    "Batal",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),

                // TOMBOL SIMPAN (DENGAN LOADING)
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) return;

                          // 1. Mulai Loading (Update tampilan dialog)
                          setDialogState(() => isSaving = true);

                          try {
                            // 2. Jalankan Logic Simpan
                            if (isEditing) {
                              await _editCategoryLogic(
                                categoryToEdit.id,
                                controller.text.trim(),
                              );
                            } else {
                              await _addCategoryLogic(controller.text.trim());
                            }

                            // 3. Sukses! Tutup Dialog dulu
                            if (context.mounted) {
                              Navigator.pop(context); // Tutup Dialog
                              _fetchCategories(); // Refresh List di belakang

                              // 4. Tampilkan Notifikasi Sukses
                              AppNotification.success(
                                context,
                                isEditing
                                    ? "Kategori berhasil diubah!"
                                    : "Kategori berhasil dibuat!",
                              );
                            }
                          } catch (e) {
                            // 5. Gagal? Stop loading dialog & Tampilkan error
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              AppNotification.error(
                                context,
                                "Terjadi kesalahan: $e",
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing ? "Simpan" : "Tambah",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Kelola Kategori",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // TOGGLE BUTTON (EXPENSE / INCOME)
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _buildToggleBtn("Pengeluaran", true),
                  _buildToggleBtn("Pemasukan", false),
                ],
              ),
            ),
          ),

          // LIST KATEGORI
          Expanded(
            child: _isLoadingList
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                ? Center(
                    child: Text(
                      "Belum ada kategori",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSystem = cat.userId == null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            // ICON JENIS
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isExpense
                                    ? AppColors.expense.withOpacity(0.1)
                                    : AppColors.income.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSystem
                                    ? PhosphorIcons.lockKey()
                                    : PhosphorIcons.tag(),
                                color: _isExpense
                                    ? AppColors.expense
                                    : AppColors.income,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),

                            // NAMA KATEGORI
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (isSystem)
                                    Text(
                                      "Bawaan Aplikasi",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // TOMBOL AKSI (Hanya muncul untuk Kategori User)
                            if (!isSystem) ...[
                              // EDIT
                              IconButton(
                                icon: const Icon(
                                  PhosphorIconsFill.pencilSimple,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showInputDialog(categoryToEdit: cat),
                                tooltip: "Edit Nama",
                              ),

                              // HAPUS
                              IconButton(
                                icon: const Icon(
                                  PhosphorIconsFill.trash,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Hapus Kategori?"),
                                      content: Text(
                                        "Yakin mau hapus '${cat.name}'?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Batal"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteCategory(cat.id);
                                          },
                                          child: const Text(
                                            "Hapus",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // TOMBOL TAMBAH (FAB)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInputDialog(),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildToggleBtn(String title, bool isExpenseBtn) {
    final bool isSelected = _isExpense == isExpenseBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isExpense != isExpenseBtn) {
            setState(() {
              _isExpense = isExpenseBtn;
              _fetchCategories();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isExpenseBtn ? AppColors.expense : AppColors.income)
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
