import '../models/person.dart';

abstract final class PersonIds {
  static const rex = 'rex';
  static const ahmed = 'ahmed';
  static const rafi = 'rafi';
  static const ramesh = 'ramesh';
  static const rakesh = 'rakesh';
  static const alex = 'alex';
  static const john = 'john';
  static const suresh = 'suresh';
  static const fatima = 'fatima';
  static const sara = 'sara';
}

List<Person> seedPeople() => const [
  Person(
    id: PersonIds.rex,
    name: 'Rex Kumar',
    role: 'DCS',
    department: 'Operations Control',
    phone: '+971 50 123 4567',
  ),
  Person(
    id: PersonIds.ahmed,
    name: 'Ahmed Ali',
    role: 'Operations',
    department: 'Operations',
    phone: '+971 50 234 5678',
  ),
  Person(
    id: PersonIds.rafi,
    name: 'Mohammed Rafi',
    role: 'Maintenance Technician',
    department: 'Maintenance',
    phone: '+971 50 345 6789',
  ),
  Person(
    id: PersonIds.ramesh,
    name: 'Ramesh Kumar',
    role: 'Production',
    department: 'Production',
    phone: '+971 50 456 7890',
  ),
  Person(
    id: PersonIds.rakesh,
    name: 'Rakesh Kumar',
    role: 'Warehouse Operator',
    department: 'Warehouse',
    phone: '+971 50 567 8901',
  ),
  Person(
    id: PersonIds.alex,
    name: 'Alex Mathew',
    role: 'AOI Operator',
    department: 'Production',
    phone: '+971 50 678 9012',
  ),
  Person(
    id: PersonIds.john,
    name: 'John Smith',
    role: 'Production Supervisor',
    department: 'Production',
    phone: '+971 50 789 0123',
  ),
  Person(
    id: PersonIds.suresh,
    name: 'Suresh Kumar',
    role: 'Warehouse',
    department: 'Warehouse',
    phone: '+971 50 890 1234',
  ),
  Person(id: PersonIds.fatima, name: 'Fatima Noor', role: 'IT', department: 'IT', phone: '+971 50 901 2345'),
  Person(id: PersonIds.sara, name: 'Sara Khan', role: 'Finance', department: 'Finance', phone: '+971 50 012 3456'),
];

const mockSites = ['All Sites', 'Dubai Factory', 'Dubai Office', 'Education City'];

const mockUsername = 'rex.kumar';
const mockEmail = 'rex.kumar@purpleiq.ae';
const mockPassword = 'Asset@360';
const mockAuthenticatorCode = '123456';
const mockBackupCode = '1234-5678';
