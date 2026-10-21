import 'package:cloud_firestore/cloud_firestore.dart';

/// Mengelola batas anggaran bulanan setiap pengguna di Firestore.
/// Data disimpan pada users/{uid}.monthlyBudget.
class MonthlyBudgetService {
  MonthlyBudgetService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int defaultBudget = 1500000;

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  /// Memastikan field monthlyBudget tersedia tanpa menimpa budget yang sudah ada.
  /// Jika dokumen atau field belum ada, nilai awalnya Rp1.500.000.
  Future<int> ensureBudget(String uid) {
    return _firestore.runTransaction<int>((transaction) async {
      final document = _userDocument(uid);
      final snapshot = await transaction.get(document);
      final data = snapshot.data();
      final savedBudget = data?['monthlyBudget'];

      if (savedBudget is num && savedBudget.toInt() > 0) {
        return savedBudget.toInt();
      }

      transaction.set(
        document,
        {'monthlyBudget': defaultBudget},
        SetOptions(merge: true),
      );
      return defaultBudget;
    });
  }

  /// Menyimpan perubahan anggaran tanpa menghapus field profil lainnya.
  Future<void> updateBudget(String uid, int budget) async {
    if (budget <= 0) {
      throw ArgumentError.value(budget, 'budget', 'Budget harus lebih dari 0.');
    }

    await _userDocument(uid).set(
      {'monthlyBudget': budget},
      SetOptions(merge: true),
    );
  }

  /// Stream agar perubahan budget dari Profile langsung terlihat di Dashboard.
  Stream<int> watchBudget(String uid) {
    return _userDocument(uid).snapshots().map((snapshot) {
      final value = snapshot.data()?['monthlyBudget'];
      if (value is num && value.toInt() > 0) return value.toInt();
      return defaultBudget;
    }).distinct();
  }
}
