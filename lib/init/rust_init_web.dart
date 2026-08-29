import 'package:calc_flut_rs/generated/rust/frb_generated.dart';

Future<void> initializeRust() async {
  await RustLib.init();
}
