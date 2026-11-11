import 'dart:convert';
import 'dart:io';

void main() async {
  print('Generating RentCore Luxe Minimalist Onboarding FigCraft design script...');

  final commands = <Map<String, dynamic>>[];
  int nextId = 2; // Page 1 is id 1

  int createFrame({
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
    required Map<String, dynamic> props,
  }) {
    final id = nextId++;
    commands.add({
      'command': 'frame.create',
      'params': {
        'name': name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'props': props,
      },
    });
    return id;
  }

  int createNode({
    required String type,
    required int parent,
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
    required Map<String, dynamic> props,
  }) {
    final id = nextId++;
    commands.add({
      'command': 'node.create',
      'params': {
        'type': type,
        'parent': parent,
        'name': name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'props': props,
      },
    });
    return id;
  }

  int createText({
    required String text,
    required int parent,
    required double x,
    required double y,
    double? width,
    required Map<String, dynamic> props,
    String? name,
  }) {
    final id = nextId++;
    final params = <String, dynamic>{
      'text': text,
      'parent': parent,
      'x': x,
      'y': y,
      'props': props,
    };
    if (width != null) params['width'] = width;
    if (name != null) params['name'] = name;
    commands.add({
      'command': 'text.create',
      'params': params,
    });
    return id;
  }

  // =========================================================================
  // LUXE MINIMALIST SPATIAL UI DESIGN TOKENS (UI_UX_DESIGN.md & app_colors.dart)
  // =========================================================================
  const cCanvas = '#F9F9FB';        // Warm Porcelain Canvas
  const cSurface = '#FFFFFF';       // Pure White Elevated Card
  const cSurfaceMuted = '#F4F4F5';  // Surface Muted / Inactive Capsule
  const cObsidian = '#181A1E';      // Deep Obsidian Charcoal (Primary CTA & Brand)
  const cObsidianLight = '#27272A'; // Obsidian Soft Tone
  const cBorder = '#E4E4E7';        // Hairline Minimalist Border
  const cBorderSubtle = '#F0F0F2';  // Subtle Secondary Divider
  const cTextPrimary = '#181A1E';   // Primary Text
  const cTextSecondary = '#71717A'; // Secondary Text
  const cTextMuted = '#A1A1AA';     // Muted Meta Text
  const cWhite = '#FFFFFF';

  // Accents from PRD & UI_UX_DESIGN.md
  const cEmerald = '#059669';       // Ready / Success Green
  const cEmeraldBg = '#ECFDF5';
  const cEmeraldBorder = '#A7F3D0';
  const cAmber = '#D97706';         // Warning Amber
  const cAmberBg = '#FFFBEB';
  const cAmberBorder = '#FDE68A';
  const cRose = '#E11D48';          // Danger / Alert
  const cRoseBg = '#FFF1F2';
  const cRoyalBlue = '#2563EB';     // Active / Info
  const cRoyalBlueBg = '#EFF6FF';

  // =========================================================================
  // FRAME 1: STEP 1 - AUTHENTICATION & ENTRANCE GATE
  // =========================================================================
  final f1 = createFrame(
    name: '01_Onboarding_Auth',
    x: 0,
    y: 0,
    width: 390,
    height: 844,
    props: {'fills': [cCanvas], 'cornerRadius': 40, 'clip': true},
  );

  // Status Bar
  createText(
    text: '09:41',
    parent: f1,
    x: 28,
    y: 16,
    props: {'fontSize': 14, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]},
  );
  createText(
    text: '●●●  WiFi  100%',
    parent: f1,
    x: 280,
    y: 16,
    props: {'fontSize': 12, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]},
  );

  // Luxe Obsidian Brand Mark
  final logoBadge = createNode(
    type: 'frame',
    parent: f1,
    name: 'LuxeObsidianBrandMark',
    x: 165,
    y: 60,
    width: 60,
    height: 60,
    props: {'fills': [cObsidian], 'cornerRadius': 20},
  );
  createText(
    text: 'RC',
    parent: logoBadge,
    x: 14,
    y: 16,
    props: {'fontSize': 24, 'fontVariations': {'wght': 900}, 'fills': [cWhite]},
  );

  // Title & Subtitle (Plus Jakarta Sans aesthetic)
  createText(
    text: 'RENTCORE',
    parent: f1,
    x: 24,
    y: 132,
    width: 342,
    props: {'fontSize': 24, 'fontVariations': {'wght': 900}, 'letterSpacing': '2px', 'fills': [cTextPrimary]},
  );
  createText(
    text: 'ELECTRONIC RENTAL OPERATING SYSTEM',
    parent: f1,
    x: 24,
    y: 164,
    width: 342,
    props: {'fontSize': 10, 'fontVariations': {'wght': 800}, 'letterSpacing': '1.2px', 'fills': [cTextSecondary]},
  );

  // Elevated Luxe Card
  final authCard = createNode(
    type: 'frame',
    parent: f1,
    name: 'AuthCardElevated',
    x: 24,
    y: 200,
    width: 342,
    height: 485,
    props: {'fills': [cSurface], 'cornerRadius': 24, 'stroke': cBorder, 'strokeWeight': 1},
  );

  createText(
    text: 'Masuk Akun Kasir / Owner',
    parent: authCard,
    x: 20,
    y: 22,
    props: {'fontSize': 17, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Akses sistem operasional cabang & multi-tenant guard.',
    parent: authCard,
    x: 20,
    y: 46,
    props: {'fontSize': 11, 'fills': [cTextSecondary]},
  );

  // Email Field
  createText(
    text: 'EMAIL PETUGAS / ADMIN',
    parent: authCard,
    x: 20,
    y: 78,
    props: {'fontSize': 10, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.6px', 'fills': [cTextSecondary]},
  );
  final inputEmail = createNode(
    type: 'frame',
    parent: authCard,
    name: 'InputEmail',
    x: 20,
    y: 98,
    width: 302,
    height: 48,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 14, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(
    text: 'kasir.genteng@rentcore.id',
    parent: inputEmail,
    x: 14,
    y: 15,
    props: {'fontSize': 13, 'fontVariations': {'wght': 600}, 'fills': [cTextPrimary]},
  );

  // Password Field
  createText(
    text: 'KATA SANDI',
    parent: authCard,
    x: 20,
    y: 158,
    props: {'fontSize': 10, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.6px', 'fills': [cTextSecondary]},
  );
  final inputPass = createNode(
    type: 'frame',
    parent: authCard,
    name: 'InputPass',
    x: 20,
    y: 178,
    width: 302,
    height: 48,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 14, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(
    text: '••••••••••••',
    parent: inputPass,
    x: 14,
    y: 16,
    props: {'fontSize': 14, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]},
  );

  // Deep Obsidian Capsule CTA Button
  final btnLogin = createNode(
    type: 'frame',
    parent: authCard,
    name: 'BtnLoginObsidianCapsule',
    x: 20,
    y: 242,
    width: 302,
    height: 50,
    props: {'fills': [cObsidian], 'cornerRadius': 16},
  );
  createText(
    text: 'Masuk ke Sistem Operasional →',
    parent: btnLogin,
    x: 48,
    y: 16,
    props: {'fontSize': 13, 'fontVariations': {'wght': 800}, 'fills': [cWhite]},
  );

  // Divider
  createNode(
    type: 'rectangle',
    parent: authCard,
    name: 'LineLeft',
    x: 20,
    y: 312,
    width: 120,
    height: 1,
    props: {'fills': [cBorder]},
  );
  createText(
    text: 'atau',
    parent: authCard,
    x: 152,
    y: 304,
    props: {'fontSize': 11, 'fontVariations': {'wght': 600}, 'fills': [cTextMuted]},
  );
  createNode(
    type: 'rectangle',
    parent: authCard,
    name: 'LineRight',
    x: 182,
    y: 312,
    width: 140,
    height: 1,
    props: {'fills': [cBorder]},
  );

  // Google Sign-In Outlined Button
  final btnGoogle = createNode(
    type: 'frame',
    parent: authCard,
    name: 'BtnGoogleOutlined',
    x: 20,
    y: 332,
    width: 302,
    height: 48,
    props: {'fills': [cSurface], 'cornerRadius': 14, 'stroke': cBorder, 'strokeWeight': 1.5},
  );
  createText(
    text: 'G',
    parent: btnGoogle,
    x: 20,
    y: 13,
    props: {'fontSize': 18, 'fontVariations': {'wght': 900}, 'fills': [cObsidian]},
  );
  createText(
    text: 'Masuk dengan Akun Google',
    parent: btnGoogle,
    x: 52,
    y: 15,
    props: {'fontSize': 13, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]},
  );

  // Quick Demo Account Capsule Pills
  createText(
    text: 'PILIHAN AKUN DEMO RESMI:',
    parent: authCard,
    x: 20,
    y: 400,
    props: {'fontSize': 9, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.6px', 'fills': [cTextMuted]},
  );

  final demoPill1 = createNode(
    type: 'frame',
    parent: authCard,
    name: 'DemoPill1',
    x: 20,
    y: 420,
    width: 95,
    height: 30,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'Kasir Genteng', parent: demoPill1, x: 12, y: 8, props: {'fontSize': 10, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});

  final demoPill2 = createNode(
    type: 'frame',
    parent: authCard,
    name: 'DemoPill2',
    x: 122,
    y: 420,
    width: 105,
    height: 30,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'Manager Genteng', parent: demoPill2, x: 10, y: 8, props: {'fontSize': 10, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});

  final demoPill3 = createNode(
    type: 'frame',
    parent: authCard,
    name: 'DemoPill3',
    x: 234,
    y: 420,
    width: 88,
    height: 30,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'Super Admin', parent: demoPill3, x: 10, y: 8, props: {'fontSize': 10, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});

  // Footer Tenant Isolation Note
  createText(
    text: '🔒 Staf terundang langsung diarahkan ke cabang yang ditugaskan tanpa membuat bisnis baru.',
    parent: f1,
    x: 24,
    y: 710,
    width: 342,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextSecondary]},
  );

  // =========================================================================
  // FRAME 2: STEP 2 - BUSINESS NAME (NAMA BISNIS)
  // =========================================================================
  final f2 = createFrame(
    name: '02_Onboarding_BusinessName',
    x: 450,
    y: 0,
    width: 390,
    height: 844,
    props: {'fills': [cCanvas], 'cornerRadius': 40, 'clip': true},
  );

  // Status Bar
  createText(text: '09:41', parent: f2, x: 28, y: 16, props: {'fontSize': 14, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});
  createText(text: '●●●  WiFi  100%', parent: f2, x: 280, y: 16, props: {'fontSize': 12, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});

  // Top Nav Bar with Capsule Step Pill
  createText(text: '←', parent: f2, x: 24, y: 50, props: {'fontSize': 20, 'fontVariations': {'wght': 900}, 'fills': [cTextPrimary]});
  
  final stepPill2 = createNode(
    type: 'frame',
    parent: f2,
    name: 'StepPill2',
    x: 235,
    y: 48,
    width: 131,
    height: 30,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'LANGKAH 1 DARI 3', parent: stepPill2, x: 12, y: 8, props: {'fontSize': 9, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.5px', 'fills': [cObsidian]});

  // Progress Bar (33% Obsidian)
  createNode(type: 'rectangle', parent: f2, name: 'ProgressTrack', x: 24, y: 90, width: 342, height: 4, props: {'fills': [cBorder], 'cornerRadius': 2});
  createNode(type: 'rectangle', parent: f2, name: 'ProgressFill', x: 24, y: 90, width: 114, height: 4, props: {'fills': [cObsidian], 'cornerRadius': 2});

  // Icon Badge
  final storeIconBadge = createNode(
    type: 'frame',
    parent: f2,
    name: 'StoreIconBadge',
    x: 24,
    y: 115,
    width: 52,
    height: 52,
    props: {'fills': [cObsidian], 'cornerRadius': 18},
  );
  createText(text: '🏬', parent: storeIconBadge, x: 13, y: 12, props: {'fontSize': 24});

  // Title & Subtitle
  createText(
    text: 'Apa nama bisnis rental Anda?',
    parent: f2,
    x: 24,
    y: 185,
    width: 342,
    props: {'fontSize': 23, 'fontVariations': {'wght': 900}, 'letterSpacing': '-0.5px', 'lineHeight': '30px', 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Masukkan nama toko, brand, atau usaha rental yang ingin Anda kelola. Nama ini dapat disesuaikan kapan saja di Pengaturan.',
    parent: f2,
    x: 24,
    y: 255,
    width: 342,
    props: {'fontSize': 13, 'lineHeight': '19px', 'fills': [cTextSecondary]},
  );

  // Elevated Input Card
  final nameCard = createNode(
    type: 'frame',
    parent: f2,
    name: 'NameCardElevated',
    x: 24,
    y: 315,
    width: 342,
    height: 180,
    props: {'fills': [cSurface], 'cornerRadius': 22, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(
    text: 'NAMA TOKO / BRAND RENTAL *',
    parent: nameCard,
    x: 18,
    y: 18,
    props: {'fontSize': 10, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.7px', 'fills': [cTextSecondary]},
  );
  final inputBizName = createNode(
    type: 'frame',
    parent: nameCard,
    name: 'InputBizNameFocused',
    x: 18,
    y: 42,
    width: 306,
    height: 52,
    props: {'fills': [cSurface], 'cornerRadius': 14, 'stroke': cObsidian, 'strokeWeight': 2},
  );
  createText(
    text: 'Jember iPhone Rental',
    parent: inputBizName,
    x: 16,
    y: 16,
    props: {'fontSize': 15, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: '💡 Contoh: Jember iPhone Rental, ProShot Kamera, Rental Motor Jaya.',
    parent: nameCard,
    x: 18,
    y: 106,
    width: 306,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextSecondary]},
  );

  // Success indicator pill
  final validPill = createNode(
    type: 'frame',
    parent: nameCard,
    name: 'ValidPill',
    x: 18,
    y: 138,
    width: 250,
    height: 26,
    props: {'fills': [cEmeraldBg], 'cornerRadius': 13, 'stroke': cEmeraldBorder, 'strokeWeight': 1},
  );
  createText(
    text: '✓ Nama memenuhi standar multi-tenant',
    parent: validPill,
    x: 10,
    y: 6,
    props: {'fontSize': 10, 'fontVariations': {'wght': 700}, 'fills': [cEmerald]},
  );

  // Luxe Architecture & Immutability Guarantee Card
  final archCard = createNode(
    type: 'frame',
    parent: f2,
    name: 'LuxeArchCard',
    x: 24,
    y: 515,
    width: 342,
    height: 125,
    props: {'fills': [cSurface], 'cornerRadius': 20, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(
    text: '🛡️ Integritas Identitas & Data Relasional',
    parent: archCard,
    x: 16,
    y: 16,
    props: {'fontSize': 12, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Nama bisnis dapat diubah kapan saja melalui menu Pengaturan tanpa merusak identitas internal sistem (UUID), relasi cabang, inventaris, atau transaksi.',
    parent: archCard,
    x: 16,
    y: 42,
    width: 310,
    props: {'fontSize': 11, 'lineHeight': '17px', 'fills': [cTextSecondary]},
  );

  // Floating Bottom Capsule CTA
  final btnStep2 = createNode(
    type: 'frame',
    parent: f2,
    name: 'BtnStep2Capsule',
    x: 24,
    y: 730,
    width: 342,
    height: 52,
    props: {'fills': [cObsidian], 'cornerRadius': 16},
  );
  createText(
    text: 'Lanjutkan ke Struktur Cabang →',
    parent: btnStep2,
    x: 65,
    y: 17,
    props: {'fontSize': 14, 'fontVariations': {'wght': 800}, 'fills': [cWhite]},
  );

  // =========================================================================
  // FRAME 3: STEP 3 - BUSINESS & BRANCH STRUCTURE
  // =========================================================================
  final f3 = createFrame(
    name: '03_Onboarding_BranchStructure',
    x: 900,
    y: 0,
    width: 390,
    height: 844,
    props: {'fills': [cCanvas], 'cornerRadius': 40, 'clip': true},
  );

  // Status Bar
  createText(text: '09:41', parent: f3, x: 28, y: 16, props: {'fontSize': 14, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});
  createText(text: '●●●  WiFi  100%', parent: f3, x: 280, y: 16, props: {'fontSize': 12, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});

  // Top Nav Bar
  createText(text: '←', parent: f3, x: 24, y: 50, props: {'fontSize': 20, 'fontVariations': {'wght': 900}, 'fills': [cTextPrimary]});
  
  final stepPill3 = createNode(
    type: 'frame',
    parent: f3,
    name: 'StepPill3',
    x: 235,
    y: 48,
    width: 131,
    height: 30,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'LANGKAH 2 DARI 3', parent: stepPill3, x: 12, y: 8, props: {'fontSize': 9, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.5px', 'fills': [cObsidian]});

  // Progress Bar (66% Obsidian)
  createNode(type: 'rectangle', parent: f3, name: 'ProgressTrack', x: 24, y: 90, width: 342, height: 4, props: {'fills': [cBorder], 'cornerRadius': 2});
  createNode(type: 'rectangle', parent: f3, name: 'ProgressFill', x: 24, y: 90, width: 228, height: 4, props: {'fills': [cObsidian], 'cornerRadius': 2});

  // Title & Subtitle
  createText(
    text: 'Bagaimana kondisi bisnis Anda saat ini?',
    parent: f3,
    x: 24,
    y: 115,
    width: 342,
    props: {'fontSize': 21, 'fontVariations': {'wght': 900}, 'letterSpacing': '-0.4px', 'lineHeight': '28px', 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Pilih opsi yang paling menggambarkan operasional Anda. Anda dapat menambah atau mengubah cabang kapan saja.',
    parent: f3,
    x: 24,
    y: 180,
    width: 342,
    props: {'fontSize': 12, 'lineHeight': '18px', 'fills': [cTextSecondary]},
  );

  // OPTION 1: SELECTED (Luxe Spatial Card)
  final opt1 = createNode(
    type: 'frame',
    parent: f3,
    name: 'Option1_Selected',
    x: 24,
    y: 235,
    width: 342,
    height: 125,
    props: {'fills': [cSurface], 'cornerRadius': 20, 'stroke': cObsidian, 'strokeWeight': 2},
  );
  // Radio Dot
  final rDot1 = createNode(type: 'frame', parent: opt1, name: 'RadioDot', x: 16, y: 16, width: 20, height: 20, props: {'fills': [cObsidian], 'cornerRadius': 10});
  createNode(type: 'frame', parent: rDot1, name: 'DotCenter', x: 6, y: 6, width: 8, height: 8, props: {'fills': [cWhite], 'cornerRadius': 4});
  
  // Capsule Badge
  final b1 = createNode(type: 'frame', parent: opt1, name: 'BadgePopular', x: 44, y: 14, width: 110, height: 24, props: {'fills': [cEmeraldBg], 'cornerRadius': 12, 'stroke': cEmeraldBorder, 'strokeWeight': 1});
  createText(text: 'Pilihan Utama', parent: b1, x: 12, y: 5, props: {'fontSize': 10, 'fontVariations': {'wght': 800}, 'fills': [cEmerald]});

  createText(
    text: 'Saya mengelola satu toko / lokasi',
    parent: opt1,
    x: 16,
    y: 46,
    width: 310,
    props: {'fontSize': 14, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Operasional dari 1 outlet fisik. Sistem otomatis menginisialisasi cabang "Pusat" sebagai basis kasir & inventaris Anda.',
    parent: opt1,
    x: 16,
    y: 72,
    width: 310,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextSecondary]},
  );

  // OPTION 2: MULTI BRANCH (Luxe Card)
  final opt2 = createNode(
    type: 'frame',
    parent: f3,
    name: 'Option2_MultiBranch',
    x: 24,
    y: 375,
    width: 342,
    height: 115,
    props: {'fills': [cSurface], 'cornerRadius': 20, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createNode(type: 'frame', parent: opt2, name: 'RadioEmpty2', x: 16, y: 16, width: 20, height: 20, props: {'fills': [cSurface], 'cornerRadius': 10, 'stroke': cBorder, 'strokeWeight': 1.5});
  createText(
    text: 'Sudah memiliki beberapa cabang',
    parent: opt2,
    x: 46,
    y: 16,
    width: 280,
    props: {'fontSize': 14, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Mulai dari cabang utama terlebih dahulu. Cabang tambahan, hak akses staf cabang, dan mutasi stok dapat didaftarkan nanti.',
    parent: opt2,
    x: 16,
    y: 50,
    width: 310,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextSecondary]},
  );

  // OPTION 3: PLAN TO EXPAND (Luxe Card)
  final opt3 = createNode(
    type: 'frame',
    parent: f3,
    name: 'Option3_ExpandPlan',
    x: 24,
    y: 505,
    width: 342,
    height: 115,
    props: {'fills': [cSurface], 'cornerRadius': 20, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createNode(type: 'frame', parent: opt3, name: 'RadioEmpty3', x: 16, y: 16, width: 20, height: 20, props: {'fills': [cSurface], 'cornerRadius': 10, 'stroke': cBorder, 'strokeWeight': 1.5});
  createText(
    text: '1 Lokasi, dengan rencana ekspansi',
    parent: opt3,
    x: 46,
    y: 16,
    width: 280,
    props: {'fontSize': 14, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Mulai sederhana hari ini dengan fondasi arsitektur multi-tenant yang siap berkembang tanpa perlu mengubah konfigurasi sistem.',
    parent: opt3,
    x: 16,
    y: 50,
    width: 310,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextSecondary]},
  );

  // Reassurance Callout Pill
  createText(
    text: '📌 Pilihan ini tidak membatasi kemampuan Anda menambah cabang baru di kemudian hari.',
    parent: f3,
    x: 24,
    y: 640,
    width: 342,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextMuted]},
  );

  // Navigation Buttons
  final btnBack3 = createNode(
    type: 'frame',
    parent: f3,
    name: 'BtnBack3',
    x: 24,
    y: 730,
    width: 100,
    height: 52,
    props: {'fills': [cSurface], 'cornerRadius': 16, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'Kembali', parent: btnBack3, x: 24, y: 17, props: {'fontSize': 13, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});

  final btnNext3 = createNode(
    type: 'frame',
    parent: f3,
    name: 'BtnNext3Obsidian',
    x: 136,
    y: 730,
    width: 230,
    height: 52,
    props: {'fills': [cObsidian], 'cornerRadius': 16},
  );
  createText(text: 'Lanjutkan ke Kategori →', parent: btnNext3, x: 38, y: 17, props: {'fontSize': 13, 'fontVariations': {'wght': 800}, 'fills': [cWhite]});

  // =========================================================================
  // FRAME 4: STEP 4 - BUSINESS CATEGORY (KATEGORI BISNIS)
  // =========================================================================
  final f4 = createFrame(
    name: '04_Onboarding_BusinessCategory',
    x: 1350,
    y: 0,
    width: 390,
    height: 844,
    props: {'fills': [cCanvas], 'cornerRadius': 40, 'clip': true},
  );

  // Status Bar
  createText(text: '09:41', parent: f4, x: 28, y: 16, props: {'fontSize': 14, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});
  createText(text: '●●●  WiFi  100%', parent: f4, x: 280, y: 16, props: {'fontSize': 12, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});

  // Top Nav Bar
  createText(text: '←', parent: f4, x: 24, y: 50, props: {'fontSize': 20, 'fontVariations': {'wght': 900}, 'fills': [cTextPrimary]});
  
  final stepPill4 = createNode(
    type: 'frame',
    parent: f4,
    name: 'StepPill4',
    x: 180,
    y: 48,
    width: 125,
    height: 30,
    props: {'fills': [cSurfaceMuted], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'LANGKAH 3 DARI 3', parent: stepPill4, x: 10, y: 8, props: {'fontSize': 9, 'fontVariations': {'wght': 800}, 'letterSpacing': '0.5px', 'fills': [cObsidian]});

  // Skip Capsule Button
  final btnSkipPill = createNode(
    type: 'frame',
    parent: f4,
    name: 'BtnSkipPill',
    x: 315,
    y: 48,
    width: 51,
    height: 30,
    props: {'fills': [cSurface], 'cornerRadius': 15, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'Lewati', parent: btnSkipPill, x: 10, y: 8, props: {'fontSize': 10, 'fontVariations': {'wght': 700}, 'fills': [cTextSecondary]});

  // Progress Bar (100% Obsidian)
  createNode(type: 'rectangle', parent: f4, name: 'ProgressTrack', x: 24, y: 90, width: 342, height: 4, props: {'fills': [cBorder], 'cornerRadius': 2});
  createNode(type: 'rectangle', parent: f4, name: 'ProgressFill', x: 24, y: 90, width: 342, height: 4, props: {'fills': [cObsidian], 'cornerRadius': 2});

  // Title & Subtitle
  createText(
    text: 'Apa saja yang Anda sewakan?',
    parent: f4,
    x: 24,
    y: 112,
    width: 342,
    props: {'fontSize': 22, 'fontVariations': {'wght': 900}, 'letterSpacing': '-0.4px', 'lineHeight': '28px', 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Pilih kategori yang sesuai untuk mempersonalisasi alur awal. Pilihan ini tidak mengunci jenis produk yang bisa Anda tambahkan.',
    parent: f4,
    x: 24,
    y: 148,
    width: 342,
    props: {'fontSize': 12, 'lineHeight': '17px', 'fills': [cTextSecondary]},
  );

  // 6 Luxe Spatial Category Tiles (2 columns × 3 rows)
  final catItems = [
    {'title': 'iPhone & Smartphone', 'icon': '📱', 'sel': true, 'sub': 'Unit Apple & Android'},
    {'title': 'Gadget & Elektronik', 'icon': '💻', 'sel': true, 'sub': 'iPad, Laptop, Game Console'},
    {'title': 'Kamera & Lensa', 'icon': '📷', 'sel': false, 'sub': 'Mirrorless, DSLR, Lensa'},
    {'title': 'Kendaraan Bermotor', 'icon': '🛵', 'sel': false, 'sub': 'Motor, Mobil, Sepeda Listrik'},
    {'title': 'Alat & Perlengkapan', 'icon': '🛠️', 'sel': false, 'sub': 'Event Gear, Proyektor'},
    {'title': 'Lainnya', 'icon': '📦', 'sel': false, 'sub': 'Peralatan Outdoor & Dll'},
  ];

  for (int i = 0; i < catItems.length; i++) {
    final item = catItems[i];
    final col = i % 2;
    final row = i ~/ 2;
    final xPos = 24.0 + (col * 176.0);
    final yPos = 195.0 + (row * 105.0);
    final isSel = item['sel'] as bool;

    final card = createNode(
      type: 'frame',
      parent: f4,
      name: 'Cat_${item['title']}',
      x: xPos,
      y: yPos,
      width: 166,
      height: 95,
      props: {
        'fills': [isSel ? cObsidian : cSurface],
        'cornerRadius': 18,
        'stroke': isSel ? cObsidian : cBorder,
        'strokeWeight': 1,
      },
    );

    // Icon
    createText(text: item['icon'] as String, parent: card, x: 12, y: 12, props: {'fontSize': 20});
    
    // Check indicator if selected
    if (isSel) {
      final chk = createNode(type: 'frame', parent: card, name: 'CheckCircle', x: 132, y: 12, width: 20, height: 20, props: {'fills': [cEmerald], 'cornerRadius': 10});
      createText(text: '✓', parent: chk, x: 5, y: 2, props: {'fontSize': 11, 'fontVariations': {'wght': 900}, 'fills': [cWhite]});
    }

    createText(
      text: item['title'] as String,
      parent: card,
      x: 12,
      y: 44,
      width: 142,
      props: {'fontSize': 12, 'fontVariations': {'wght': 800}, 'fills': [isSel ? cWhite : cTextPrimary]},
    );
    createText(
      text: item['sub'] as String,
      parent: card,
      x: 12,
      y: 65,
      width: 142,
      props: {'fontSize': 10, 'fills': [isSel ? '#A1A1AA' : cTextSecondary]},
    );
  }

  // Non-restrictive Luxe Callout Box
  final callout4 = createNode(
    type: 'frame',
    parent: f4,
    name: 'CalloutNoLimitLuxe',
    x: 24,
    y: 530,
    width: 342,
    height: 125,
    props: {'fills': [cSurface], 'cornerRadius': 18, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(
    text: '⚡ Bebas Menyewakan Barang Apapun',
    parent: callout4,
    x: 14,
    y: 14,
    props: {'fontSize': 12, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Pilihan kategori ini murni untuk mempersonalisasi alur awal dan TIDAK membatasi tipe barang yang ingin Anda sewakan. Tidak mengubah role pengguna, skema harga, atau batasan langganan.',
    parent: callout4,
    x: 14,
    y: 38,
    width: 314,
    props: {'fontSize': 11, 'lineHeight': '16px', 'fills': [cTextSecondary]},
  );

  // Bottom Navigation Bar
  final btnBack4 = createNode(
    type: 'frame',
    parent: f4,
    name: 'BtnBack4',
    x: 24,
    y: 730,
    width: 100,
    height: 52,
    props: {'fills': [cSurface], 'cornerRadius': 16, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: 'Kembali', parent: btnBack4, x: 24, y: 17, props: {'fontSize': 13, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});

  final btnFinish4 = createNode(
    type: 'frame',
    parent: f4,
    name: 'BtnFinish4Obsidian',
    x: 136,
    y: 730,
    width: 230,
    height: 52,
    props: {'fills': [cObsidian], 'cornerRadius': 16},
  );
  createText(text: 'Selesaikan Setup Bisnis ✓', parent: btnFinish4, x: 30, y: 17, props: {'fontSize': 13, 'fontVariations': {'wght': 800}, 'fills': [cWhite]});

  // =========================================================================
  // FRAME 5: STEP 5 - DASHBOARD & PROGRESSIVE CHECKLIST
  // =========================================================================
  final f5 = createFrame(
    name: '05_Onboarding_ReadyDashboard',
    x: 1800,
    y: 0,
    width: 390,
    height: 844,
    props: {'fills': [cCanvas], 'cornerRadius': 40, 'clip': true},
  );

  // Status Bar
  createText(text: '09:41', parent: f5, x: 28, y: 16, props: {'fontSize': 14, 'fontVariations': {'wght': 700}, 'fills': [cTextPrimary]});
  createText(text: '●●●  WiFi  100%', parent: f5, x: 280, y: 16, props: {'fontSize': 12, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});

  // Top Operational Bar with Branch Capsule Pill
  final bizPill = createNode(
    type: 'frame',
    parent: f5,
    name: 'BizBranchCapsulePill',
    x: 24,
    y: 48,
    width: 230,
    height: 38,
    props: {'fills': [cSurface], 'cornerRadius': 19, 'stroke': cBorder, 'strokeWeight': 1},
  );
  createText(text: '🏢 Jember iPhone (Pusat) ▼', parent: bizPill, x: 14, y: 10, props: {'fontSize': 12, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]});

  // Bell & Avatar
  final bellBtn = createNode(type: 'frame', parent: f5, name: 'BellBtn', x: 295, y: 48, width: 38, height: 38, props: {'fills': [cSurface], 'cornerRadius': 19, 'stroke': cBorder, 'strokeWeight': 1});
  createText(text: '🔔', parent: bellBtn, x: 10, y: 9, props: {'fontSize': 14});
  final avtBtn = createNode(type: 'frame', parent: f5, name: 'AvtBtn', x: 340, y: 48, width: 38, height: 38, props: {'fills': [cObsidian], 'cornerRadius': 19});
  createText(text: 'O', parent: avtBtn, x: 13, y: 9, props: {'fontSize': 14, 'fontVariations': {'wght': 800}, 'fills': [cWhite]});

  // Operational Success Banner (Luxe Card)
  final celCard = createNode(
    type: 'frame',
    parent: f5,
    name: 'CelCardLuxe',
    x: 24,
    y: 98,
    width: 342,
    height: 85,
    props: {'fills': [cSurface], 'cornerRadius': 20, 'stroke': cBorder, 'strokeWeight': 1},
  );
  final celBadge = createNode(type: 'frame', parent: celCard, name: 'CheckBadge', x: 14, y: 14, width: 28, height: 28, props: {'fills': [cEmeraldBg], 'cornerRadius': 14, 'stroke': cEmeraldBorder, 'strokeWeight': 1});
  createText(text: '✓', parent: celBadge, x: 8, y: 4, props: {'fontSize': 14, 'fontVariations': {'wght': 900}, 'fills': [cEmerald]});

  createText(
    text: 'Bisnis Anda Siap Digunakan!',
    parent: celCard,
    x: 52,
    y: 14,
    props: {'fontSize': 14, 'fontVariations': {'wght': 900}, 'fills': [cTextPrimary]},
  );
  createText(
    text: 'Toko "Jember iPhone Rental" aktif. Cabang Pusat siap melayani kasir & verifikasi jaminan KTP.',
    parent: celCard,
    x: 52,
    y: 38,
    width: 275,
    props: {'fontSize': 11, 'lineHeight': '15px', 'fills': [cTextSecondary]},
  );

  // Progressive Setup Checklist (Luxe Card)
  final checkCard = createNode(
    type: 'frame',
    parent: f5,
    name: 'ChecklistCardLuxe',
    x: 24,
    y: 195,
    width: 342,
    height: 440,
    props: {'fills': [cSurface], 'cornerRadius': 22, 'stroke': cBorder, 'strokeWeight': 1},
  );

  createText(
    text: 'Panduan Memulai Toko',
    parent: checkCard,
    x: 16,
    y: 16,
    props: {'fontSize': 14, 'fontVariations': {'wght': 900}, 'fills': [cTextPrimary]},
  );
  
  // Progress Pill (1/6 Selesai)
  final chkProgPill = createNode(
    type: 'frame',
    parent: checkCard,
    name: 'ChkProgPill',
    x: 235,
    y: 14,
    width: 90,
    height: 24,
    props: {'fills': [cObsidian], 'cornerRadius': 12},
  );
  createText(text: '1/6 Selesai', parent: chkProgPill, x: 16, y: 4, props: {'fontSize': 10, 'fontVariations': {'wght': 800}, 'fills': [cWhite]});

  // Checklist Progress Bar (16.6% Obsidian)
  createNode(type: 'rectangle', parent: checkCard, name: 'ChkTrack', x: 16, y: 44, width: 310, height: 4, props: {'fills': [cBorder], 'cornerRadius': 2});
  createNode(type: 'rectangle', parent: checkCard, name: 'ChkFill', x: 16, y: 44, width: 52, height: 4, props: {'fills': [cObsidian], 'cornerRadius': 2});

  // 6 Checklist Items (PRD & Operational Feature Integration)
  final checklistItems = [
    {'title': '1. Profil Toko & Kontak Cabang', 'sub': 'Alamat & nomor WhatsApp cabang', 'btn': 'Selesai ✓', 'done': true},
    {'title': '2. Tambah Model Katalog Aset', 'sub': 'Definisikan iPhone, gadget, kamera', 'btn': 'Katalog', 'done': false},
    {'title': '3. Registrasi Unit Fisik Pertama', 'sub': 'Serial number, IMEI, Grade A/B/C', 'btn': 'Unit', 'done': false},
    {'title': '4. Atur Paket Tarif Sewa (6j/12j/24j)', 'sub': 'Skema harga per jam & harian', 'btn': 'Tarif', 'done': false},
    {'title': '5. Hubungkan Printer Struk Bluetooth', 'sub': 'Thermal 58mm/80mm ESC/POS', 'btn': 'Printer', 'done': false},
    {'title': '6. Atur PIN Diskon & Undang Kasir', 'sub': 'Otorisasi PIN manajer & akses staf', 'btn': 'Staf', 'done': false},
  ];

  for (int i = 0; i < checklistItems.length; i++) {
    final item = checklistItems[i];
    final yItem = 58.0 + (i * 54.0);
    final isDone = item['done'] as bool;

    final row = createNode(
      type: 'frame',
      parent: checkCard,
      name: 'Item_${i + 1}',
      x: 12,
      y: yItem,
      width: 318,
      height: 48,
      props: {'fills': [cCanvas], 'cornerRadius': 12, 'stroke': cBorder, 'strokeWeight': 0.8},
    );

    // Indicator Dot (Emerald if done, outline if not)
    if (isDone) {
      final circDone = createNode(type: 'frame', parent: row, name: 'CircDone', x: 10, y: 15, width: 18, height: 18, props: {'fills': [cEmerald], 'cornerRadius': 9});
      createText(text: '✓', parent: circDone, x: 4, y: 1, props: {'fontSize': 11, 'fontVariations': {'wght': 900}, 'fills': [cWhite]});
    } else {
      createNode(type: 'frame', parent: row, name: 'CircPending', x: 10, y: 15, width: 18, height: 18, props: {'fills': [cSurface], 'cornerRadius': 9, 'stroke': cBorder, 'strokeWeight': 1.5});
    }

    createText(
      text: item['title'] as String,
      parent: row,
      x: 36,
      y: 9,
      props: {'fontSize': 11, 'fontVariations': {'wght': 800}, 'fills': [cTextPrimary]},
    );
    createText(
      text: item['sub'] as String,
      parent: row,
      x: 36,
      y: 27,
      props: {'fontSize': 9, 'fills': [cTextSecondary]},
    );

    final itemBtn = createNode(
      type: 'frame',
      parent: row,
      name: 'ItemBtn',
      x: 242,
      y: 10,
      width: 66,
      height: 28,
      props: {
        'fills': [isDone ? cEmeraldBg : cSurface],
        'cornerRadius': 8,
        'stroke': isDone ? cEmeraldBorder : cBorder,
        'strokeWeight': 1,
      },
    );
    createText(
      text: item['btn'] as String,
      parent: itemBtn,
      x: 8,
      y: 7,
      props: {
        'fontSize': 9,
        'fontVariations': {'wght': 800},
        'fills': [isDone ? cEmerald : cObsidian],
      },
    );
  }

  createText(
    text: '💡 Checklist bersifat non-blocking & dapat disembunyikan kapan saja.',
    parent: checkCard,
    x: 14,
    y: 395,
    width: 314,
    props: {'fontSize': 9, 'fills': [cTextMuted]},
  );

  // Quick Action Button (+ Sewa Baru)
  final btnQuickRent = createNode(
    type: 'frame',
    parent: f5,
    name: 'BtnQuickRentCapsule',
    x: 24,
    y: 650,
    width: 342,
    height: 48,
    props: {'fills': [cObsidian], 'cornerRadius': 16},
  );
  createText(
    text: '➕ Buat Transaksi Sewa Baru (POS)',
    parent: btnQuickRent,
    x: 60,
    y: 15,
    props: {'fontSize': 13, 'fontVariations': {'wght': 800}, 'fills': [cWhite]},
  );

  // Floating Capsule Bottom Dock (Section 2 UI_UX_DESIGN.md)
  final dock = createNode(
    type: 'frame',
    parent: f5,
    name: 'FloatingCapsuleBottomDock',
    x: 35,
    y: 730,
    width: 320,
    height: 58,
    props: {'fills': [cObsidian], 'cornerRadius': 29},
  );
  createText(text: '🏠 Home', parent: dock, x: 24, y: 20, props: {'fontSize': 11, 'fontVariations': {'wght': 800}, 'fills': [cWhite]});
  createText(text: '📋 Booking', parent: dock, x: 100, y: 20, props: {'fontSize': 11, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});
  createText(text: '🎟️ Voucher', parent: dock, x: 180, y: 20, props: {'fontSize': 11, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});
  createText(text: '📊 Kasir', parent: dock, x: 255, y: 20, props: {'fontSize': 11, 'fontVariations': {'wght': 600}, 'fills': [cTextSecondary]});

  // Write out JSON script
  final outFile = File('C:/Users/VyndhyCell/Projects/rentcore/design/figcraft_onboarding_script.json');
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(jsonEncode(commands));
  print('Generated ${commands.length} commands to ${outFile.path}');
}
