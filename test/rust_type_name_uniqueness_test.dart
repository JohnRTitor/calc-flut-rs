import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against a silent failure mode in `flutter_rust_bridge` codegen.
///
/// The generator keys every public type it finds by its **bare name**, ignoring
/// the module it came from. So two public types sharing a name anywhere in the
/// crate — a domain struct and the transport struct the bridge declares for it,
/// say — collide. When they do, codegen logs at `info` level and keeps
/// `items_of_key[0]`, discarding the other. Nothing fails, and the generated
/// Dart binds whichever happened to sort first.
///
/// The failure is invisible until runtime, and it looks like a decoding bug
/// rather than a naming mistake, so it is worth catching here instead.
void main() {
  final crateRoot = Directory('rust/src');

  /// Public type declarations in hand-written code.
  ///
  /// Skips generated code, which redeclares everything, and the test modules,
  /// whose helper types are never part of the crate's public surface.
  Map<String, List<String>> publicTypeDeclarations() {
    final found = <String, List<String>>{};

    for (final file in crateRoot.listSync(recursive: true).whereType<File>()) {
      final path = file.path;
      if (!path.endsWith('.rs')) continue;
      if (path.endsWith('frb_generated.rs')) continue;
      if (path.contains('${Platform.pathSeparator}tests${Platform.pathSeparator}')) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = RegExp(
          r'^\s*pub\s+(?:struct|enum)\s+([A-Za-z_][A-Za-z0-9_]*)',
        ).firstMatch(lines[i]);
        if (match == null) continue;
        found.putIfAbsent(match.group(1)!, () => []).add('$path:${i + 1}');
      }
    }

    return found;
  }

  test('the Rust source tree is present to scan', () {
    // A test that silently found nothing would pass for the right reason, which
    // is the failure mode this whole file exists to avoid.
    expect(crateRoot.existsSync(), isTrue, reason: 'run from the package root');
    expect(crateRoot.listSync().whereType<File>().where((f) => f.path.endsWith('.rs')), isNotEmpty);
  });

  test('no two public types share a name', () {
    final duplicates = <String, List<String>>{};
    publicTypeDeclarations().forEach((name, locations) {
      if (locations.length > 1) duplicates[name] = locations;
    });

    expect(
      duplicates,
      isEmpty,
      reason:
          'flutter_rust_bridge keys generated types by bare name, so a duplicate '
          'makes codegen discard one of them at random and only log at info '
          'level. Give one of these a distinct name, or drop the bridge mirror '
          'and mark the domain type #[frb] instead:\n'
          '${duplicates.entries.map((e) => '  ${e.key}: ${e.value.join(", ")}').join("\n")}',
    );
  });

  test('the scan actually finds the types it is meant to guard', () {
    // Guards the guard. If the regex or the file filter stopped matching, the
    // duplicate check would pass vacuously and this is the only thing that
    // would notice.
    final names = publicTypeDeclarations().keys.toSet();

    // A known type from each layer: a domain one and a bridge one.
    expect(names, contains('SymbolicOperation'), reason: 'a domain type');
    expect(names, contains('SymbolicResult'), reason: 'a bridge type');
    expect(names, contains('CalcResult'), reason: 'a pre-existing bridge type');
    expect(names, contains('StructureAnalysis'), reason: 'another bridge type');

    // Generated code must be excluded, or every type would look duplicated.
    expect(names, isNot(contains('RustOpaque')));
  });

  test('the five previously-colliding pairs are now distinct', () {
    // Each of these was a domain type shadowed by a bridge transport type of
    // the same name. They are named apart on purpose; this stops a future
    // rename from quietly reintroducing the collision.
    final names = publicTypeDeclarations();
    for (final domainType in [
      'FormVariant',
      'SolutionCategory',
      'PlotCurve',
      'PlotSample',
      'LimitRange',
    ]) {
      expect(names[domainType], hasLength(1), reason: domainType);
    }
  });
}
