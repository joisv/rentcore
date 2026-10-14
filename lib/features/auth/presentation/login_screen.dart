import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'kasir.genteng@rentcore.id');
  final _passwordController = TextEditingController(text: 'password');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString('google_server_client_id');
    if (custom != null && custom.trim().isNotEmpty) {
      if (custom.contains('8uqr0atc9aiojvg8g3bubj0m609ko1ar')) {
        await prefs.setString('google_server_client_id', ApiConstants.googleServerClientId);
        return ApiConstants.googleServerClientId;
      }
      return custom.trim();
    }
    return ApiConstants.googleServerClientId.trim();
  }

  Future<void> _handleGoogleSignIn() async {
    final serverClientId = await _getEffectiveServerClientId();
    if (serverClientId.isEmpty) {
      if (mounted) {
        _showConfigGoogleClientIdDialog();
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
        // User cancelled account selection
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
        final error = ref.read(authProvider).errorMessage ?? 'Autentikasi Google gagal.';
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
          message: errorStr.replaceAll('Exception: ', '').replaceAll('PlatformException(', ''),
        );
      }
    }
  }

  void _showDiagnosticErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SelectableText(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
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
    final currentId = await _getEffectiveServerClientId();
    final ctrl = TextEditingController(text: currentId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.obsidian),
            SizedBox(width: 8),
            Text('Konfigurasi Web Client ID', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Untuk mengaktifkan autentikasi Google Sign-In asli di HP Android, masukkan Web OAuth Client ID dari Google Cloud Console:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Google Web Client ID',
                hintText: 'xxxx.apps.googleusercontent.com',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
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
    final prefs = await SharedPreferences.getInstance();
    final urlCtrl = TextEditingController(text: ApiClient().currentBaseUrl);
    final googleIdCtrl = TextEditingController(
      text: prefs.getString('google_server_client_id') ?? ApiConstants.googleServerClientId,
    );

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pengaturan Server & OAuth'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Base URL Backend Laravel:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL API',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.usb_rounded, size: 14),
                      label: const Text('127.0.0.1 (USB)', style: TextStyle(fontSize: 10)),
                      onPressed: () => urlCtrl.text = ApiConstants.usbReverseBaseUrl,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wifi_rounded, size: 14),
                      label: const Text('192.168.1.101 (LAN)', style: TextStyle(fontSize: 10)),
                      onPressed: () => urlCtrl.text = ApiConstants.currentLanPcBaseUrl,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.smart_screen_rounded, size: 14),
                      label: const Text('10.0.2.2 (Emulator)', style: TextStyle(fontSize: 10)),
                      onPressed: () => urlCtrl.text = ApiConstants.emulatorBaseUrl,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.language_rounded, size: 14),
                      label: const Text('Laragon vhost', style: TextStyle(fontSize: 10)),
                      onPressed: () => urlCtrl.text = ApiConstants.laragonVhostUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '2. Google Web OAuth Client ID:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: googleIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Web Client ID (.apps.googleusercontent.com)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_rounded, color: AppColors.textSecondary),
            tooltip: 'Pengaturan Server API',
            onPressed: () => _showServerSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.obsidian,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.obsidian.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.devices_other_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'RENTCORE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 26,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Electronic Rental Operating System',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 36),

                // Login Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Masuk Akun',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Petugas / Admin',
                          prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Masuk ke Sistem'),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.border)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'atau',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.border)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                        icon: const Icon(Icons.account_circle_rounded, size: 20, color: AppColors.obsidian),
                        label: const Text(
                          'Masuk dengan Google',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Account Fill Chips
                Text(
                  'PILIHAN AKUN DEMO RESMI:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      label: const Text('Kasir Genteng', style: TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.surface,
                      onPressed: () => _quickFill('kasir.genteng@rentcore.id'),
                    ),
                    ActionChip(
                      label: const Text('Manager Genteng', style: TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.surface,
                      onPressed: () => _quickFill('manager.genteng@rentcore.id'),
                    ),
                    ActionChip(
                      label: const Text('Super Admin', style: TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.surface,
                      onPressed: () => _quickFill('superadmin@rentcore.id'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
