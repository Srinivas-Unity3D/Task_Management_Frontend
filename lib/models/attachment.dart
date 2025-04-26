class Attachment {
  final String id;
  final String taskId;
  final String fileName;
  final String? filePath;
  final String fileType;
  final int fileSize;
  final String? createdBy;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    this.filePath,
    required this.fileType,
    required this.fileSize,
    this.createdBy,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'],
      taskId: json['task_id'],
      fileName: json['file_name'],
      filePath: json['file_path'],
      fileType: json['file_type'] ?? '',
      fileSize: json['file_size'] ?? 0,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'file_size': fileSize,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 