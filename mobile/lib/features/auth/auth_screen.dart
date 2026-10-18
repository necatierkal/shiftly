import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/shiftly_logo.dart';
import '../navigation/main_nav_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login Form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register Form
  final _regFormKey = GlobalKey<FormState>();
  final _regFirstNameController = TextEditingController();
  final _regLastNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _selectedSector = 'Sağlık';

  final List<String> _sectors = [
    'Sağlık',
    'Güvenlik',
    'Polis / Asker',
    'Üretim / Fabrika',
    'Lojistik',
    'Teknik Servis',
    'Ofis / IT',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regFirstNameController.dispose();
    _regLastNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    // Refresh shifts and redirect
    context.read<ShiftProvider>().fetchShifts();
    context.read<ShiftProvider>().fetchShiftTypes();
    context.read<ShiftProvider>().fetchStatistics();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainNavScreen()));
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _loginEmailController.text,
      _loginPasswordController.text,
    );
    if (success && mounted) {
      _onSuccess();
    } else if (mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _regEmailController.text,
      password: _regPasswordController.text,
      firstName: _regFirstNameController.text,
      lastName: _regLastNameController.text,
      sector: _selectedSector,
    );
    if (success && mounted) {
      _onSuccess();
    } else if (mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleDemoLogin() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginAsDemo();
    if (success && mounted) {
      _onSuccess();
    } else if (mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(child: ShiftlyLogo(size: 80, showText: true)),
              const SizedBox(height: 28),

              // Demo mode banner button (Madde 40)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Hızlı Test & Önizleme',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hazır 24/48 nöbet takvimi ve sağlık personeli demo verileri ile anında başlayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      text: 'Demo Hesabı ile Devam Et',
                      isLoading: auth.isLoading,
                      onPressed: _handleDemoLogin,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.borderLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondaryLight,
                  tabs: const [
                    Tab(text: 'Giriş Yap'),
                    Tab(text: 'Kayıt Ol'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab contents
              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildLoginForm(auth), _buildRegisterForm(auth)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider auth) {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _loginEmailController,
            decoration: const InputDecoration(
              labelText: 'E-posta Adresi',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Geçerli bir e-posta girin.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            decoration: const InputDecoration(
              labelText: 'Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) => (v == null || v.length < 4)
                ? 'Şifre en az 4 karakter olmalıdır.'
                : null,
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Giriş Yap',
            isLoading: auth.isLoading,
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthProvider auth) {
    return Form(
      key: _regFormKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regFirstNameController,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Ad girin' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _regLastNameController,
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Soyad girin' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regEmailController,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Geçerli bir e-posta girin.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPasswordController,
            decoration: const InputDecoration(
              labelText: 'Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) =>
                (v == null || v.length < 4) ? 'En az 4 karakter girin' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedSector,
            decoration: const InputDecoration(labelText: 'Sektörünüz'),
            items: _sectors
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedSector = v);
            },
          ),
          const SizedBox(height: 20),
          AppButton(
            text: 'Kayıt Ol',
            isLoading: auth.isLoading,
            onPressed: _handleRegister,
          ),
        ],
      ),
    );
  }
}
