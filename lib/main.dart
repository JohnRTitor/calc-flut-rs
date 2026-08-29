import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/app/app.dart';
import 'package:flutter/services.dart';
import 'package:calc_flut_rs/init/rust_init.dart';

/// The main entry point for the Calculator application.
///
/// Initializes Flutter bindings, sets up Edge-to-Edge UI, loads the Rust library
/// via flutter_rust_bridge, and starts the app wrapped in a Riverpod ProviderScope.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await initializeRust();

  runApp(const ProviderScope(child: CalculatorApp()));
}
