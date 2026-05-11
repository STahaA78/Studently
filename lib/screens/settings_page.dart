import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/user.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/logger.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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

  void _showReportErrorDialog() {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Error'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: subjectController,
                decoration: const InputDecoration(
                  hintText: 'Subject',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Describe the error...',
                ),
                maxLines: 4,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a description' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = ref.read(authProvider).value;
                if (user == null) return;

                final success = await ref.read(userRepositoryProvider).submitErrorReport(
                      userId: user.id,
                      subject: subjectController.text,
                      description: descriptionController.text,
                    );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Error reported successfully. Thank you!'
                            : 'Failed to report error. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const Scaffold(backgroundColor: Colors.white);

    final hasChanges = _isPrivateLocal != user.isPrivate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                  : const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyle.textSecondary,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Private Account'),
            subtitle: const Text(
              'When your account is private, your profile will not be shown on the Discover page.',
            ),
            value: _isPrivateLocal,
            onChanged: (value) {
              setState(() => _isPrivateLocal = value);
            },
            activeColor: AppStyle.primaryBlue,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Support',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyle.textSecondary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined),
            title: const Text('Report Error'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showReportErrorDialog,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Login',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyle.textSecondary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppStyle.errorRed),
            title: const Text(
              'Logout',
              style: TextStyle(color: AppStyle.errorRed),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(authProvider.notifier).logout();
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: AppStyle.errorRed),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
