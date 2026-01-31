import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Widget buildLogoAvatarWithFile(String path) {
  return const CircleAvatar(
    backgroundColor: AppColors.glassFillStrong,
    child: Icon(Icons.business, color: AppColors.textSecondary),
  );
}
