import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Widget buildLogoAvatarWithFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const CircleAvatar(
      backgroundColor: AppColors.glassFillStrong,
      child: Icon(Icons.business, color: AppColors.textSecondary),
    );
  }
  return CircleAvatar(
    backgroundColor: AppColors.glassFillStrong,
    child: ClipOval(
      child: Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.business, color: AppColors.textSecondary),
      ),
    ),
  );
}
