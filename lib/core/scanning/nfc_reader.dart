import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'package:asset360_mobile/core/scanning/scan_event.dart';

enum NfcState { enabled, disabled, unsupported }

/// Why a read ended without a tag.
enum NfcFailure { unsupported, disabled, timeout, cancelled, error }

class NfcReadException implements Exception {
  const NfcReadException(this.failure, [this.message]);

  final NfcFailure failure;
  final String? message;

  @override
  String toString() => 'NfcReadException($failure, $message)';
}

/// Reads one NFC tag of any kind. Tests replace it through [nfcReaderProvider].
abstract class NfcReader {
  Future<NfcState> availability();

  /// Starts a session and completes with the first tag (UID + every NDEF record), or throws
  /// [NfcReadException].
  Future<ScanEvent> readOnce({Duration timeout});

  Future<void> cancel();
}

/// nfc_manager 4: Android reader mode / iOS NFCTagReaderSession.
class PlatformNfcReader implements NfcReader {
  Completer<ScanEvent>? _pending;

  bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<NfcState> availability() async {
    if (!_mobile) return NfcState.unsupported;
    try {
      return switch (await NfcManager.instance.checkAvailability()) {
        NfcAvailability.enabled => NfcState.enabled,
        NfcAvailability.disabled => NfcState.disabled,
        NfcAvailability.unsupported => NfcState.unsupported,
      };
    } catch (_) {
      return NfcState.unsupported;
    }
  }

  @override
  Future<ScanEvent> readOnce({Duration timeout = const Duration(seconds: 30)}) async {
    switch (await availability()) {
      case NfcState.unsupported:
        throw const NfcReadException(NfcFailure.unsupported);
      case NfcState.disabled:
        throw const NfcReadException(NfcFailure.disabled);
      case NfcState.enabled:
        break;
    }
    await cancel();
    final done = _pending = Completer<ScanEvent>();
    try {
      await NfcManager.instance.startSession(
        // ISO 18092 (FeliCa) on iOS needs system codes in Info.plist, so iOS polls the other two.
        pollingOptions: Platform.isIOS
            ? {NfcPollingOption.iso14443, NfcPollingOption.iso15693}
            : {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        alertMessageIos: 'Hold your iPhone near the tag',
        onDiscovered: (tag) {
          if (done.isCompleted) return;
          try {
            done.complete(eventFromTag(tag));
            NfcManager.instance.stopSession(alertMessageIos: 'Tag read').ignore();
          } catch (e) {
            done.completeError(NfcReadException(NfcFailure.error, '$e'));
            NfcManager.instance.stopSession(errorMessageIos: 'Could not read this tag').ignore();
          }
        },
        onSessionErrorIos: (e) {
          if (done.isCompleted) return;
          final cancelled = e.code == NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled;
          final timedOut = e.code == NfcReaderErrorCodeIos.readerSessionInvalidationErrorSessionTimeout;
          done.completeError(
            NfcReadException(
              cancelled
                  ? NfcFailure.cancelled
                  : timedOut
                  ? NfcFailure.timeout
                  : NfcFailure.error,
              e.message,
            ),
          );
        },
      );
    } catch (e) {
      _pending = null;
      throw NfcReadException(NfcFailure.error, '$e');
    }
    try {
      return await done.future.timeout(timeout);
    } on TimeoutException {
      await cancel();
      throw const NfcReadException(NfcFailure.timeout);
    } finally {
      if (identical(_pending, done)) _pending = null;
    }
  }

  @override
  Future<void> cancel() async {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.completeError(const NfcReadException(NfcFailure.cancelled));
    if (!_mobile) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // No session running.
    }
  }

  /// UID and NDEF records of [tag] (Android or iOS).
  static ScanEvent eventFromTag(NfcTag tag) {
    List<int>? uid;
    NdefMessage? message;
    if (Platform.isAndroid) {
      uid = NfcTagAndroid.from(tag)?.id;
      message = NdefAndroid.from(tag)?.cachedNdefMessage;
    } else {
      uid =
          MiFareIos.from(tag)?.identifier ??
          Iso15693Ios.from(tag)?.identifier ??
          Iso7816Ios.from(tag)?.identifier ??
          FeliCaIos.from(tag)?.currentIDm;
      message = NdefIos.from(tag)?.cachedNdefMessage;
    }
    final uidText = uid == null || uid.isEmpty ? 'UNKNOWN' : formatUid(uid);
    final records = [
      for (final r in message?.records ?? const <NdefRecord>[])
        decodeNdefRecord(tnf: r.typeNameFormat.index, type: r.type, payload: r.payload),
    ];
    return ScanEvent(
      value: nfcValue(uidText, records),
      format: 'nfc',
      source: ScanSource.nfc,
      nfcUid: uidText,
      nfcRecords: records,
    );
  }
}

final nfcReaderProvider = Provider<NfcReader>((ref) {
  final r = PlatformNfcReader();
  ref.onDispose(r.cancel);
  return r;
});
