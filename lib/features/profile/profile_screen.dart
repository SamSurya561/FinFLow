import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Core
import '../../core/auth/auth_service.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/profile_storage.dart';
import '../../core/storage/export_import_service.dart';
import '../../core/notifiers/theme_notifier.dart';
import '../../core/services/firestore_service.dart'; // REQUIRED for backend data

// Models
import '../../core/models/transaction_model.dart'; // NEW MODEL
import '../../features/budgets/models/budget_model.dart';

// Screens
import 'profile_edit_sheet.dart';
import 'app_update_screen.dart';
import 'legal_screens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  User? _authUser;
  Profile? _profile;
  bool _isGuest = false;
  bool _loading = true;

  // Real Stats
  double _safeToSpend = 0.0;
  double _monthlySpent = 0.0;
  int _activeBudgets = 0;

  late AnimationController _animController;
  final GlobalKey _exportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _initData();
    _checkProfileTutorial();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkProfileTutorial() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final seen = await LocalStorage.hasSeenProfileIntro();
    if (!seen && mounted) {
      _showProfileTutorial();
      await LocalStorage.setSeenProfileIntro();
    }
  }

  void _showProfileTutorial() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "export_data",
          keyTarget: _exportKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 0,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Backup Data\nExport your data to CSV here.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        )
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      textSkip: "GOT IT",
    ).show(context: context);
  }

  Future<void> _initData() async {
    setState(() => _loading = true);

    _authUser = AuthService.currentUser;
    _isGuest = await LocalStorage.isGuest();
    _profile = await Profile.getProfileOrDefault();

    // 1. Fetch Real Data from Firestore (Solid Backend)
    // We use .first to get a one-time snapshot of the current data
    final transactions = await FirestoreService().getTransactionsStream().first;
    final budgets = await FirestoreService().getBudgetsStream().first;
    final goalMap = await LocalStorage.getSavingGoal();

    // 2. Calculate Stats (Current Month Only) to match Dashboard
    final now = DateTime.now();
    double income = 0;
    double expense = 0;

    for (var t in transactions) {
      if (t.date.month == now.month && t.date.year == now.year) {
        if (t.type == TxnType.income) income += t.amount;
        if (t.type == TxnType.expense) expense += t.amount;
      }
    }

    final sGoal = goalMap != null ? (goalMap['amount'] as num).toDouble() : 0.0;

    // Logic: Safe = Income - Spent - Goal
    final safe = income - expense - sGoal;

    if (mounted) {
      setState(() {
        _monthlySpent = expense;
        _activeBudgets = budgets.length;
        _safeToSpend = safe < 0 ? 0 : safe;
        _loading = false;
      });
      _animController.forward();
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sign Out", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (_isGuest) {
        await LocalStorage.setGuest(false);
      } else {
        await AuthService.signOut();
      }
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  // --- Theme Selection Dialog ---
  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("App Theme", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildThemeOption("System Default", ThemeMode.system, Icons.brightness_auto),
              _buildThemeOption("Light Mode", ThemeMode.light, Icons.light_mode),
              _buildThemeOption("Dark Mode", ThemeMode.dark, Icons.dark_mode),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, IconData icon) {
    final isSelected = ThemeNotifier.themeMode.value == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.blue : null, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        ThemeNotifier.setTheme(mode);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _requestNotificationPermission(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    // Get Name & Image
    final displayName = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : (_authUser?.displayName ?? "User");

    // Check if Google Photo exists, else use base64, else use initial
    ImageProvider? profileImage;
    if (_authUser?.photoURL != null) {
      profileImage = NetworkImage(_authUser!.photoURL!);
    } else if (_profile?.imageBase64.isNotEmpty == true) {
      try {
        profileImage = MemoryImage(base64Decode(_profile!.imageBase64));
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: bgColor,
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: Text('Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800, fontSize: 28)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 1. Profile Card
                  _AnimatedSection(
                    controller: _animController, delay: 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final res = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => ProfileEditSheet(initial: _profile!)
                              );
                              if(res != null) setState(() => _profile = res);
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: profileImage,
                                  child: profileImage == null ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey)) : null,
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.edit, size: 12, color: Colors.white)),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                Text(_authUser?.email ?? (_isGuest ? "Guest Mode" : ""), style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Stats
                  _AnimatedSection(controller: _animController, delay: 100, child: Row(children: [
                    Expanded(child: _StatBox('Safe Spend', '₹${_safeToSpend.toStringAsFixed(0)}', Colors.green, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatBox('Mo. Spent', '₹${_monthlySpent.toStringAsFixed(0)}', Colors.redAccent, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatBox('Budgets', '$_activeBudgets', Colors.blue, isDark)),
                  ])),

                  const SizedBox(height: 32),

                  // 3. Settings
                  _AnimatedSection(controller: _animController, delay: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SectionHeader('PREFERENCES'),
                    _SettingsGroup(isDark: isDark, children: [
                      _SettingsTile(
                        icon: Icons.brightness_6_rounded,
                        title: 'App Theme',
                        subtitle: _getThemeName(),
                        isDark: isDark,
                        onTap: _showThemeSelector,
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_rounded,
                        title: 'Notifications',
                        isDark: isDark,
                        trailing: Switch.adaptive(value: true, activeColor: Colors.blue, onChanged: _requestNotificationPermission),
                      ),
                      Container(
                        key: _exportKey,
                        child: _SettingsTile(icon: Icons.cloud_download_rounded, title: 'Export CSV', isDark: isDark, onTap: () => ExportImportService.exportAllCsv(context)),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _SectionHeader('ABOUT'),
                    _SettingsGroup(isDark: isDark, children: [
                      _SettingsTile(icon: Icons.system_update_rounded, title: 'Check for Updates', isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppUpdateScreen()))),
                      _SettingsTile(icon: Icons.description_rounded, title: 'Terms & Conditions', isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleInfoScreen(title: "Terms", content: "Terms and conditions go here...")))),
                      _SettingsTile(icon: Icons.privacy_tip_rounded, title: 'Privacy Policy', isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleInfoScreen(title: "Privacy", content: "Privacy policy goes here...")))),
                      _SettingsTile(icon: Icons.info_rounded, title: 'About FinFlow', isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen()))),
                    ]),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handleSignOut,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName() {
    final mode = ThemeNotifier.themeMode.value;
    if (mode == ThemeMode.light) return "Light";
    if (mode == ThemeMode.dark) return "Dark";
    return "System Default";
  }
}

// --- Components ---
class _StatBox extends StatelessWidget {
  final String label; final String value; final Color color; final bool isDark;
  const _StatBox(this.label, this.value, this.color, this.isDark);
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))]));
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children; final bool isDark;
  const _SettingsGroup({required this.children, required this.isDark});
  @override Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: children));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle; final bool isDark; final Widget? trailing; final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, this.subtitle, required this.isDark, this.trailing, this.onTap});
  @override Widget build(BuildContext context) {
    return ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black)), title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)), subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: Colors.grey[500], fontSize: 12)) : null, trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; const _SectionHeader(this.title);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 12, bottom: 8), child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0)));
}

class _AnimatedSection extends StatelessWidget {
  final Widget child; final int delay; final AnimationController controller;
  const _AnimatedSection({required this.child, required this.delay, required this.controller});
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: (ctx, _) {
      final start = delay / 800.0;
      final curve = CurvedAnimation(parent: controller, curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut));
      return Opacity(opacity: curve.value, child: Transform.translate(offset: Offset(0, 20 * (1 - curve.value)), child: child));
    });
  }
}