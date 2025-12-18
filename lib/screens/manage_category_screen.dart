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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  // 1. AMBIL DATA
  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
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
          _categories = data.map((json) => CategoryModel.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. TAMBAH BARU
  Future<void> _addCategory(String name) async {
    try {
      await _supabase.from('categories').insert({
        'name': name,
        'is_expense': _isExpense,
        'user_id': _supabase.auth.currentUser!.id,
        'icon_name': 'star',
      });
      _fetchCategories();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori dibuat!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // 3. EDIT KATEGORI (UPDATE)
  Future<void> _editCategory(int id, String newName) async {
    try {
      await _supabase.from('categories').update({
        'name': newName,
      }).eq('id', id); // Update berdasarkan ID
      
      _fetchCategories(); // Refresh list
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama kategori diubah!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal edit: $e')));
    }
  }

  // 4. HAPUS KATEGORI
  Future<void> _deleteCategory(int id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      _fetchCategories();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori dihapus!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal hapus (Sedang dipakai)')));
    }
  }

  // DIALOG PINTAR (BISA TAMBAH / EDIT)
  void _showInputDialog({CategoryModel? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final controller = TextEditingController(text: isEditing ? categoryToEdit.name : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? "Edit Kategori" : (_isExpense ? "Tambah Pengeluaran" : "Tambah Pemasukan")),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nama Kategori"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (isEditing) {
                  _editCategory(categoryToEdit.id, controller.text);
                } else {
                  _addCategory(controller.text);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(isEditing ? "Simpan Perubahan" : "Simpan", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Kelola Kategori", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  _buildToggleBtn("Pengeluaran", true),
                  _buildToggleBtn("Pemasukan", false),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSystem = cat.userId == null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isExpense ? AppColors.expense.withOpacity(0.1) : AppColors.income.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isSystem ? PhosphorIcons.lockKey() : PhosphorIcons.user(),
                                color: _isExpense ? AppColors.expense : AppColors.income,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            
                            Expanded(
                              child: Text(
                                cat.name,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                            ),

                            // TOMBOL AKSI (Hanya muncul untuk Kategori User)
                            if (!isSystem) ...[
                              // TOMBOL EDIT
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _showInputDialog(categoryToEdit: cat), // Panggil Dialog Edit
                                tooltip: "Edit Nama",
                              ),
                              
                              // TOMBOL HAPUS
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Hapus Kategori?"),
                                      content: const Text("Yakin mau hapus kategori ini?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteCategory(cat.id);
                                          },
                                          child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ]
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
        onPressed: () => _showInputDialog(), // Panggil Dialog Tambah (parameter kosong)
        backgroundColor: AppColors.primary,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
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