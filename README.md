# Flutter Rust Calculator

A modern, production-quality Android calculator application built with a **Flutter** UI and a **Rust** calculation engine.

## Features

- **Native Material Design 3 UI**: Uses `dynamic_color` for full Android 12+ Material You theming and edge-to-edge transparent system bars.
- **Rust Core**: A fully custom-built recursive descent parser handles all mathematical evaluations efficiently on a background thread.
- **Scientific Mode**: Easily switch between standard keypad and a full scientific interface (`sin`, `cos`, `tan`, `log`, `ln`, `sqrt`, `^`, `!`).
- **History & Memory**: Persistent on-disk calculation history and full memory functionality (`MC`, `MR`, `M+`, `M-`, `MS`).
- **Offline First**: Zero external runtime dependencies for mathematical evaluations.

## Development

This project was built using `flutter_rust_bridge` and `riverpod`.

To run the application locally:

```bash
flutter run
```

If you modify the Rust core (`rust/src/`), you **must** regenerate the Dart FFI bindings before running the app. You can do this by running:

```bash
dart run build_runner build -d
```

To cross-compile the release Android APK:

```bash
flutter build apk --release
```

### App Icons

The custom app icons are generated using the `flutter_launcher_icons` package. If you want to modify the icon, edit the vector `assets/calculator_icon.svg`, rasterize it to a high-resolution PNG (`assets/calculator_icon.png`), and run the generation command:

```bash
flutter pub run flutter_launcher_icons
```

## WebAssembly (WASM) Support

To run the application on the web browser, you must compile the Rust backend to WebAssembly before starting the Flutter app:

```bash
flutter_rust_bridge_codegen build-web
flutter run -d chrome
```

**Note:**
`flutter_rust_bridge_codegen build-web` optimizes the WebAssembly file size using `-Z build-std=std,panic_abort`, which is normally a Nightly Rust feature. Make sure you use a Rust Nightly toolchain or set `RUSTC_BOOTSTRAP=1` in the environment so that these nightly features can be used with the stable Rust compiler without errors.

Or you can build it manually.

```bash
wasm-pack build -t no-modules -d web/pkg --no-typescript --out-name rust_lib_calc_flut_rs --dev rust
```

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
