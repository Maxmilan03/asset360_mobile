import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/people_mock.dart';
import 'package:asset360_mobile/data/models/person.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

class PeopleNotifier extends Notifier<List<Person>> {
  @override
  List<Person> build() => seedPeople();

  void update(Person p) => state = replaceWhere(state, p.id, (x) => x.id, (_) => p);
}

final peopleProvider = NotifierProvider<PeopleNotifier, List<Person>>(PeopleNotifier.new);

final personByIdProvider = Provider.family<Person?, String?>((ref, id) {
  if (id == null) return null;
  return ref.watch(peopleProvider).firstWhereOrNull((p) => p.id == id);
});

enum CodeResult { ok, wrong, locked }

class SessionState {
  const SessionState({
    required this.userId,
    required this.email,
    required this.password,
    required this.site,
    required this.loggedIn,
    this.passwordVerified = false,
    this.rememberMe = true,
    this.failedLogins = 0,
    this.lockedUntil,
    this.failedCodes = 0,
    this.notice,
    this.photoPath,
  });

  final String userId;
  final String email;
  final String password;
  final String site;

  /// Fully signed in (password + authenticator code).
  final bool loggedIn;

  /// Step 1 passed; the Authenticator screen may be shown.
  final bool passwordVerified;
  final bool rememberMe;
  final int failedLogins;

  /// Sign-in is blocked until this time after 5 wrong passwords.
  final DateTime? lockedUntil;
  final int failedCodes;

  /// One-time message for the Login screen (e.g. after too many wrong codes).
  final String? notice;
  final String? photoPath;

  static const maxAttempts = 5;
  static const lockDuration = Duration(seconds: 30);

  int get codeAttemptsLeft => maxAttempts - failedCodes;

  SessionState copyWith({
    String? email,
    String? password,
    String? site,
    bool? loggedIn,
    bool? passwordVerified,
    bool? rememberMe,
    int? failedLogins,
    DateTime? Function()? lockedUntil,
    int? failedCodes,
    String? Function()? notice,
    String? photoPath,
  }) => SessionState(
    userId: userId,
    email: email ?? this.email,
    password: password ?? this.password,
    site: site ?? this.site,
    loggedIn: loggedIn ?? this.loggedIn,
    passwordVerified: passwordVerified ?? this.passwordVerified,
    rememberMe: rememberMe ?? this.rememberMe,
    failedLogins: failedLogins ?? this.failedLogins,
    lockedUntil: lockedUntil == null ? this.lockedUntil : lockedUntil(),
    failedCodes: failedCodes ?? this.failedCodes,
    notice: notice == null ? this.notice : notice(),
    photoPath: photoPath ?? this.photoPath,
  );
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState(
    userId: PersonIds.rex,
    email: mockEmail,
    password: mockPassword,
    site: mockSites.first,
    loggedIn: false,
  );

  /// Remaining lock time, or null when sign-in is allowed.
  Duration? get lockRemaining {
    final until = state.lockedUntil;
    if (until == null) return null;
    final left = until.difference(DemoClock.now);
    return left.isNegative ? null : left;
  }

  /// Step 1: username or email + password. Counts failures and locks after 5.
  bool signIn(String login, String password, {required bool rememberMe}) {
    if (lockRemaining != null) return false;
    final l = login.trim().toLowerCase();
    final ok = (l == mockUsername || l == state.email.toLowerCase()) && password == state.password;
    if (ok) {
      state = state.copyWith(
        passwordVerified: true,
        rememberMe: rememberMe,
        failedLogins: 0,
        lockedUntil: () => null,
        failedCodes: 0,
      );
    } else {
      final fails = state.failedLogins + 1;
      state = state.copyWith(
        failedLogins: fails >= SessionState.maxAttempts ? 0 : fails,
        lockedUntil: fails >= SessionState.maxAttempts ? () => DemoClock.now.add(SessionState.lockDuration) : null,
      );
    }
    return ok;
  }

  /// Returns and clears the one-time Login message.
  String? takeNotice() {
    final n = state.notice;
    if (n != null) state = state.copyWith(notice: () => null);
    return n;
  }

  /// Ends the 30-second lock (called when the Login countdown reaches zero).
  void clearLock() => state = state.copyWith(lockedUntil: () => null, failedLogins: 0);

  /// Google / Microsoft (simulated): counts as step 1.
  void signInWithProvider() => state = state.copyWith(passwordVerified: true, failedCodes: 0);

  /// Step 2: authenticator (or email / backup) code.
  CodeResult verifyCode(String code) {
    if (code == mockAuthenticatorCode) {
      state = state.copyWith(loggedIn: true, passwordVerified: false, failedCodes: 0);
      return CodeResult.ok;
    }
    final fails = state.failedCodes + 1;
    if (fails >= SessionState.maxAttempts) {
      state = state.copyWith(
        passwordVerified: false,
        failedCodes: 0,
        notice: () => 'Too many invalid codes. Please sign in again.',
      );
      return CodeResult.locked;
    }
    state = state.copyWith(failedCodes: fails);
    return CodeResult.wrong;
  }

  /// "Use a backup code" (demo code 1234-5678).
  bool useBackupCode(String code) {
    final ok = code.replaceAll(RegExp(r'[\s-]'), '') == mockBackupCode.replaceAll('-', '');
    if (ok) state = state.copyWith(loggedIn: true, passwordVerified: false, failedCodes: 0);
    return ok;
  }

  /// Leaves the Authenticator step and returns to Login.
  void cancelSecondFactor() => state = state.copyWith(passwordVerified: false, failedCodes: 0);

  void logout() => state = state.copyWith(loggedIn: false, passwordVerified: false);
  void switchSite(String site) => state = state.copyWith(site: site);
  void changePassword(String password) => state = state.copyWith(password: password);
  void setPhoto(String path) => state = state.copyWith(photoPath: path);

  void updateProfile({String? name, String? phone}) {
    final me = ref.read(peopleProvider).firstWhere((p) => p.id == state.userId);
    ref.read(peopleProvider.notifier).update(me.copyWith(name: name, phone: phone));
  }
}

/// "r***@purpleiq.ae".
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 1) return email;
  return '${email[0]}***${email.substring(at)}';
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

final currentUserProvider = Provider<AppUser>((ref) {
  final s = ref.watch(sessionProvider);
  final person = ref.watch(peopleProvider).firstWhere((p) => p.id == s.userId);
  return AppUser(
    person: person,
    username: mockUsername,
    email: s.email,
    password: s.password,
    authenticatorCode: mockAuthenticatorCode,
    photoPath: s.photoPath,
  );
});

final sitesProvider = Provider<List<String>>((ref) => mockSites);
