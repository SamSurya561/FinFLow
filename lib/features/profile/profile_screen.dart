// lib/features/profile/profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../core/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/storage/profile_storage.dart';
import 'profile_edit_sheet.dart';

typedef ExportCsvCallback = Future<String> Function(); // returns CSV contents
typedef ImportCsvCallback = Future<bool> Function(String csvContents); // return true if success
typedef VoidAsyncCallback = Future<void> Function();

class ProfileScreen extends StatefulWidget {
  /// Optional callbacks you can provide:
  /// - onExportBudgets: produce budgets CSV string
  /// - onExportExpenses: produce expenses CSV string
  /// - onImportCsv: parse/import CSV string
  /// - onSignOut: auth sign out (optional)
  /// - onOpenSettings: open settings screen (optional)
  final ExportCsvCallback? onExportBudgets;
  final ExportCsvCallback? onExportExpenses;
  final ImportCsvCallback? onImportCsv;
  final VoidAsyncCallback? onSignOut;
  final VoidAsyncCallback? onOpenSettings;

  const ProfileScreen({
    Key? key,
    this.onExportBudgets,
    this.onExportExpenses,
    this.onImportCsv,
    this.onSignOut,
    this.onOpenSettings,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _userScreenState();
}

enum ExportChoice { budgets, expenses, both }
enum DeliveryChoice { download, share }

class _userScreenState extends State<ProfileScreen> {

  User? _authUser;      // Firebase auth user
  Profile? _profile;   // App profile data


  bool _loading = true;
  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _authUser = AuthService.currentUser;
    _loadProfile();

  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final p = await Profile.getProfileOrDefault();
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Uint8List? _imageBytes() {
    if (_profile == null) return null;
    if (_profile!.imageBase64.isEmpty) return null;
    try {
      return base64Decode(_profile!.imageBase64);
    } catch (e) {
      return null;
    }
  }

  Future<void> _openEditSheet() async {
    if (_profile == null) return;
    final res = await showModalBottomSheet<Profile?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ProfileEditSheet(initial: _profile!),
    );
    if (res != null) {
      setState(() => _profile = res);
    } else {
      await _loadProfile();
    }
  }

  /// fallback builders if callbacks not provided
  Future<String> _buildFallbackBudgetsCsv() async {
    final headers = ['id','title','limit','spent','remaining'];
    final rows = [
      headers,
      ['b1','Food','3000','500','2500'],
      ['b2','Shopping','2000','1000','1000']
    ];
    return const ListToCsvConverter().convert(rows);
  }
  Future<String> _buildFallbackExpensesCsv() async {
    final headers = ['id','amount','category','note','date_iso'];
    final rows = [
      headers,
      ['t1','1000','Shopping','Dress','2025-12-11T23:12:00'],
      ['t2','500','Food','Dinner','2025-12-11T14:47:00']
    ];
    return const ListToCsvConverter().convert(rows);
  }

  Future<Directory?> _getDownloadsDirectory() async {
    try {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
      return await getTemporaryDirectory();
    } catch (_) {
      return await getTemporaryDirectory();
    }
  }

  Future<File> _writeStringToDownloads(String fileName, String contents) async {
    final dir = await _getDownloadsDirectory();
    final path = '${dir!.path}/$fileName';
    final file = File(path);
    await file.writeAsString(contents, flush: true);
    return file;
  }

  Future<void> _exportFlow() async {
    // Step 1: ask what to export
    final exportChoice = await showDialog<ExportChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ExportChoice.budgets), child: const Text('Budgets')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ExportChoice.expenses), child: const Text('Expenses')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ExportChoice.both), child: const Text('Both')),
        ],
      ),
    );
    if (exportChoice == null) return;

    // Step 2: ask delivery method
    final delivery = await showDialog<DeliveryChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export to'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, DeliveryChoice.download), child: const Text('Download (save to Downloads folder)')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, DeliveryChoice.share), child: const Text('Share (share sheet)')),
        ],
      ),
    );
    if (delivery == null) return;

    setState(() => _exporting = true);
    try {
      final List<XFile> filesToShare = [];
      if (exportChoice == ExportChoice.budgets || exportChoice == ExportChoice.both) {
        String budgetsCsv;
        if (widget.onExportBudgets != null) {
          budgetsCsv = await widget.onExportBudgets!();
        } else {
          budgetsCsv = await _buildFallbackBudgetsCsv();
        }
        final fname = 'finflow_budgets_${DateTime.now().toIso8601String().replaceAll(':','-')}.csv';
        if (delivery == DeliveryChoice.download) {
          await _writeStringToDownloads(fname, budgetsCsv);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved $fname')));
        } else {
          final tmp = await _saveTempFile(fname, budgetsCsv);
          filesToShare.add(XFile(tmp.path));
        }
      }

      if (exportChoice == ExportChoice.expenses || exportChoice == ExportChoice.both) {
        String expensesCsv;
        if (widget.onExportExpenses != null) {
          expensesCsv = await widget.onExportExpenses!();
        } else {
          expensesCsv = await _buildFallbackExpensesCsv();
        }
        final fname = 'finflow_expenses_${DateTime.now().toIso8601String().replaceAll(':','-')}.csv';
        if (delivery == DeliveryChoice.download) {
          await _writeStringToDownloads(fname, expensesCsv);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved $fname')));
        } else {
          final tmp = await _saveTempFile(fname, expensesCsv);
          filesToShare.add(XFile(tmp.path));
        }
      }

      if (delivery == DeliveryChoice.share && filesToShare.isNotEmpty) {
        await Share.shareXFiles(filesToShare, text: 'FinFlow export');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<File> _saveTempFile(String fileName, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents, flush: true);
    return file;
  }

  Future<void> _importCsvFromString(String csvContents) async {
    setState(() => _importing = true);
    try {
      if (widget.onImportCsv != null) {
        final ok = await widget.onImportCsv!(csvContents);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV imported successfully')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV import failed')));
        }
      } else {
        // basic validation using csv package
        try {
          final rows = const CsvToListConverter().convert(csvContents, eol: '\n');
          if (rows.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV is empty or invalid')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV parsed (no import logic).')));
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV parsing failed')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      setState(() => _importing = false);
    }
  }

  Future<void> _pickCsvFileAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String contents;
      if (file.bytes != null) {
        contents = const Utf8Decoder().convert(file.bytes!);
      } else if (file.path != null) {
        contents = await File(file.path!).readAsString();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read file')));
        return;
      }
      await _importCsvFromString(contents);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
    }
  }

  Future<void> _openImportDialog() async {
    final controller = TextEditingController();
    final action = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste CSV contents here (or pick a CSV file).'),
            const SizedBox(height: 8),
            TextField(controller: controller, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('pick'), child: const Text('Pick CSV file')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop('import'), child: const Text('Import')),
        ],
      ),
    );

    if (action == 'pick') {
      await _pickCsvFileAndImport();
      return;
    }
    if (action == 'import') {
      await _importCsvFromString(controller.text);
      return;
    }
  }

  Future<void> _onSignOut() async {
    await AuthService.signOut();
    if (widget.onSignOut != null) {
      try {
        await widget.onSignOut!();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign out not configured')));
    }
  }

  Widget _buildHeader(BuildContext context, Uint8List? imgBytes) {
    final theme = Theme.of(context);
    final initials = _profile?.name.isNotEmpty == true ? _profile!.name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join() : '';
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
          backgroundImage: imgBytes != null ? MemoryImage(imgBytes) : null,
          child: imgBytes == null ? Text(initials.isEmpty ? 'S' : initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_profile?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_authUser?.email ?? '', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.onOpenSettings ?? () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings not configured'))); },
          icon: const Icon(Icons.settings_outlined),
        ),
        IconButton(
          onPressed: _openEditSheet,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    );
  }

  Widget _buildBudgetsCard(BuildContext context) {
    final theme = Theme.of(context);
    final budgetsCount = _profile?.budgetsCount ?? 0;
    final spent = _profile?.spentThisMonth ?? 0.0;
    final safe = _profile?.safeToSpendEstimate ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Budgets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              Text('$budgetsCount', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Spent this month', style: TextStyle(color: Colors.grey[400]))),
              Text('₹ ${spent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Safe to spend (est.)', style: TextStyle(color: Colors.grey[400]))),
              Text('₹ ${safe.toStringAsFixed(0)}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final img = _imageBytes();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          // settings in top bar (user requested)
          IconButton(
            onPressed: widget.onOpenSettings ?? () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings not configured'))); },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: [
            _buildHeader(context, img),
            const SizedBox(height: 18),
            _buildBudgetsCard(context),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportFlow,
                icon: const Icon(Icons.upload_file),
                label: _exporting ? const Text('Exporting...') : const Text('Export CSV (budgets & expenses)'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _openImportDialog,
                icon: const Icon(Icons.download),
                label: _importing ? const Text('Importing...') : const Text('Import CSV'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Export / Import help'),
              subtitle: const Text('How to export and import CSV files'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Export & Import help', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('• Tap Export CSV to choose which data to export (Budgets, Expenses, or Both).'),
                        Text('• Then choose Download (saves to Downloads folder) or Share (share sheet).'),
                        Text('• To import, paste CSV contents or pick a CSV file.'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _onSignOut,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sign out', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Troubleshooting', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('If avatar does not show, make sure image bytes are saved and valid base64.'),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
