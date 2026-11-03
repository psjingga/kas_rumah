import 'package:flutter/material.dart';

/// Jenis transaksi: uang masuk atau uang keluar.
enum TransactionType {
  income('Pemasukan'),
  expense('Pengeluaran');

  const TransactionType(this.label);

  final String label;
}

/// Pilihan ikon & warna untuk kategori. Ikon disimpan sebagai **kunci**
/// (bukan code point) supaya semua `IconData` tetap konstan dan aman untuk
/// tree-shaking ikon di build release.
abstract final class CategoryStyle {
  static const icons = <String, IconData>{
    'work': Icons.work_outline,
    'gift': Icons.card_giftcard,
    'store': Icons.storefront_outlined,
    'payments': Icons.payments_outlined,
    'savings': Icons.savings_outlined,
    'restaurant': Icons.restaurant_outlined,
    'basket': Icons.shopping_basket_outlined,
    'receipt': Icons.receipt_long_outlined,
    'car': Icons.directions_car_outlined,
    'school': Icons.school_outlined,
    'hospital': Icons.local_hospital_outlined,
    'movie': Icons.movie_outlined,
    'home': Icons.home_outlined,
    'bolt': Icons.bolt,
    'water': Icons.water_drop_outlined,
    'wifi': Icons.wifi,
    'phone': Icons.smartphone,
    'fuel': Icons.local_gas_station_outlined,
    'child': Icons.child_care,
    'pets': Icons.pets,
    'shirt': Icons.checkroom,
    'coffee': Icons.local_cafe_outlined,
    'sports': Icons.sports_soccer,
    'flight': Icons.flight,
    'charity': Icons.volunteer_activism_outlined,
    'mosque': Icons.mosque_outlined,
    'cake': Icons.cake_outlined,
    'tools': Icons.handyman_outlined,
    'family': Icons.family_restroom,
    'more': Icons.more_horiz,
    'label': Icons.label_outline,
  };

  static const colors = <Color>[
    Color(0xFF2E7D32),
    Color(0xFF43A047),
    Color(0xFF00897B),
    Color(0xFF1E88E5),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFFE53935),
    Color(0xFFEF6C00),
    Color(0xFFF9A825),
    Color(0xFF6D4C41),
    Color(0xFF757575),
  ];
}

/// Kategori transaksi: bawaan (tetap) atau buatan pengguna.
///
/// Setiap kategori terikat ke satu [TransactionType], sehingga form hanya
/// menawarkan kategori yang cocok. Dua kategori dianggap sama bila [id]-nya
/// sama; transaksi menyimpan [id] kategori, lalu label/ikon/warna terbaru
/// diambil dari daftar kategori saat dimuat.
@immutable
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.label,
    required this.type,
    required this.iconKey,
    required this.color,
    this.builtIn = false,
  });

  const TransactionCategory._builtIn(
    this.id,
    this.label,
    this.type,
    this.iconKey,
    this.color,
  ) : builtIn = true;

  final String id;
  final String label;
  final TransactionType type;

  /// Kunci di [CategoryStyle.icons].
  final String iconKey;

  /// Warna kategori, dipakai juga di grafik.
  final Color color;

  /// Kategori bawaan tidak bisa diubah atau dihapus.
  final bool builtIn;

  IconData get icon => CategoryStyle.icons[iconKey] ?? Icons.label_outline;

  /// Kategori yang sudah dihapus pengguna (lihat [byId]).
  bool get isMissing => label == _missingLabel;

  // ---------- Kategori bawaan ----------
  // ID = nama enum versi lama, sehingga data lama tetap terbaca.

  static const salary = TransactionCategory._builtIn(
    'salary',
    'Gaji',
    TransactionType.income,
    'work',
    Color(0xFF2E7D32),
  );
  static const bonus = TransactionCategory._builtIn(
    'bonus',
    'Bonus',
    TransactionType.income,
    'gift',
    Color(0xFF43A047),
  );
  static const business = TransactionCategory._builtIn(
    'business',
    'Hasil Usaha',
    TransactionType.income,
    'store',
    Color(0xFF66BB6A),
  );
  static const savingsWithdrawal = TransactionCategory._builtIn(
    'savingsWithdrawal',
    'Ambil Tabungan',
    TransactionType.income,
    'savings',
    Color(0xFF00897B),
  );
  static const otherIncome = TransactionCategory._builtIn(
    'otherIncome',
    'Pemasukan Lain',
    TransactionType.income,
    'payments',
    Color(0xFF81C784),
  );
  static const food = TransactionCategory._builtIn(
    'food',
    'Makanan',
    TransactionType.expense,
    'restaurant',
    Color(0xFFEF6C00),
  );
  static const groceries = TransactionCategory._builtIn(
    'groceries',
    'Belanja Rumah Tangga',
    TransactionType.expense,
    'basket',
    Color(0xFF8E24AA),
  );
  static const bills = TransactionCategory._builtIn(
    'bills',
    'Tagihan',
    TransactionType.expense,
    'receipt',
    Color(0xFFE53935),
  );
  static const transport = TransactionCategory._builtIn(
    'transport',
    'Transportasi',
    TransactionType.expense,
    'car',
    Color(0xFF1E88E5),
  );
  static const education = TransactionCategory._builtIn(
    'education',
    'Pendidikan',
    TransactionType.expense,
    'school',
    Color(0xFF3949AB),
  );
  static const health = TransactionCategory._builtIn(
    'health',
    'Kesehatan',
    TransactionType.expense,
    'hospital',
    Color(0xFF00897B),
  );
  static const entertainment = TransactionCategory._builtIn(
    'entertainment',
    'Hiburan',
    TransactionType.expense,
    'movie',
    Color(0xFFD81B60),
  );
  static const savings = TransactionCategory._builtIn(
    'savings',
    'Tabungan',
    TransactionType.expense,
    'savings',
    Color(0xFF00695C),
  );
  static const otherExpense = TransactionCategory._builtIn(
    'otherExpense',
    'Pengeluaran Lain',
    TransactionType.expense,
    'more',
    Color(0xFF757575),
  );

  static const builtIns = [
    salary,
    bonus,
    business,
    savingsWithdrawal,
    otherIncome,
    food,
    groceries,
    bills,
    transport,
    education,
    health,
    entertainment,
    savings,
    otherExpense,
  ];

  /// Kategori bawaan untuk jenis [type].
  static List<TransactionCategory> builtInsOf(TransactionType type) =>
      builtIns.where((c) => c.type == type).toList();

  static const _missingLabel = 'Kategori dihapus';

  /// Kategori bawaan ber-[id] ini. Untuk kategori buatan pengguna
  /// dikembalikan penanda sementara (label "Kategori dihapus") yang nanti
  /// diganti versi lengkapnya oleh provider daftar kategori.
  static TransactionCategory byId(String id, TransactionType type) =>
      builtIns.where((c) => c.id == id).firstOrNull ??
      TransactionCategory(
        id: id,
        label: _missingLabel,
        type: type,
        iconKey: 'label',
        color: const Color(0xFF9E9E9E),
      );

  TransactionCategory copyWith({
    String? label,
    String? iconKey,
    Color? color,
  }) => TransactionCategory(
    id: id,
    label: label ?? this.label,
    type: type,
    iconKey: iconKey ?? this.iconKey,
    color: color ?? this.color,
    builtIn: builtIn,
  );

  @override
  bool operator ==(Object other) =>
      other is TransactionCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TransactionCategory($id)';
}
