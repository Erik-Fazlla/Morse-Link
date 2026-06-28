class SavedMessageTemplate {
  const SavedMessageTemplate({
    required this.id,
    required this.title,
    required this.messageText,
    required this.isBuiltIn,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final String messageText;
  final bool isBuiltIn;
  final bool isFavorite;

  SavedMessageTemplate copyWith({
    String? id,
    String? title,
    String? messageText,
    bool? isBuiltIn,
    bool? isFavorite,
  }) {
    return SavedMessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      messageText: messageText ?? this.messageText,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'title': title,
      'messageText': messageText,
      'isBuiltIn': isBuiltIn,
      'isFavorite': isFavorite,
    };
  }

  factory SavedMessageTemplate.fromJson(Map<String, dynamic> json) {
    return SavedMessageTemplate(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      messageText: json['messageText'] as String? ?? '',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
