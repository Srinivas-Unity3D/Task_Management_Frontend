class VoiceNote {
  final String? id;
  final String? taskId;
  final String? filePath;
  final String? audioData;
  final String? createdBy;
  final DateTime? createdAt;
  final Duration duration;
  final String fileName;

  VoiceNote({
    this.id,
    this.taskId,
    this.filePath,
    this.audioData,
    this.createdBy,
    this.createdAt,
    required this.duration,
    required this.fileName,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json, {String? parentTaskId}) {
    final id = json['audio_id'] ?? json['id'];
    final taskId = json['task_id'] ?? parentTaskId;
    print('🛠 [VoiceNote.fromJson] id: $id, taskId: $taskId');
    return VoiceNote(
      id: id,
      taskId: taskId,
      filePath: json['file_path'],
      audioData: json['audio_data'],
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      duration: Duration(milliseconds: json['duration'] ?? 0),
      fileName: json['file_name'] ?? 'voice_note.wav',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'file_path': filePath,
      'audio_data': audioData,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'duration': duration.inMilliseconds,
      'file_name': fileName,
    };
  }
} 