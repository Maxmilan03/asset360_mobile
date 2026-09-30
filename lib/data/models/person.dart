class Person {
  const Person({required this.id, required this.name, required this.role, this.department, this.phone});

  final String id;
  final String name;
  final String role;
  final String? department;
  final String? phone;

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  String get firstName => name.split(' ').first;

  /// "Mohammed Rafi (Maintenance Technician)".
  String get labelWithRole => '$name ($role)';

  Person copyWith({String? name, String? role, String? department, String? phone}) => Person(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    department: department ?? this.department,
    phone: phone ?? this.phone,
  );
}

/// The signed-in user: a [Person] plus account details.
class AppUser {
  const AppUser({
    required this.person,
    required this.username,
    required this.email,
    required this.password,
    required this.authenticatorCode,
    this.photoPath,
  });

  final Person person;
  final String username;
  final String email;
  final String password;
  final String authenticatorCode;
  final String? photoPath;

  String get id => person.id;
  String get name => person.name;
  String get role => person.role;
  String get initials => person.initials;
  String get firstName => person.firstName;

  AppUser copyWith({Person? person, String? email, String? password, String? photoPath}) => AppUser(
    person: person ?? this.person,
    username: username,
    email: email ?? this.email,
    password: password ?? this.password,
    authenticatorCode: authenticatorCode,
    photoPath: photoPath ?? this.photoPath,
  );
}
