import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:calc_flut_rs/generated/rust/frb_generated.dart';

Future<void> initializeRust() async {
  ExternalLibrary? externalLibrary;
  if (Platform.isLinux) {
    final executable = Platform.resolvedExecutable;
    final libPath = path.join(
      path.dirname(executable),
      'lib',
      'libcalc_flut_core.so',
    );
    if (File(libPath).existsSync()) {
      externalLibrary = ExternalLibrary.open(libPath);
    }
  }
  await RustLib.init(externalLibrary: externalLibrary);
}
