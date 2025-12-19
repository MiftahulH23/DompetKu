import 'package:catat_uang_app/core/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // STATE TOGGLE (Default False = Pemasukan)
  bool _showExpense = false;

  // STATE FILTER
  String _filterType = 'Bulanan'; // Default
  DateTime _selectedDate = DateTime.now();

  Map<String, double> _categoryTotals = {};
  double _totalAmount = 0;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // 1. FETCH DATA (SAFETY MODE)
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

      // FIX CRASH: Jika Total 0, anggap tidak ada data kategori (biar tidak render chart kosong)
      if (total == 0) {
        tempTotals.clear();
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
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: Colors.black,
                surface: Colors.white,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _fetchStats();
      }
    } else if (_filterType == 'Tahunan') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
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
                _fetchStats();
              },
            ),
          ),
        ),
      );
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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
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
                    _fetchStats();
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
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    String dateLabel = "";
    if (_filterType == 'Harian') {
      dateLabel = DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Bulanan') {
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    } else {
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);
    }

    final themeColor = _showExpense ? AppColors.expense : AppColors.income;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === HEADER (STICKY) ===
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(25),
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
                  const SizedBox(height: 20),

                  // TOGGLE
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        _buildToggleBtn("Pemasukan", false),
                        _buildToggleBtn("Pengeluaran", true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // FILTER & DATE
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: PopupMenuButton<String>(
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          onSelected: (value) {
                            setState(() {
                              _filterType = value;
                              _fetchStats();
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          itemBuilder: (context) => [
                            _buildPopupItem("Harian", Icons.calendar_view_day),
                            _buildPopupItem(
                              "Bulanan",
                              Icons.calendar_view_month,
                            ),
                            _buildPopupItem("Tahunan", Icons.calendar_today),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  PhosphorIconsFill.faders,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _filterType,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickSmartDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.calendarBlank,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      dateLabel,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // === CONTENT ===
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categoryTotals.isEmpty ||
                        _totalAmount ==
                            0 // FIX: Cek Total Amount juga
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.chartPieSlice(),
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
                          // 1. CHART
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

                          // 2. TOTAL AMOUNT (CARD KEMBAR HISTORY)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: themeColor.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Icon Box
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _showExpense
                                        ? PhosphorIconsFill.trendDown
                                        : PhosphorIconsFill.trendUp,
                                    color: themeColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 15),

                                // Text Label
                                Text(
                                  _showExpense
                                      ? "Total Pengeluaran"
                                      : "Total Pemasukan",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),

                                const Spacer(), // PENDORONG KE KANAN
                                // Nominal (Kanan)
                                Text(
                                  currencyFormat.format(_totalAmount),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3. LIST KATEGORI
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _categoryTotals.length,
                            itemBuilder: (context, index) {
                              final entry = _categoryTotals.entries.elementAt(
                                index,
                              );
                              final percentage = _totalAmount == 0
                                  ? "0.0"
                                  : (entry.value / _totalAmount * 100)
                                        .toStringAsFixed(1);
                              final color = _getColor(index);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
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
                                        const SizedBox(width: 12),
                                        Text(
                                          entry.key,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currencyFormat.format(entry.value),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "$percentage%",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value == _filterType ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: value == _filterType
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: value == _filterType ? AppColors.primary : Colors.black,
            ),
          ),
        ],
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
              _fetchStats();
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
      final double percentage = _totalAmount == 0
          ? 0.0
          : (entry.value / _totalAmount * 100);

      final widget = PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
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
