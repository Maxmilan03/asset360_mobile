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

  /// Opens the system NFC settings (Android). Returns false when the platform can't open them.
  static Future<bool> openNfcSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNfcSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens [url] in the app that handles it (mailto: → the email app). Returns false when none can.
  static Future<bool> openUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// "Zebra TC52 · Android 11" (Android) / "Apple iPhone15,2 · iOS 17.5" (iOS), or null.
  static Future<String?> deviceInfo() async {
    try {
      return await _channel.invokeMethod<String>('deviceInfo');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
