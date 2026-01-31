import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'logo_avatar_stub.dart' if (dart.library.io) 'logo_avatar_io.dart' as _impl;

Widget buildLogoAvatar(String? logoPath) {
  if (logoPath == null || logoPath.isEmpty || logoPath == 'No disponible') {
    return const CircleAvatar(
      backgroundColor: AppColors.glassFillStrong,
      child: Icon(Icons.business, color: AppColors.textSecondary),
    );
  }
  return _impl.buildLogoAvatarWithFile(logoPath);
}
