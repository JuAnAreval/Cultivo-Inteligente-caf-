import 'package:uuid/uuid.dart';

class SubActivity {
  final String id;
  String title;
  DateTime date;
  bool isCompleted;

  SubActivity({
    String? id,
    required this.title,
    required this.date,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  factory SubActivity.fromJson(Map<String, dynamic> json) {
    return SubActivity(
      id: json['id'] as String?,
      title: json['title'] as String,
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      isCompleted: json['isCompleted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'isCompleted': isCompleted,
      };
}

class AppTask {
  final String id;
  String title;
  String state;
  String color;
  String category;
  String details;
  DateTime dueDate;
  List<SubActivity> subActivities;

  AppTask({
    String? id,
    required this.title,
    this.state = 'pending',
    this.color = '#FFFFFF',
    required this.category,
    this.details = '',
    DateTime? dueDate,
    List<SubActivity>? subActivities,
  })  : id = id ?? const Uuid().v4(),
        dueDate = dueDate ?? DateTime.now(),
        subActivities = subActivities ?? [];

  factory AppTask.fromJson(Map<String, dynamic> json) {
    return AppTask(
      id: json['id'] as String?,
      title: json['title'] as String,
      state: json['state'] as String? ?? 'pending',
      color: json['color'] as String? ?? '#42A5F5',
      category: json['category'] as String? ?? 'General',
      details: json['details'] as String? ?? '',
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now(),
      subActivities: (json['subActivities'] as List<dynamic>?)
              ?.map((e) => SubActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'state': state,
        'color': color,
        'category': category,
        'details': details,
        'dueDate': dueDate.toIso8601String(),
        'subActivities': subActivities.map((e) => e.toJson()).toList(),
      };
}
