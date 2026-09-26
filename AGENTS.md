# AGENTS.md — AI Collaboration Guide

Flutter + Rust calculator. `flutter_rust_bridge` (FRB) bridge, Riverpod, dual
theme (Material + Liquid Glass). Targets Android, iOS, Web, Windows, macOS, Linux.

**Principle: correctness over convenience.** This file is authoritative over
framework defaults and model assumptions. Search before creating; prefer
extending an existing abstraction to adding a parallel one; make the smallest
change that solves the problem.

---

## Non-Negotiables

**Do not**

- Edit generated files (`lib/generated/`, `*.g.dart`).
- Move mathematical computation into Flutter.
- Introduce a second state-management solution, or a parallel UI system.
- Introduce a temporary fix when a root-cause fix is possible.
- Hardcode colors.
- Create Material-only components.

**Correctness** (a slower correct result beats a faster wrong one)

- Never silently lose precision, overflow, truncate, or approximate.
- Return an explicit error instead of an incorrect result.
- Never use `f32`. Avoid `f64` except for FRB output formatting and trig where
  exact representation is impossible.
- Never use `i32`/`i64` for intermediates. `i128` minimum, `BigInt` preferred.
- Never `unwrap()`, `expect()`, or `panic!()` outside tests.
- Prefer exact arithmetic, in this order: `BigInt` → `BigRational` →
  `BigDecimal` → primitives only when unavoidable.

**Boundary**

| Flutter | Rust |
| --- | --- |
| UI, state management, user interaction, presentation | Mathematical evaluation, number theory, arbitrary precision, parsing, domain logic |

**Reuse first.** Before creating a widget, dialog, dropdown, provider,
evaluator, parser, error type, or history system, search:

- `lib/shared/widgets/`, `lib/shared/`, `lib/app/navigation/`
- `rust/src/shared/`
- existing feature implementations

---

## Commands

```bash
# after editing rust/src/bridge/
flutter_rust_bridge_codegen generate

# after editing any @riverpod provider
dart run build_runner build --delete-conflicting-outputs

# validate
flutter analyze
flutter test
cd rust && cargo test && cargo clippy
```

---

## Architecture

### Layout

Read the real structure with `ls lib/`, `ls rust/src/` — do not trust a tree
copied into these docs. The rules that matter:

- Feature modules live in `lib/features/<feature>/`, each `data/` (repositories,
  data sources) · `domain/` (entities, use cases) ·
  `presentation/{screens,providers,widgets,state}`. Do not create empty layers —
  add them when the feature actually has that logic. Most features so far need
  only `presentation/`.
- Reusable dual-theme UI goes in `lib/shared/widgets/`; responsive helpers in
  `lib/shared/layouts/`.
- App-level (not feature-level) state goes in `lib/app/providers/`.
- Keep modules small and single-purpose; split a file past ~300 lines. Shared
  logic belongs in `shared/`, not duplicated between features.

### Navigation

`lib/app/navigation/tool_registry.dart` is the single source of truth. The
drawer, rail, hub grids and search all read `appSections`; never duplicate a
tool list. Adding a tool is a one-line registry edit.

`AppShell` picks its layout from the shared `AppBreakpoints`:

| Width | Layout |
| --- | --- |
| `< 600` | Hamburger + modal drawer |
| `600–840` | Persistent icon-only rail |
| `> 840` | Extended rail (icon + label) |

Sections are hosted in an `IndexedStack` (not `TabBarView`) so each keeps its
own scroll position and state. The last-selected section is persisted.

Two patterns **inside** a section — choose by tool count, not by feature:

| Pattern | Use when |
| --- | --- |
| **Hub Grid** — `AppHubGrid` of `SharedSurface` cards → `Navigator.push` | 5+ loosely related tools, or a family that keeps growing |
| **Segmented** — `PillSwitcher` (2) / `MultiPillSwitcher` (3+) swapping inline | 2–4 tightly coupled modes sharing one layout |

To add a section or tool:

1. Add an `AppSection` to `tool_registry.dart`; put tools in its `tools` list.
2. For a hub section, its screen renders `AppHubGrid` from
   `appHubItemsForTools(context, ref, section.tools)`.
3. Pushed screens get `Scaffold` + `AppBar` whose title matches the hub card label.
4. Do not touch `AppShell`.

`AppTool.open()` is the only way to launch a tool: it runs `onPrepare` (provider
seeding), pushes with `FadePageRoute`, or shows a "Coming Soon" notice when
`isAvailable: false`.

**Screens that are both a section and a pushed destination** (`HistoryScreen`,
`SettingsScreen`) take an `embedded` flag. The shell already renders the section
title, so an unconditional app bar duplicates it:

- `embedded: true` — no app bar; the shell owns the title and back action.
- `embedded: false` (default) — full `Scaffold` + `AppBar` with a back action.

Any app bar action must be reachable in **both** modes.

---

## Rust Rules

**Errors** — use `Result<T, CalcError>` (calculator), `Result<T, ModError>`
(modular), `Result<T, SymbolicError>` (symbolic), `Result<T, CommonError>`
(shared), `Result<T, String>` only at the FRB boundary. Convert at the bridge
with `.map_err(|e| e.to_string())`.

Four error enums, each with `From<CommonError>`: `CommonError`
(`shared/error.rs`), `CalcError` (`calculator/error.rs`), `ModError`
(`modular_arithmetic/error.rs`), `SymbolicError` (`symbolic/error.rs`). Add a
variant to the most specific one; if it is shared, add to `CommonError` and
update the `From` impls.

**Domains are siblings, not layers.** `calculator/` is the real-number fast
path, `modular_arithmetic/` is ring/field analysis, and `symbolic/` is
computer algebra. They share `shared/`, nothing else. Do not fold symbolic
concerns into `calculator/evaluator/` or widen its `Evaluator` trait — that path
stays synchronous and keypress-latency sensitive.

`symbolic/` is backed by the `symplex` crate, which keeps exact
`Ratio<BigInt>` arithmetic end to end; never route a symbolic result through
`f64`. Expression handles are bound to the `Context` that created them and the
backend panics when handles from two contexts meet, so take variable *names*
across a boundary rather than handles.

`modular_arithmetic/mod_arith.rs` is backed by `num-modular`, whose algorithms
are exact and whose API is deliberately not what this app needs. The module owns
four contracts, all observable, and all pinned by `tests/modular_kernel_tests.rs`:

- **Zero modulus.** `num-modular` panics on it, and the release profile is
  `panic = "abort"`, so an unguarded call is a process kill on Android. The ring
  helpers pass their operands through unreduced; `mod_pow` and `mod_inv` return
  an error. Callers rely on getting their own message about `mod 0`.
- **Negative modulus.** The workspace's modulus is a free-text field, so `-7`
  is reachable. It names the ring of its magnitude, i.e. `rem_euclid(|n|)`.
- **Signedness.** `num-modular` is unsigned-only and `ModularInteger` cannot
  represent a signed operand. Keep the `i128` API and normalise through
  `residue()`. Do not adopt `ModularInteger` here: the evaluator has no fixed
  modulus to hoist, and its per-node `Option<i128>` modulus makes the type
  safety decorative.
- **Integer width.** `mod_pow` narrows to `u64` only when the modulus *and* the
  exponent both fit. Narrowing a wide exponent drops its high bits and turns
  `2^(2^100)` into `2^0`. This is roughly a 2× difference on the calculator's
  keypress preview, so it is not optional.

Do not hand-roll a modular multiply. Two reduced operands below `n` need `n²` of
room, so the product belongs in a double-width intermediate, which is what
`mulm` gives you. Multiplying in the operand type instead wraps for any modulus
above about `2^63.5` — silently, because the release profile compiles with
overflow checks off.

**Verify the backend's answers, do not relay them — but only where the check
is sound.** `symplex` reports "I cannot do this" by returning the request
unevaluated, and its solver reaches answers by rearranging the equation — which
admits roots that satisfy the rearranged form but not the original
(`sqrt(x) = -1` yields `x = 1`). Both are handled in `symbolic/`:
`has_unevaluated()` turns the first into an explicit refusal, and every solved
candidate is substituted back and kept only if its residual simplifies to
exactly zero. Never surface a result you have not checked.

The same residual gate must **not** be applied to indefinite integrals. Their
answers are frequently correct while `simplify` cannot prove it: differentiating
`ln(abs(x))` or `-ln(abs(cos(x)))` introduces `sign`/`abs` pairs that do not
reduce, so the check reports false negatives and would reject correct
mathematics. Integration is gated on `has_unevaluated()` alone. If simplification
ever closes that loop, a test asserting the current false negative
(`test_simplification_cannot_always_verify_a_good_answer`) will fail and prompt
the question again.

**Overflow** — never wrap, saturate, or truncate. Factorial accumulates `BigInt`
(`Expr::Factorial`). Modular exponentiation uses `mod_pow()`, which square-and-
multiplies through a double-width intermediate. If a value cannot be computed,
return a descriptive error.

**Adding a mathematical domain**

1. New module under `rust/src/`.
2. Domain-specific parser, evaluator, error type.
3. Bridge functions in `rust/src/bridge/`.
4. `history_bridge!()` if it needs history.
5. Register in `lib.rs`.
6. `flutter_rust_bridge_codegen generate`.
7. Tests in `rust/src/tests/`.

`history_bridge!` (`rust/src/shared/history.rs`) generates the FRB history CRUD
functions for any `HistoryManager` — use it instead of writing bridge CRUD by
hand.

**Evaluators** implement the `Evaluator` trait
(`fn resolve_variable()`, `fn is_degree()`, `fn ans_value()`). Do not introduce
evaluator-specific architectures.

---

## FRB Rules

- All exposed functions live in `rust/src/bridge/`.
- `#[frb(sync)]` on synchronous functions, `#[frb]` on exposed structs.
- Prefer primitives and `String` over complex Rust types.
- Error types must implement `std::error::Error` for `Result` returns.

**Sync is the default, and the exception must be justified.** `#[frb(sync)]`
runs the Rust work on the calling thread, which is what keeps the numeric
calculator's live preview free of any added latency. Omit it only for work with
no predictable upper bound — symbolic simplification, factorisation, solving —
because a blocking FFI call freezes the UI thread and risks an Android ANR. The
symbolic bridge (`bridge/symbolic.rs`) is the reference.

**New bridge functions should return a typed error, not `Result<T, String>`.**
A `SymbolicErrorInfo` (or a `success`/error-field envelope like
`StructureAnalysisResponse`) crosses the boundary as a reconstructed Dart
exception, so the UI switches on its `kind` instead of string-scrubbing wrapper
syntax out of the message. The existing `replaceAll('AnyhowException(', '')`
pattern in the modular and function-evaluator providers is the thing to avoid,
not the pattern to copy.

**No two public types in the crate may share a name.** `flutter_rust_bridge`
keys every generated type by its *bare* name, ignoring the module. A domain
struct and the transport struct the bridge declares for it — same name, two
types — collide, and codegen resolves it by keeping `items_of_key[0]` and
logging at `info` level. Nothing fails; the loser silently loses its binding
and the symptom shows up later as a decoding bug, not a naming mistake.
`test/rust_type_name_uniqueness_test.dart` enforces this and runs with
`flutter test`. When it fires, either rename the domain type or drop the bridge
mirror and mark the domain type `#[frb]` — but keep the mirror, since the other
three domains all use it.

---

## UI Rules

**Dual theme is not optional.** `UiStyle.material` | `UiStyle.liquidGlass`.
Every component takes `required UiStyle uiStyle` and must render correctly in
both.

1. Use `SharedSurface` for every container/card/panel — never a raw `Container`
   or `Material`. Pass `glassRole`; pass `materialColor` to override the
   Material-mode fill.
2. Branch on `uiStyle` only for fundamentally different widget trees.
3. Colors from `colorScheme`; component-specific semantics from
   `AppThemeExtension`; glass colors from `resolveGlassStyle()`.
4. Full-screen surfaces (drawer, rail, search) need `frosted: true` and
   `resolveOverlaySurfaceFill()` — `GlassSurfaceRole.panel` is too translucent
   over page content.

**Glass roles** — `panel` full-width sections/dialog backgrounds · `card` content
cards and result displays · `button` interactive buttons · `accent` secondary
actions · `primary` primary actions and operators · `destructive` clear/delete.

**Existing shared widgets** — use these; extend rather than fork.

| Widget | File |
| --- | --- |
| `SharedSurface`, `resolveGlassStyle`, `GlassSurfaceRole` | `shared/widgets/glass_utils.dart` |
| `SharedGlassBackground` | `shared/widgets/glass_utils.dart` |
| `AppCalcButton` | `shared/widgets/app_button.dart` |
| `showAppDialog()` | `shared/widgets/app_dialog.dart` |
| `AppDropdownMenu` | `shared/widgets/app_dropdown_menu.dart` |
| `AppTabBar` | `shared/widgets/app_tab_bar.dart` |
| `AppHubGrid` | `shared/widgets/app_hub_grid.dart` |
| `AppNavigationDrawer`, `AppNavigationRail` | `shared/widgets/app_navigation.dart` |
| `AppNotice`, `showAppNotice()` | `shared/widgets/app_notice.dart` |
| `PillSwitcher` | `shared/widgets/pill_switcher.dart` |
| `MultiPillSwitcher` | `shared/widgets/multi_pill_switcher.dart` |
| `AppChip` | `shared/widgets/app_chip.dart` |
| `MathExpressionText` | `shared/widgets/math_expression_text.dart` |
| `AppBreakpoints`, `ResponsiveKeypadLayout` | `shared/layouts/breakpoints.dart` |

New shared widgets go in `lib/shared/widgets/`.

**Viewports and degenerate constraints.** A grid or list inside an
`IndexedStack` builds on the first frame, when the window can still measure
zero (Android, while insets settle). Guard non-positive or non-finite
constraints and render nothing rather than tripping a sliver assertion.

**State** — Riverpod with `riverpod_annotation`. Providers live in
`features/<feature>/presentation/providers/`, app-level ones in
`lib/app/providers/`. State classes live beside their providers. Never
introduce a second solution.

**Accessibility** — keyboard navigation, semantic labels, and responsive
portrait/landscape layouts for all widgets. `AppNavigationTile` is the
reference: `Semantics(selected:)` plus Enter/Space activation.

---

## Testing

**Required** when changing: evaluators, parsers, arithmetic, number theory,
history, or anything user-visible in a widget. For a widget, cover **both**
`UiStyle` values, and assert on real behaviour — a test that passes when the
bug is reintroduced is worse than no test.

Widget tests cannot call the Rust bridge. Override the provider rather than
mocking FRB (see `test/features/history/history_embedded_test.dart`), or test
the widget that does not depend on it.

- Rust: `rust/src/tests/` for integration, `#[cfg(test)] mod tests` for unit.
- Flutter: `test/`, mirroring `lib/`.

A test file that is not listed in `rust/src/tests/mod.rs` does not compile, does
not run, and does not count as coverage. Register the module in the same commit
that writes it.

Prioritise exact-value checks, then edge cases (zero, negative, boundary),
overflow scenarios, and invalid input. For arithmetic, check against exact
`BigInt` and against mathematical identities — `(a+b) mod m == ((a mod m)+(b
mod m)) mod m`, `a^(x+y) mod m == (a^x · a^y) mod m`, `a · inv(a) == 1 (mod m)`
when `gcd(a,m) == 1` — never against a second copy of the same algorithm, which
would pass when both copies are wrong. Use a fixed-seed PRNG so a failure is
reproducible.

---

## Definition of Done

- `flutter analyze`, `flutter test`, `cargo test`, `cargo clippy` all pass.
- FRB bindings regenerated if `rust/src/bridge/` changed.
- Works in both UI styles.
- No duplicate abstractions introduced.
- New public Rust/Dart items are documented.
- Architectural changes are reflected in this file.

---

## Refactoring

Preserve behaviour; add tests before major changes; reduce duplication; prefer
many small changes over one large one.
