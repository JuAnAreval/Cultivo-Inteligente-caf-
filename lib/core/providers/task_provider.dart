import 'package:app_flutter_ai/core/models/task_model.dart';
import 'package:app_flutter_ai/core/services/database_helper.dart';
import 'package:flutter/material.dart';

class TaskProvider with ChangeNotifier {
  List<AppTask> _tasks = [];
  String _selectedCategory = 'Todas';

  TaskProvider() {
    loadTasks();
  }

  Future<void> loadTasks() async {
    _tasks = await DatabaseHelper().getTasks();
    _tasks = _tasks.reversed.toList();
    notifyListeners();
  }

  List<AppTask> get allTasks => List.unmodifiable(_tasks);

  List<AppTask> get tasks {
    if (_selectedCategory == 'Archivadas') {
      return _tasks.where((task) => task.state == 'archived').toList();
    }

    final activeTasks =
        _tasks.where((task) => task.state != 'archived').toList();
    if (_selectedCategory == 'Todas') {
      return activeTasks;
    }

    return activeTasks
        .where((task) => task.category == _selectedCategory)
        .toList();
  }

  List<String> get categories {
    final activeTasks =
        _tasks.where((task) => task.state != 'archived').toList();
    final categories = activeTasks.map((task) => task.category).toSet().toList();
    categories.insert(0, 'Archivadas');
    categories.insert(0, 'Todas');
    return categories;
  }

  String get selectedCategory => _selectedCategory;

  int get pendingCount =>
      _tasks.where((task) => task.state == 'pending').length;

  int get inProgressCount =>
      _tasks.where((task) => task.state == 'in_progress').length;

  int get archivedCount =>
      _tasks.where((task) => task.state == 'archived').length;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> addTask(AppTask task) async {
    _tasks.insert(0, task);
    await DatabaseHelper().insertTask(task);
    notifyListeners();
  }

  Future<void> updateTask(AppTask task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      return;
    }

    _tasks[index] = task;
    await DatabaseHelper().updateTask(task);
    notifyListeners();
  }

  Future<void> removeTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    await DatabaseHelper().deleteTask(id);
    notifyListeners();
  }
}
