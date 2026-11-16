import 'package:uuid/uuid.dart';

class Ids {
  const Ids();

  String next() => const Uuid().v4();
}
