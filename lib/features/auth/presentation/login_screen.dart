import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/legal_links.dart';
import '../../../shared/widgets/airy_settings_widgets.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isDemoExpanded = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isDevelopmentMode =>
      ref.read(appEnvironmentProvider) == AppEnvironment.development &&
      AppConfig.isDevelopment;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap masukkan email dan kata sandi.')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).login(email, password);
    if (!success && mounted) {
      final error = ref.read(authProvider).errorMessage ?? 'Login gagal.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String> _getEffectiveServerClientId() async {
    if (!_isDevelopmentMode) {
      return ApiConstants.googleServerClientId.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString('google_server_client_id');
    if (custom != null && custom.trim().isNotEmpty) {
      if (custom.contains('8uqr0atc9aiojvg8g3bubj0m609ko1ar')) {
        await prefs.setString(
          'google_server_client_id',
          ApiConstants.googleServerClientId,
        );
        return ApiConstants.googleServerClientId;
      }
      return custom.trim();
    }
    return ApiConstants.googleServerClientId.trim();
  }

  Future<void> _handleGoogleSignIn() async {
    final serverClientId = await _getEffectiveServerClientId();
    if (serverClientId.isEmpty) {
      if (!mounted) return;
      if (_isDevelopmentMode) {
        _showConfigGoogleClientIdDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi Google Sign-In belum tersedia.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: serverClientId,
        scopes: ['email', 'profile'],
      );

      // Sign out cached account locally to guarantee account picker shows on every attempt
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final account = await googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          _showDiagnosticErrorDialog(
            title: 'ID Token Tidak Diterima',
            message:
                'Google Play Services berhasil memilih akun (${account.email}), tetapi tidak mengembalikan ID Token.\n\n'
                'Langkah Perbaikan di Google Cloud Console:\n'
                '1. Pastikan Web Client ID yang digunakan ($serverClientId) benar dari menu Credentials > OAuth 2.0 Client IDs > Web application.\n'
                '2. Pastikan Android Client ID sudah dibuat dengan:\n'
                '   - Package name: com.rentcore.rentcore_mobile\n'
                '   - SHA-1: 98:8C:86:65:AA:EF:A8:F8:57:E2:F0:89:E1:1C:E1:D3:BD:7B:96:D6',
          );
        }
        return;
      }

      final success = await ref.read(authProvider.notifier).googleSignIn(
            idToken: idToken,
            email: account.email,
            name: account.displayName,
            avatarUrl: account.photoUrl,
          );

      if (!success && mounted) {
        final error =
            ref.read(authProvider).errorMessage ?? 'Autentikasi Google gagal.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      if (errorStr.contains('ApiException: 10') || errorStr.contains('10:')) {
        _showDiagnosticErrorDialog(
          title: 'Google Sign-In Error 10 (DEVELOPER_ERROR)',
          message:
              'Google Play Services menolak autentikasi karena konfigurasi belum sesuai di Google Cloud Console.\n\n'
              'Pastikan di Google Cloud Console:\n'
              '1. Android Client ID terdaftar:\n'
              '   Package: com.rentcore.rentcore_mobile\n'
              '   SHA-1: 98:8C:86:65:AA:EF:A8:F8:57:E2:F0:89:E1:1C:E1:D3:BD:7B:96:D6\n'
              '2. Web Client ID terdaftar & cocok dengan serverClientId:\n'
              '   $serverClientId\n'
              '3. OAuth consent screen sudah diatur dan menyertakan akun Google uji coba sebagai Test User (jika status masih Testing).',
        );
      } else {
        _showDiagnosticErrorDialog(
          title: 'Gagal Masuk dengan Google',
          message: errorStr
              .replaceAll('Exception: ', '')
              .replaceAll('PlatformException(', ''),
        );
      }
    }
  }

  void _showDiagnosticErrorDialog({
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SelectableText(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (_isDevelopmentMode)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showServerSettings(context);
              },
              child: const Text('Buka Pengaturan'),
            ),
        ],
      ),
    );
  }

  void _showConfigGoogleClientIdDialog() async {
    if (!_isDevelopmentMode) return;
    final currentId = await _getEffectiveServerClientId();
    final ctrl = TextEditingController(text: currentId);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text(
              'Konfigurasi Web Client ID',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Untuk mengaktifkan autentikasi Google Sign-In asli di HP Android, masukkan Web OAuth Client ID dari Google Cloud Console:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: airyInputDecoration(
                hintText: 'xxxx.apps.googleusercontent.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newId = ctrl.text.trim();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('google_server_client_id', newId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (newId.isNotEmpty) {
                _handleGoogleSignIn();
              }
            },
            child: const Text('Simpan & Masuk'),
          ),
        ],
      ),
    );
  }

  void _quickFill(String email) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = 'password';
    });
  }

  void _showServerSettings(BuildContext context) async {
    if (!_isDevelopmentMode) return;
    final prefs = await SharedPreferences.getInstance();
    final urlCtrl = TextEditingController(text: ApiClient().currentBaseUrl);
    final googleIdCtrl = TextEditingController(
      text: prefs.getString('google_server_client_id') ??
          ApiConstants.googleServerClientId,
    );

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Pengaturan Server & OAuth',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                airyFieldLabel('1. Base URL Backend Laravel'),
                const SizedBox(height: 6),
                TextField(
                  controller: urlCtrl,
                  decoration: airyInputDecoration(
                    hintText: 'http://192.168.1.101:8000/api/v1',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.usb_rounded, size: 14),
                      label: const Text('127.0.0.1 (USB)', style: TextStyle(fontSize: 10.5)),
                      onPressed: () =>
                          urlCtrl.text = ApiConstants.usbReverseBaseUrl,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wifi_rounded, size: 14),
                      label: const Text('192.168.1.101 (LAN)', style: TextStyle(fontSize: 10.5)),
                      onPressed: () =>
                          urlCtrl.text = ApiConstants.currentLanPcBaseUrl,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.smart_screen_rounded, size: 14),
                      label: const Text('10.0.2.2 (Emulator)', style: TextStyle(fontSize: 10.5)),
                      onPressed: () =>
                          urlCtrl.text = ApiConstants.emulatorBaseUrl,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.language_rounded, size: 14),
                      label: const Text('Laragon vhost', style: TextStyle(fontSize: 10.5)),
                      onPressed: () =>
                          urlCtrl.text = ApiConstants.laragonVhostUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                airyFieldLabel('2. Google Web OAuth Client ID'),
                const SizedBox(height: 6),
                TextField(
                  controller: googleIdCtrl,
                  decoration: airyInputDecoration(
                    hintText: 'xxxx.apps.googleusercontent.com',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(88, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final newUrl = urlCtrl.text.trim();
                final newClientId = googleIdCtrl.text.trim();
                await ApiClient().updateBaseUrl(newUrl);
                await prefs.setString('google_server_client_id', newClientId);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pengaturan disimpan: $newUrl')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Bantuan Kata Sandi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Untuk staf atau kasir, hubungi Owner atau Manager toko agar kata sandi akun Anda diperbarui melalui menu Tim & Staf. Untuk pemilik usaha, Anda juga dapat masuk langsung menggunakan akun Google.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleGoogleSignIn();
                },
                child: const Text(
                  'Masuk dengan Google',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Kembali',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegistrationOnboardingSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Daftar Akun Usaha Gratis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Buat workspace rental baru dalam 3 langkah singkat: pilih akun Google Anda, isi profil usaha & cabang utama, lalu pilih preset katalog awal.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleGoogleSignIn();
                },
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                label: const Text(
                  'Daftar dengan Google',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Nanti Saja',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          key: const Key('login_dev_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1),
          ),
          child: const Text(
            'DEV',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFFB45309),
            ),
          ),
        ),
        IconButton(
          key: const Key('login_server_config_button'),
          icon: const Icon(
            Icons.dns_outlined,
            size: 20,
            color: Color(0xFF64748B),
          ),
          tooltip: 'Pengaturan Server API',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => _showServerSettings(context),
        ),
      ],
    );
  }

  Widget _buildDemoSection() {
    return Container(
      key: const Key('login_demo_section'),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('login_demo_toggle'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isDemoExpanded = !_isDemoExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PILIHAN AKUN DEMO RESMI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Icon(
                    _isDemoExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_isDemoExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    key: const Key('demo_fill_kasir'),
                    label: const Text(
                      'Kasir Genteng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onPressed: () => _quickFill('kasir.genteng@rentcore.id'),
                  ),
                  ActionChip(
                    key: const Key('demo_fill_manager'),
                    label: const Text(
                      'Manager Genteng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onPressed: () => _quickFill('manager.genteng@rentcore.id'),
                  ),
                  ActionChip(
                    key: const Key('demo_fill_owner'),
                    label: const Text(
                      'Owner',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onPressed: () => _quickFill('superadmin@rentcore.id'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final env = ref.watch(appEnvironmentProvider);
    final isDevelopment = env == AppEnvironment.development;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDevelopment) ...[
                  _buildDevTopBar(context),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 24),

                // Crisp Brand Header
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.devices_other_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'RENTCORE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Electronic Rental Operating System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),

                // Borderless Airy Minimalist Form
                airyFieldLabel('Email'),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('login_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: airyInputDecoration(
                    hintText: 'nama@usaha.com',
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                airyFieldLabel('Kata Sandi'),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('login_password_field'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: airyInputDecoration(
                    hintText: 'Masukkan kata sandi',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: IconButton(
                      key: const Key('login_password_visibility_toggle'),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    key: const Key('login_forgot_password_button'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: _showForgotPasswordSheet,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'Lupa Kata Sandi?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Primary Sign-In CTA
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('login_submit_button'),
                    onPressed: authState.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      disabledBackgroundColor: const Color(0xFF0F172A)
                          .withValues(alpha: 0.65),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Hairline Divider
                const Row(
                  children: [
                    Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'atau',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Google Sign-In Secondary CTA
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('login_google_button'),
                    onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 24,
                      color: Color(0xFF0F172A),
                    ),
                    label: const Text(
                      'Masuk dengan Google',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFFFF),
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Registration Footer
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text(
                      'Belum punya akun usaha?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    InkWell(
                      key: const Key('login_register_button'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: _showRegistrationOnboardingSheet,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'Daftar Gratis',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (isDevelopment) ...[
                  const SizedBox(height: 24),
                  _buildDemoSection(),
                ],

                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    key: const Key('login_privacy_policy_button'),
                    onPressed: () => LegalLinks.openExternal(
                      context,
                      LegalLinks.privacyPolicyUri,
                    ),
                    icon: const Icon(
                      Icons.privacy_tip_outlined,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    label: const Text(
                      'Kebijakan Privasi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
