class AppConfig {
  static const String appName = 'SHIFTLY';
  static const String appTagline = 'Vardiyan. Takvimin. Ekibin.';
  static const String appSubtitleTr = 'Vardiya ve Nöbet Takvimi';
  static const String appSubtitleEn = 'Shift & Duty Planner';
  static const String supportEmail = 'destek@shiftly.app';
  static const String appVersion = '1.0.0';
  
  // Base API configuration (Android emulator or local host)
  static const String defaultApiBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String emulatorApiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  // Demo user credentials for quick dev review
  static const String demoEmail = 'demo@shiftly.app';
  static const String demoPassword = 'demo1234';
}
