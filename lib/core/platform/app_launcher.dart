import 'package:flutter/services.dart';

/// Opens other apps through a small platform channel (MainActivity.kt / AppDelegate.swift).
abstract final class AppLauncher {
  static const _channel = MethodChannel('com.purpleiq.asset360/apps');

  /// Tries to open Google Authenticator. Returns false when it isn't installed
  /// or the platform can't open it.
  static Future<bool> openAuthenticator() async {
    try {
      return await _channel.invokeMethod<bool>('openAuthenticator') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens this app's page in the system Settings (e.g. to allow the camera).
  /// Returns false when the platform can't open it.
  static Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
