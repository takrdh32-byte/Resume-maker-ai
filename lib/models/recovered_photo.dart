class RecoveredPhoto {
  final String path;
  final int sizeBytes;
  final bool isUnlocked;

  RecoveredPhoto({
    required this.path,
    required this.sizeBytes,
    this.isUnlocked = false,
  });

  RecoveredPhoto copyWith({bool? isUnlocked}) {
    return RecoveredPhoto(
      path: path,
      sizeBytes: sizeBytes,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}