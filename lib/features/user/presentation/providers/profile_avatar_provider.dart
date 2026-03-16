import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';

final profileAvatarUrlProvider = FutureProvider.family<String?, String>((
  ref,
  avatarPath,
) async {
  final trimmedPath = avatarPath.trim();
  if (trimmedPath.isEmpty) {
    return null;
  }

  try {
    final client = ref.watch(supabaseClientProvider);
    return await client.storage
        .from('avatars')
        .createSignedUrl(trimmedPath, 60 * 60);
  } catch (_) {
    return null;
  }
});
