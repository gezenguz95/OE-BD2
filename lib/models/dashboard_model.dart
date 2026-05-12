// lib/models/dashboard_model.dart

import 'package:flutter/material.dart';
import '../data/app_database.dart';

class DashboardModel extends ChangeNotifier {
  final AppDatabase _db;
  List<PidCatalogData> _allPids = [];
  final Set<int> _selectedPidIds = {};

  DashboardModel(this._db) {
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    _allPids = await _db.getAllPids();
    notifyListeners();
  }

  List<PidCatalogData> get allPids => _allPids;
  List<PidCatalogData> get selectedPids =>
      _allPids.where((p) => _selectedPidIds.contains(p.id)).toList();

  void togglePid(int pidId) {
    if (_selectedPidIds.contains(pidId)) {
      _selectedPidIds.remove(pidId);
    } else {
      _selectedPidIds.add(pidId);
    }
    notifyListeners();
  }
}
