import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class PendingAction extends HiveObject {
  @HiveField(0)
  final String actionType; // e.g., 'GATE_CONFIRM', 'SEND_MESSAGE'

  @HiveField(1)
  final Map<String, dynamic> data;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  int retries;

  PendingAction({
    required this.actionType,
    required this.data,
    required this.createdAt,
    this.retries = 0,
  });
}

@HiveType(typeId: 1)
class PendingUpload extends HiveObject {
  @HiveField(0)
  final String filePath;

  @HiveField(1)
  final String storagePath;

  @HiveField(2)
  final String hash;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  bool isCompleted;

  PendingUpload({
    required this.filePath,
    required this.storagePath,
    required this.hash,
    required this.createdAt,
    this.isCompleted = false,
  });
}
