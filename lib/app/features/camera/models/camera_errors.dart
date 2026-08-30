enum CameraFailureType {
  restricted,
  permissionDenied,
  notFound,
  inUse,
  unknown
}

class CameraFailure {
  const CameraFailure({
    required this.type,
    required this.userMessage,
    required this.rawMessage,
  });

  final CameraFailureType type;
  final String userMessage;
  final String rawMessage;

  factory CameraFailure.from(Object error) {
    final raw = error.toString();
    if (raw.contains('CameraAccessDeniedWithoutPrompt') ||
        raw.contains('CameraAccessRestricted')) {
      return CameraFailure(
        type: CameraFailureType.restricted,
        rawMessage: raw,
        userMessage: 'Akses kamera dibatasi. Izinkan kamera untuk Motorix dari '
            'Pengaturan perangkat, lalu tekan Coba lagi.',
      );
    }
    if (raw.contains('CameraAccessDenied') ||
        raw.contains('NotAllowedError') ||
        raw.toLowerCase().contains('permission denied')) {
      return CameraFailure(
        type: CameraFailureType.permissionDenied,
        rawMessage: raw,
        userMessage:
            'Izin kamera belum diberikan. Izinkan akses kamera, lalu tekan '
            'Coba lagi.',
      );
    }
    if (raw.contains('NotFoundError') ||
        raw.contains('Kamera tidak ditemukan')) {
      return CameraFailure(
        type: CameraFailureType.notFound,
        rawMessage: raw,
        userMessage: 'Kamera tidak ditemukan pada perangkat ini.',
      );
    }
    if (raw.contains('NotReadableError')) {
      return CameraFailure(
        type: CameraFailureType.inUse,
        rawMessage: raw,
        userMessage:
            'Kamera sedang digunakan aplikasi atau layanan lain. Tutup '
            'pengguna kamera tersebut, lalu tekan Coba lagi.',
      );
    }
    return CameraFailure(
      type: CameraFailureType.unknown,
      rawMessage: raw,
      userMessage: 'Kamera gagal dimulai. Silakan tekan Coba lagi.\n$raw',
    );
  }
}

String cameraErrorMessage(Object error) =>
    CameraFailure.from(error).userMessage;
