/// Uygulamanın çalışması için gereken tüm izinlerin ve servislerin anlık durumunu tutan model.
class PermissionStatus {
  final bool isLocationServiceEnabled; // GPS açık mı?
  final bool isLocationPermissionGranted; // Konum izni verildi mi?
  final bool isInternetConnected;     // İnternet var mı?
  final bool isBluetoothEnabled;      // Bluetooth açık mı?
  final bool isMicrophoneGranted;     // Mikrofon izni var mı?
  final bool isAudioAccessGranted;    // Müzik/Depolama izni var mı?
  final bool isCallLogGranted;        // Arama kaydı okuma izni var mı?
  final bool isPhoneStateGranted;     // Telefon durumunu okuma ve yönetme izni var mı?
  final bool isContactsGranted;       // Kişi listesine erişim izni var mı?

  const PermissionStatus({
    required this.isLocationServiceEnabled,
    required this.isLocationPermissionGranted,
    required this.isInternetConnected,
    required this.isBluetoothEnabled,
    required this.isMicrophoneGranted,
    required this.isAudioAccessGranted,
    required this.isCallLogGranted,
    required this.isPhoneStateGranted,
    required this.isContactsGranted,
  });

  /// Tüm kritik izinlerin ve servislerin verilip verilmediğini kontrol eder.
  bool get allGranted =>
      isLocationServiceEnabled &&
          isLocationPermissionGranted &&
          isInternetConnected &&
          isBluetoothEnabled &&
          isMicrophoneGranted &&
          isAudioAccessGranted &&
          isCallLogGranted &&
          isPhoneStateGranted &&
          isContactsGranted;
}
