class AppConfig {
  static const String appName = 'SHIFTLY';
  static const String appTagline = 'Vardiyan. Takvimin. Ekibin.';
  static const String appSubtitleTr = 'Vardiya ve Nöbet Takvimi';
  static const String appSubtitleEn = 'Shift & Duty Planner';
  static const String supportEmail = 'destek@shiftly.app';
  static const String appVersion = '1.0.0';

  // Base API configuration
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  static const String emulatorApiBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String localhostApiBaseUrl = 'http://127.0.0.1:8000/api/v1';

  // Demo / Initial credentials
  static const String demoEmail = 'demo@shiftly.app';
  static const String demoPassword = 'demo1234';

  static const String managerEmail = 'yonetici@shiftly.app';
  static const String managerPassword = 'Yonetici123!';

  static const String staffEmail = 'personel1@shiftly.app';
  static const String staffPassword = 'Personel123!';
}
