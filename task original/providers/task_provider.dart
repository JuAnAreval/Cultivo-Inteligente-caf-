import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/database_helper.dart';

class TaskProvider with ChangeNotifier {
  List<AppTask> _tasks = [];
  String _selectedCategory = 'Todas';

  TaskProvider() {
    loadTasks();
  }

  Future<void> loadTasks() async {
    _tasks = await DatabaseHelper().getTasks();
    // Sort tasks logically or just reverse to show latest first
    _tasks = _tasks.reversed.toList();
    notifyListeners();
  }

  List<AppTask> get tasks {
    if (_selectedCategory == 'Archivadas') {
      return _tasks.where((t) => t.state == 'archived').toList();
    }
    
    final activeTasks = _tasks.where((t) => t.state != 'archived').toList();
    if (_selectedCategory == 'Todas') return activeTasks;
    
    return activeTasks.where((t) => t.category == _selectedCategory).toList();
  }

  List<String> get categories {
    final activeTasks = _tasks.where((t) => t.state != 'archived').toList();
    final cats = activeTasks.map((e) => e.category).toSet().toList();
    cats.insert(0, 'Archivadas');
    cats.insert(0, 'Todas');
    return cats;
  }

  String get selectedCategory => _selectedCategory;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void addTask(AppTask task) {
    _tasks.insert(0, task);
    DatabaseHelper().insertTask(task);
    notifyListeners();
  }

  void updateTask(AppTask task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      DatabaseHelper().updateTask(task);
      notifyListeners();
    }
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    DatabaseHelper().deleteTask(id);
    notifyListeners();
  }
}
