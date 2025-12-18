import 'package:catat_uang_app/core/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // STATE TOGGLE
  bool _showExpense = true;

  // STATE FILTER
  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();

  Map<String, double> _categoryTotals = {};
  double _totalAmount = 0;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // 1. FETCH DATA
  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      var query = _supabase
          .from('transactions')
          .select('amount, categories!inner(name, is_expense)')
          .eq('user_id', userId)
          .eq('categories.is_expense', _showExpense);

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

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

      final response = await query;
      final List<dynamic> data = response;

      Map<String, double> tempTotals = {};
      double total = 0;

      for (var item in data) {
        final category = item['categories'];
        final catName = category['name'] as String;
        final amount = (item['amount'] as num).toDouble();

        if (tempTotals.containsKey(catName)) {
          tempTotals[catName] = tempTotals[catName]! + amount;
        } else {
          tempTotals[catName] = amount;
        }
        total += amount;
      }

      var sortedEntries = tempTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _categoryTotals = Map.fromEntries(sortedEntries);
          _totalAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. PICKER TANGGAL PINTAR
  Future<void> _pickSmartDate() async {
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
        builder: (ctx) => AlertDialog(
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
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      ).then((_) => _fetchStats());
    } else {
      // Bulanan
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
              itemCount: months.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
              ),
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
                          _fetchStats();
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
      ).then((_) => _fetchStats());
    }
    if (_filterType == 'Harian') _fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Label Tanggal
    String dateLabel = "";
    if (_filterType == 'Harian') {
      dateLabel = DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Bulanan')
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    else
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    "Laporan Keuangan",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 1. TOGGLE (PENGELUARAN / PEMASUKAN)
                  Container(
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
                  const SizedBox(height: 15),

                  // 2. FILTER WAKTU FULL WIDTH (UPDATE INI)
                  Row(
                    children: [
                      _buildFilterBtn("Harian"),
                      const SizedBox(width: 10),
                      _buildFilterBtn("Bulanan"),
                      const SizedBox(width: 10),
                      _buildFilterBtn("Tahunan"),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 3. DATE PICKER
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

            // KONTEN CHART
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categoryTotals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pie_chart_outline,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Belum ada data di periode ini",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _showExpense
                                ? "Total Pengeluaran"
                                : "Total Pemasukan",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            currencyFormat.format(_totalAmount),
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _showExpense
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event
                                                  .isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection ==
                                                  null) {
                                            _touchedIndex = -1;
                                            return;
                                          }
                                          _touchedIndex = pieTouchResponse
                                              .touchedSection!
                                              .touchedSectionIndex;
                                        });
                                      },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _generateSections(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          Builder(
                            builder: (context) {
                              int i = 0;
                              return Column(
                                children: _categoryTotals.entries.map((entry) {
                                  final percentage =
                                      (entry.value / _totalAmount * 100)
                                          .toStringAsFixed(1);
                                  final color = _getColor(i);
                                  i++;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              currencyFormat.format(
                                                entry.value,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              "$percentage%",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET TOMBOL FILTER FULL WIDTH (BARU)
  Widget _buildFilterBtn(String label) {
    final bool isSelected = _filterType == label;
    return Expanded(
      // PAKAI EXPANDED BIAR FULL
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() {
              _filterType = label;
              _fetchStats();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.textPrimary
                : Colors.transparent, // Hitam kalau aktif
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

  Widget _buildToggleBtn(String title, bool isExpenseBtn) {
    final bool isSelected = _showExpense == isExpenseBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_showExpense != isExpenseBtn) {
            setState(() {
              _showExpense = isExpenseBtn;
            });
            _fetchStats();
          }
        },
        child: Container(
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

  List<PieChartSectionData> _generateSections() {
    int i = 0;
    return _categoryTotals.entries.map((entry) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 18.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final color = _getColor(i);
      final widget = PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${(entry.value / _totalAmount * 100).toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
      i++;
      return widget;
    }).toList();
  }

  Color _getColor(int index) {
    final colors = [
      const Color(0xFF2962FF),
      const Color(0xFFFF2B2B),
      const Color(0xFFFFB300),
      const Color(0xFF00E676),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF4081),
      const Color(0xFF795548),
      const Color(0xFF607D8B),
    ];
    return colors[index % colors.length];
  }
}
