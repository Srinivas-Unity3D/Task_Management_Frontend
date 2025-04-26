class VoiceNote {
  final String id;
  final String taskId;
  final String? filePath;
  final String? audioData;
  final String? createdBy;
  final DateTime createdAt;
  final Duration duration;

  VoiceNote({
    required this.id,
    required this.taskId,
    this.filePath,
    this.audioData,
    this.createdBy,
    required this.createdAt,
    required this.duration,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id'],
      taskId: json['task_id'],
      filePath: json['file_path'],
      audioData: json['audio_data'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      duration: Duration(milliseconds: json['duration'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'file_path': filePath,
      'audio_data': audioData,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'duration_ms': duration.inMilliseconds,
    };
  }
} 