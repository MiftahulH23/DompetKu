import 'package:catat_uang_app/core/app_notification.dart';
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
  bool _isLoadingList = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

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

  Future<void> _addCategoryLogic(String name) async {
    await _supabase.from('categories').insert({
      'name': name,
      'is_expense': _isExpense,
      'user_id': _supabase.auth.currentUser!.id,
      'icon_name': 'star',
    });
  }

  Future<void> _editCategoryLogic(int id, String newName) async {
    await _supabase.from('categories').update({'name': newName}).eq('id', id);
  }

  Future<void> _deleteCategory(int id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      _fetchCategories();
      if (mounted)
        AppNotification.success(context, "Kategori berhasil dihapus!");
    } catch (e) {
      if (mounted)
        AppNotification.error(
          context,
          "Gagal hapus. Kategori sedang digunakan.",
        );
    }
  }

  // --- DIALOG MODAL YANG SUDAH DIPERBAIKI UI-NYA ---
  void _showInputDialog({CategoryModel? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final controller = TextEditingController(
      text: isEditing ? categoryToEdit.name : '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              // 1. FIX WARNA PINK: Set surfaceTintColor transparan
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.white,

              // 2. LEBARKAN MODAL: Atur inset padding
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: Center(
                child: Text(
                  isEditing
                      ? "Edit Kategori"
                      : (_isExpense
                            ? "Tambah Pengeluaran"
                            : "Tambah Pemasukan"),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // 3. KONTEN LEBIH RAPI DENGAN WIDTH MAKSIMAL
              content: SizedBox(
                width: double.maxFinite, // Paksa lebar maksimal
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Nama Kategori (Contoh: Bensin)",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors
                        .background, // Abu muda biar kontras sama putih
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  enabled: !isSaving,
                ),
              ),

              actionsPadding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24,
              ), // Padding tombol
              actions: [
                Row(
                  children: [
                    // TOMBOL BATAL (Expanded)
                    Expanded(
                      child: TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Batal",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // TOMBOL SIMPAN (Expanded & Dark Blue)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (controller.text.trim().isEmpty) return;
                                setDialogState(() => isSaving = true);
                                try {
                                  if (isEditing) {
                                    await _editCategoryLogic(
                                      categoryToEdit.id,
                                      controller.text.trim(),
                                    );
                                  } else {
                                    await _addCategoryLogic(
                                      controller.text.trim(),
                                    );
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _fetchCategories();
                                    AppNotification.success(
                                      context,
                                      isEditing
                                          ? "Berhasil diubah!"
                                          : "Berhasil ditambah!",
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (context.mounted)
                                    AppNotification.error(context, "Error: $e");
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, // Dark Blue
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                "Simpan",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
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
                            if (!isSystem) ...[
                              IconButton(
                                icon: const Icon(
                                  PhosphorIconsFill.pencilSimple,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showInputDialog(categoryToEdit: cat),
                              ),
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
                                      backgroundColor: Colors.white,
                                      surfaceTintColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
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
