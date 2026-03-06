import 'dart:io';

import 'package:icongine/icongine.dart';

Future<void> main(List<String> args) async {
  exitCode = await IcongineCli().run(
    args,
    stdoutWriteln: stdout.writeln,
    stderrWriteln: stderr.writeln,
  );
}
