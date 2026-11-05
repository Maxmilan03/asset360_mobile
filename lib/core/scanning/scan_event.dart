import 'dart:convert';
import 'dart:typed_data';

import 'package:asset360_mobile/data/db/app_database.dart';

export 'package:asset360_mobile/data/db/app_database.dart' show ScanSource, MatchType, TagType, LinkTarget;

/// One code read by the camera, an NFC tag, the HHT scanner or Manual Entry.
class ScanEvent {
  const ScanEvent({required this.value, required this.format, required this.source, this.nfcUid, this.nfcRecords});

  /// Raw text: the barcode / QR value, the first NDEF text / URI record, or "NFC:" + UID.
  final String value;

  /// qr, code128, ean13, datamatrix, nfc, manual …
  final String format;
  final ScanSource source;

  /// "04:A2:3B:…" (upper-case hex, colon separated).
  final String? nfcUid;
  final List<NdefRecordInfo>? nfcRecords;

  bool get isNfc => source == ScanSource.nfc || nfcUid != null;

  /// The key a [TagLink] uses for this tag: "NFC:" + UID for NFC tags, else the value.
  String get tagKey => nfcUid != null ? nfcTagKey(nfcUid!) : value.trim();

  TagType get tagType => isNfc
      ? TagType.nfc
      : format == 'qr'
      ? TagType.qr
      : TagType.barcode;
}

String nfcTagKey(String uid) => 'NFC:$uid';

/// "04A23B" bytes → "04:A2:3B".
String formatUid(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

/// What ScanService found for a [ScanEvent] (the row is already saved in ScanLog).
class ScanResult {
  const ScanResult({
    required this.event,
    required this.matchType,
    this.matchId,
    this.matchLabel,
    this.location,
    this.logId,
    this.viaLink = false,
    this.problem,
    this.candidates = const [],
  });

  final ScanEvent event;
  final MatchType matchType;

  /// Asset ID, part number or location code.
  final String? matchId;
  final String? matchLabel;
  final DbLocation? location;

  /// The ScanLog row.
  final int? logId;

  /// Resolved through a TagLinks row.
  final bool viaLink;

  /// API mode: why the code could not be resolved although it may be registered (the server's
  /// "matches more than one asset" message, or a connection error). [matchType] is then none.
  final String? problem;

  /// API mode: the assetRegistrationIds a 409 named.
  final List<String> candidates;

  bool get isKnown => matchType != MatchType.none;
}

// ---------------------------------------------------------------- NDEF

enum NdefKind { text, uri, mime, external, empty, unknown }

/// One decoded NDEF record, stored as JSON in ScanLog.nfcRecords.
class NdefRecordInfo {
  const NdefRecordInfo({required this.kind, required this.type, required this.value, this.language});

  final NdefKind kind;

  /// "T", "U", "application/json", "android.com:pkg" …
  final String type;

  /// The text, the full URI, the MIME payload as text, or the payload as hex.
  final String value;
  final String? language;

  String get title => switch (kind) {
    NdefKind.text => 'Text${language == null ? '' : ' ($language)'}',
    NdefKind.uri => 'URI',
    NdefKind.mime => 'MIME · $type',
    NdefKind.external => 'External · $type',
    NdefKind.empty => 'Empty record',
    NdefKind.unknown => 'Unknown${type.isEmpty ? '' : ' · $type'} (hex)',
  };

  Map<String, Object?> toJson() => {'kind': kind.name, 'type': type, 'value': value, 'lang': ?language};

  factory NdefRecordInfo.fromJson(Map<String, Object?> j) => NdefRecordInfo(
    kind: NdefKind.values.asNameMap()[j['kind']] ?? NdefKind.unknown,
    type: j['type'] as String? ?? '',
    value: j['value'] as String? ?? '',
    language: j['lang'] as String?,
  );

  static String encodeList(List<NdefRecordInfo> records) => jsonEncode([for (final r in records) r.toJson()]);

  static List<NdefRecordInfo> decodeList(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return [for (final r in jsonDecode(json) as List) NdefRecordInfo.fromJson((r as Map).cast<String, Object?>())];
    } catch (_) {
      return const [];
    }
  }
}

/// URI identifier codes (NFC Forum URI RTD).
const _uriPrefixes = [
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
  'ftp://anonymous:anonymous@',
  'ftp://ftp.',
  'ftps://',
  'sftp://',
  'smb://',
  'nfs://',
  'ftp://',
  'dav://',
  'news:',
  'telnet://',
  'imap:',
  'rtsp://',
  'urn:',
  'pop:',
  'sip:',
  'sips:',
  'tftp:',
  'btspp://',
  'btl2cap://',
  'btgoep://',
  'tcpobex://',
  'irdaobex://',
  'file://',
  'urn:epc:id:',
  'urn:epc:tag:',
  'urn:epc:pat:',
  'urn:epc:raw:',
  'urn:epc:',
  'urn:nfc:',
];

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

String _utf8(List<int> b) => utf8.decode(b, allowMalformed: true);

/// Decodes one record. [tnf] is the Type Name Format (0 empty, 1 well-known, 2 MIME, 3 absolute URI,
/// 4 external, 5 unknown, 6 unchanged).
NdefRecordInfo decodeNdefRecord({required int tnf, required Uint8List type, required Uint8List payload}) {
  final t = _utf8(type);
  switch (tnf) {
    case 0:
      return const NdefRecordInfo(kind: NdefKind.empty, type: '', value: '');
    case 1 when t == 'T' && payload.isNotEmpty:
      final status = payload[0];
      final langLen = status & 0x3F;
      final utf16 = status & 0x80 != 0;
      if (1 + langLen > payload.length) break;
      final lang = ascii.decode(payload.sublist(1, 1 + langLen), allowInvalid: true);
      final body = payload.sublist(1 + langLen);
      final text = utf16 ? _utf16(body) : _utf8(body);
      return NdefRecordInfo(kind: NdefKind.text, type: 'T', value: text, language: lang.isEmpty ? null : lang);
    case 1 when t == 'U' && payload.isNotEmpty:
      final prefix = payload[0] < _uriPrefixes.length ? _uriPrefixes[payload[0]] : '';
      return NdefRecordInfo(kind: NdefKind.uri, type: 'U', value: prefix + _utf8(payload.sublist(1)));
    case 2:
      final textual = t.startsWith('text/') || t.contains('json') || t.contains('xml') || t.endsWith('+json');
      return NdefRecordInfo(kind: NdefKind.mime, type: t, value: textual ? _utf8(payload) : _hex(payload));
    case 3:
      return NdefRecordInfo(kind: NdefKind.uri, type: 'absolute-uri', value: t);
    case 4:
      return NdefRecordInfo(kind: NdefKind.external, type: t, value: _printable(payload) ?? _hex(payload));
  }
  return NdefRecordInfo(kind: NdefKind.unknown, type: t, value: _hex(payload));
}

String _utf16(List<int> b) {
  var bytes = b;
  var bigEndian = true;
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    bigEndian = false;
    bytes = bytes.sublist(2);
  } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    bytes = bytes.sublist(2);
  }
  final units = [
    for (var i = 0; i + 1 < bytes.length; i += 2)
      bigEndian ? (bytes[i] << 8) | bytes[i + 1] : (bytes[i + 1] << 8) | bytes[i],
  ];
  return String.fromCharCodes(units);
}

/// The payload as text when it is printable UTF-8.
String? _printable(List<int> b) {
  final s = _utf8(b);
  return s.contains('�') || s.runes.any((r) => r < 0x20 && r != 0x0A && r != 0x0D && r != 0x09) ? null : s;
}

/// The scan value for an NFC tag: the first text / URI record, else "NFC:" + UID.
String nfcValue(String uid, List<NdefRecordInfo> records) {
  for (final r in records) {
    if ((r.kind == NdefKind.text || r.kind == NdefKind.uri) && r.value.trim().isNotEmpty) return r.value.trim();
  }
  return nfcTagKey(uid);
}
