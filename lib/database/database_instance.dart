import 'package:isar_community/isar.dart';

/// Process-wide Isar handle initialized during application bootstrap.
///
/// Keeping the database handle in the data layer prevents repositories and
/// models from importing the application entry point. Tests can also replace
/// this handle after opening an isolated Isar instance.
late Isar isar;
