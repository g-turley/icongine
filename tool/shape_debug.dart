import 'dart:io';

import 'package:icongine/icongine.dart';

void main(List<String> args) {
  exitCode = const ShapeDebugCommand().run(
    args,
    stdoutWriteln: stdout.writeln,
    stderrWriteln: stderr.writeln,
  );
}
