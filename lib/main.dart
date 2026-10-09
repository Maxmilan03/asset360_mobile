import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Gallery picks use the system photo picker (no storage permission; backported below Android 13).
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.headerOverlay);
  runApp(const ProviderScope(child: Asset360App()));
}
