import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/app_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/models/user.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/auth_provider.dart';

// Wrapper class to add selected state to Interest
class InterestOption {
  final Interest interest;
  bool selected;

  InterestOption({required this.interest, this.selected = false});

  String get name => interest.name;
  String get emoji => interest.emoji;
}

class InterestsSelectionPage extends ConsumerStatefulWidget {
  final List<Interest> initialInterests;
  final User? user;
  final bool completeSignup;
  final bool extractedFields;

  const InterestsSelectionPage({
    super.key,
    this.initialInterests = const [],
    this.user,
    this.completeSignup = false,
    this.extractedFields = true,
  });

  @override
  ConsumerState<InterestsSelectionPage> createState() =>
      _InterestsSelectionPageState();
}

class _InterestsSelectionPageState
    extends ConsumerState<InterestsSelectionPage> {
  static const int selectionLimit = 5;

  late Map<String, List<InterestOption>> sections;
  String? _completionError;

  @override
  void initState() {
    super.initState();
    sections = {};
  }

  Future<void> _completeRegistration() async {
    try {
      setState(() {
        _completionError = null;
      });

      // Call signup and wait for completion
      await ref
          .read(authProvider.notifier)
          .signUp(
            name: widget.user!.name,
            birthday: widget.user!.birthday!,
            department: widget.user!.department!,
            batch: widget.user!.batch!,
            campus: widget.user!.campus!,
            interests: selectedInterests,
            gender: widget.user!.gender,
            extractedFields: widget.extractedFields,
          );

      logger.i("[$runtimeType] Signup completed successfully");
    } catch (e) {
      logger.e("[$runtimeType] Signup error: $e");
      setState(() {
        _completionError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _handleCompletion() {
    if (widget.completeSignup) {
      _completeRegistration();
    } else {
      Navigator.of(context).pop(selectedInterests);
    }
  }

  void _initializeFromConfig(dynamic config) {
    setState(() {
      sections = {};
      for (var category in config.interests) {
        sections[category.category] = category.data
            .map<InterestOption>(
              (interest) => InterestOption(
                interest: interest,
                selected: widget.initialInterests.any(
                  (initial) => initial.name == interest.name,
                ),
              ),
            )
            .toList();
      }
    });
  }

  int get selectedCount {
    int count = 0;
    for (var section in sections.values) {
      for (var item in section) {
        if (item.selected) count++;
      }
    }
    return count;
  }

  List<Interest> get selectedInterests {
    List<Interest> selected = [];
    for (var section in sections.values) {
      for (var item in section) {
        if (item.selected) {
          selected.add(item.interest);
        }
      }
    }
    return selected;
  }

  void toggleSelection(InterestOption item) {
    setState(() {
      if (item.selected) {
        item.selected = false;
      } else {
        if (selectedCount < selectionLimit) {
          item.selected = true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can select up to $selectionLimit interests.'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  Widget buildChip(InterestOption item) {
    final bool selected = item.selected;
    final Color blue = AppStyle.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => toggleSelection(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? blue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? blue : const Color(0xFFE0E6ED),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                item.name,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF334155),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSection(String title, List<InterestOption> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(children: items.map(buildChip).toList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = AppStyle.primaryBlue;
    final configAsyncValue = ref.watch(backendConfigProvider);
    final authState = ref.watch(authProvider);
    final isAuthLoading = authState.isLoading;
    ref.listen(authProvider, (previous, next) {
      // 1. Handle Success: If we now have a user, clear the signup stack
      if (next is AsyncData && next.value != null) {
        logger.i(
          "[$runtimeType] Signup successful, clearing navigation stack.",
        );
        // This removes all signup screens and reveals the CommunityFeedPage at the root
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // 2. Handle Errors (Your existing code)
      if (next is AsyncError) {
        setState(() {
          _completionError = next.error.toString().replaceAll(
            'Exception: ',
            '',
          );
        });
      }
    });
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // Back Button Row (left aligned)
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppStyle.backButtonLeftPadding,
                            bottom: AppStyle.backButtonBottomPadding,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF323743),
                              size: 30,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                    // Title (left aligned)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppStyle.signUpPageTitleLeftPadding,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Choose Your Interests',
                          style: GoogleFonts.poppins(
                            fontSize: AppStyle.signUpPageHeadingFontSize,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppStyle.signUpPageTitleLeftPadding,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pick up to 5 interests to find people who share your passions.',
                          style: TextStyle(fontSize: 14, color: Colors.black),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    configAsyncValue.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            const Text('Failed to load interests'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  ref.refresh(backendConfigProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (config) {
                        // Initialize sections on first build or when data changes
                        if (sections.isEmpty) {
                          _initializeFromConfig(config);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppStyle.signUpPageTitleLeftPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Progress bar
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: selectedCount / 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: blue,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    '$selectedCount/5 selected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: sections.entries
                                    .map(
                                      (entry) =>
                                          buildSection(entry.key, entry.value),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 5,
                top: 10,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (selectedCount > 0 && !isAuthLoading)
                          ? () {
                              _handleCompletion();
                            }
                          : null,
                      child: isAuthLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  if (_completionError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _completionError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
