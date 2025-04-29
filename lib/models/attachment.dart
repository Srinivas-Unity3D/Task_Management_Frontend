class Attachment {
  final String id;
  final String taskId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? filePath;
  final String? createdBy;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.filePath,
    this.createdBy,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'],
      taskId: json['task_id'],
      fileName: json['file_name'],
      fileType: json['file_type'] ?? '',
      fileSize: json['file_size'] ?? 0,
      filePath: json['file_path'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'file_path': filePath,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 