class TaskAttachment {
  final String? attachmentId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileData;  // Base64 encoded file data

  TaskAttachment({
    this.attachmentId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileData,
  });

  Map<String, dynamic> toJson() {
    return {
      'attachment_id': attachmentId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'file_data': fileData,
    };
  }

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      attachmentId: json['attachment_id'],
      fileName: json['file_name'],
      fileType: json['file_type'],
      fileSize: json['file_size'],
      fileData: json['file_data'],
    );
  }
} 