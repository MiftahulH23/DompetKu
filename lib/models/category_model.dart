class CategoryModel {
  final int id;
  final String name;
  final bool isExpense;
  final String iconName;
  final String? userId; // Nullable karena bisa jadi ini kategori global

  CategoryModel({
    required this.id,
    required this.name,
    required this.isExpense,
    required this.iconName,
    this.userId,
  });

  // Menerima data JSON dari Supabase -> Ubah jadi Object Dart
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      isExpense: json['is_expense'] ?? true, // Default ke true kalau null
      iconName: json['icon_name'] ?? 'question',
      userId: json['user_id'],
    );
  }

  // Mengubah Object Dart -> JSON (untuk dikirim ke Supabase)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'is_expense': isExpense,
      'icon_name': iconName,
      // user_id biasanya diambil otomatis dari auth session, jadi tidak wajib disini
    };
  }
}