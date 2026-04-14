import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/repositories/backend_config.dart';

final backendConfigProvider = FutureProvider<BackendConfig>((ref) async {
  final repository = BackendConfigRepository();
  return repository.fetchConfig();
});
