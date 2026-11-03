/// Kontrak penyimpanan anggaran (batas pengeluaran per kategori per bulan).
abstract interface class BudgetRepository {
  /// ID kategori → batas per bulan.
  Map<String, double> getLimits();

  Future<void> replaceLimits(Map<String, double> limits);

  /// Kunci peringatan yang sudah pernah dikirim (lihat `BudgetAlert.key`).
  Set<String> getSentAlerts();

  Future<void> saveSentAlerts(Set<String> keys);
}
