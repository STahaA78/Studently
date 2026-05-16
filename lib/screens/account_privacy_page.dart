import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/logger.dart';

class AccountPrivacyPage extends ConsumerStatefulWidget {
  const AccountPrivacyPage({super.key});

  @override
  ConsumerState<AccountPrivacyPage> createState() => _AccountPrivacyPageState();
}

class _AccountPrivacyPageState extends ConsumerState<AccountPrivacyPage> {
  bool _isPrivateLocal = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final user = ref.watch(authProvider).value;
      if (user != null) {
        _isPrivateLocal = user.isPrivate;
        _isInitialized = true;
      }
    }
  }

  Future<void> _savePrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).updateProfile({
        'is_private': _isPrivateLocal,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      logger.e("Failed to update privacy settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update privacy settings')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const Scaffold(backgroundColor: Colors.white);

    final hasChanges = _isPrivateLocal != user.isPrivate;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy',
          style: TextStyle(
            color: Colors.black,
            fontSize: AppStyle.appBarTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _savePrivacySettings,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Private Account'),
            subtitle: const Text(
              'When your account is private, your profile will not be shown on the Discover page.',
            ),
            value: _isPrivateLocal,
            onChanged: (value) {
              setState(() => _isPrivateLocal = value);
            },
            activeThumbColor: AppStyle.primaryBlue,
          ),
        ],
      ),
    );
  }
}
