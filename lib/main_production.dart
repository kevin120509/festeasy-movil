import 'package:festeasy/app/app.dart';
import 'package:festeasy/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
