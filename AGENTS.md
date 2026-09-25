# AGENTS.md — AI Collaboration Guide

> **For:** Claude Code, ChatGPT, Gemini CLI, Cursor, Codex, Aider, OpenHands, and all coding agents.
>
> **Project:** Cross-platform calculator with Flutter frontend, Rust computation engine, and flutter_rust_bridge (FRB).
>
> **Principle:** Correctness is more important than implementation convenience.

---

<!-- BEGIN:agent-critical-rules -->

# CRITICAL: Read This First

This file is intentionally authoritative. Do not ignore project-specific rules in favor of framework defaults.

This repository does not follow typical Flutter calculator architecture.

Before making any change:

1. Read this AGENTS.md.
2. Inspect existing implementations.
3. Reuse existing abstractions.
4. Make the smallest change that solves the problem.
5. Follow existing architecture and naming conventions.
6. Run relevant validation steps.

AGENTS.md is the source of truth whenever it conflicts with framework defaults or model assumptions.

---

# Agent Workflow

Before coding:

1. Understand the task.
2. Search the codebase for existing implementations.
3. Identify reusable abstractions.
4. Propose the minimal change.
5. Implement.
6. Run tests.
7. Run analysis/linting.
8. Verify both Material and Liquid Glass modes.

---

# Architecture Constraints

Do not:

- Edit generated files.
- Move computation logic into Flutter.
- Introduce a second state management solution.
- Create parallel UI systems.
- Create duplicate abstractions.
- Bypass existing architectural patterns.
- Introduce temporary fixes when a root-cause fix is possible.

Prefer extending existing architecture over creating new architecture.

---

# Mathematical Requirements

The calculator prioritizes correctness over performance.

Rules:

- Never silently lose precision.
- Never silently overflow.
- Never silently truncate.
- Never silently approximate.
- Return explicit errors instead of incorrect results.
- Prefer exact arithmetic whenever possible.

Preferred numeric hierarchy:

1. BigInt
2. BigRational
3. BigDecimal
4. Primitive numeric types only when unavoidable

Never use:

- f32
- Floating point for exact arithmetic

A slower correct result is preferred over a faster incorrect result.

---

# Reuse First

Before creating:

- Widgets
- Dialogs
- Dropdowns
- Providers
- Evaluators
- Parsers
- Error types
- History systems

Search the codebase first.

Specifically inspect:

- lib/shared/widgets/
- lib/shared/
- rust/src/shared/
- Existing feature implementations

Extend existing abstractions before creating new ones.

---

# Code Generation Requirements

After modifying:

### Rust Bridge

```bash
flutter_rust_bridge_codegen generate
```

### Riverpod Providers

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Validation

```bash
flutter analyze
cd rust && cargo clippy
```

Run relevant tests before considering the task complete.

---

# Project-Specific Knowledge

## UI

Always prefer existing shared widgets:

- SharedSurface
- AppCalcButton
- AppDropdownMenu
- AppTabBar
- showAppDialog()
- PillSwitcher
- MultiPillSwitcher

Do not create parallel implementations.

## Themes

Material and Liquid Glass are first-class UI systems.

Feature parity is required.

## Evaluators

All evaluation modes should follow the Evaluator trait pattern.

Do not introduce evaluator-specific architectures unless necessary.

## History

Use the history_bridge! macro for history-enabled systems.

Do not duplicate history CRUD bridge logic.

## Flutter / Rust Boundary

All mathematical computation belongs in Rust.

Flutter is responsible for:

- UI
- State management
- User interaction
- Presentation

Rust is responsible for:

- Mathematical evaluation
- Number theory
- Arbitrary precision arithmetic
- Parsing
- Domain logic

---

## Project Overview

This is a production-grade calculator application built with:

- Flutter frontend
- Rust computation engine
- flutter_rust_bridge
- Riverpod
- Material + Liquid Glass dual-theme architecture

The calculator uses arbitrary precision arithmetic, exact rational arithmetic, modular arithmetic, and number theory utilities.

---

## Core Principles

1. Mathematical correctness above all else.
2. Maintainability over cleverness.
3. Reuse before creating.
4. Deterministic behavior across platforms.
5. Strict separation between UI and computation.
6. Clear code over clever code.

## Definition of Done

A task is not complete until:

- Code compiles
- Relevant tests pass
- flutter analyze passes
- cargo clippy passes
- Both Material and Liquid Glass modes work
- No duplicate abstractions were introduced

<!-- END:agent-critical-rules -->

## Architecture

### Directory Structure

```
├── rust/src/                    # Rust computation engine
│   ├── bridge/                  # FRB API surface (calculator.rs, modular_arithmetic.rs, converter.rs)
│   ├── calculator/              # Standard calculator engine
│   │   ├── evaluator/           # Evaluator trait + implementations
│   │   │   ├── mod.rs           # Evaluator trait, evaluate_expr()
│   │   │   ├── basic_evaluator.rs
│   │   │   └── function_evaluator.rs
│   │   ├── parser.rs            # Tokenizer + recursive descent parser → Expr AST
│   │   ├── rational.rs          # CalcValue enum (Rational, PiRational, Float)
│   │   ├── error.rs             # CalcError enum
│   │   └── memory.rs            # Calculator memory (M+, M-, MR, MC)
│   ├── modular_arithmetic/            # Modular arithmetic + number theory
│   │   ├── evaluator.rs         # Modular expression evaluator
│   │   ├── parser.rs            # Modular expression parser
│   │   ├── structure_parser.rs  # Structure notation parser (Z_n, Z_n*, GF(p))
│   │   ├── mod_arith.rs         # Core modular operations (mod_pow, mod_inv, etc.)
│   │   ├── number_theory.rs     # GCD, Euler's totient, etc.
│   │   ├── number_theory_ext.rs # Unit groups, primitive roots, element orders
│   │   ├── ring_analysis.rs     # Ring classification
│   │   ├── cayley.rs            # Cayley table generation
│   │   ├── galois.rs            # Galois field utilities
│   │   ├── quadratic.rs         # Quadratic residues
│   │   └── error.rs             # ModError enum
│   ├── converter/               # Unit converter
│   ├── shared/                  # Shared Rust utilities
│   │   ├── history.rs           # HistoryManager + history_bridge! macro
│   │   └── error.rs             # CommonError enum
│   ├── tests/                   # Integration tests
│   └── lib.rs                   # Crate root
│
├── lib/                         # Flutter frontend
│   ├── app/                     # App shell
│   │   ├── app.dart             # Root widget (CalculatorApp)
│   │   ├── theme/               # Theme system
│   │   │   ├── app_theme.dart   # Light/Dark/AMOLED theme builders
│   │   │   ├── app_theme_extension.dart  # AppThemeExtension
│   │   │   └── ui_style.dart    # UiStyle enum (material, liquidGlass)
│   │   ├── navigation/          # Adaptive shell + tool registry
│   │   │   ├── app_shell.dart   # AppShell (drawer/rail + IndexedStack)
│   │   │   ├── tool_registry.dart # AppTool/AppSection + appSections (single source of truth)
│   │   │   ├── tool_search_delegate.dart # Search over appSections tools
│   │   │   └── route_transitions.dart # FadePageRoute
│   │   └── providers/           # App-level providers
│   │       └── section_provider.dart # Persisted last-selected top-level section
│   ├── features/                # Feature modules (clean architecture)
│   │   ├── calculator/          # Calculator feature
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── screens/     # calculator, function_evaluator, modular_workspace
│   │   │       ├── providers/   # Riverpod notifiers + state classes
│   │   │       ├── widgets/     # Feature-specific widgets
│   │   │       └── state/
│   │   ├── symbolic_math/       # Symbolic Math hub (growing tool family)
│   │   │   └── presentation/
│   │   │       └── screens/     # symbolic_math_home_screen (Hub Grid)
│   │   ├── converter/
│   │   ├── currency/
│   │   ├── history/
│   │   └── settings/
│   ├── shared/                  # Shared UI components
│   │   ├── widgets/             # Reusable widgets (IMPORTANT — use these)
│   │   │   ├── app_button.dart  # AppCalcButton (dual-theme calculator button)
│   │   │   ├── app_dialog.dart  # showAppDialog() (dual-theme dialog system)
│   │   │   ├── app_dropdown_menu.dart  # AppDropdownMenu (dual-theme dropdown)
│   │   │   ├── app_tab_bar.dart # AppTabBar (dual-theme tab bar)
│   │   │   ├── app_hub_grid.dart # AppHubGrid (Hub Grid pattern) + AppHubGridItem
│   │   │   ├── app_navigation.dart # AppNavigationDrawer + AppNavigationRail + AppNavigationTile
│   │   │   ├── app_notice.dart  # AppNotice + showAppNotice (toast notice)
│   │   │   ├── glass_utils.dart # SharedSurface, GlassSurfaceRole, resolveGlassStyle()
│   │   │   ├── pill_switcher.dart
│   │   │   ├── multi_pill_switcher.dart
│   │   │   └── screenshot_share_wrapper.dart
│   │   ├── dialogs/
│   │   ├── animations/
│   │   └── layouts/
│   ├── core/                    # Core utilities
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── extensions/
│   │   ├── models/
│   │   ├── services/
│   │   └── utils/
│   └── generated/               # FRB generated code (DO NOT EDIT)
```

### Key Design Decisions

- **Evaluator Trait Pattern:** All evaluators implement `trait Evaluator { fn resolve_variable(), fn is_degree(), fn ans_value() }`. To add a new evaluation mode, implement this trait.
- **CalcValue Enum:** `Rational(BigRational) | PiRational(BigRational) | Float(BigDecimal)`. Arithmetic methods preserve precision when possible, falling back to `Float` only when necessary.
- **History Bridge Macro:** `history_bridge!()` generates FRB-compatible history CRUD functions for any `HistoryManager` instance. Use it for new calculator modes.
- **SharedSurface Widget:** The unified surface for both Material and Liquid Glass. All UI surfaces should use `SharedSurface` instead of raw `Container` or `Material` widgets.
- **UiStyle Enum:** `material | liquidGlass`. Every visual component receives this and must render correctly in both modes.
- **Tool Registry:** `lib/app/navigation/tool_registry.dart` is the single source of truth for every section and tool. The drawer, rail, hub grids and search all read from `appSections` — never duplicate a tool list.

---

## Navigation Architecture

### Adaptive Shell

`AppShell` (`lib/app/navigation/app_shell.dart`) is the app root. The layout is
chosen from the available width using the shared `AppBreakpoints`:

| Width       | Layout                                        |
| ----------- | --------------------------------------------- |
| `< 600`     | Hamburger button + modal `AppNavigationDrawer` |
| `600 - 840` | Persistent icon-only `AppNavigationRail`      |
| `> 840`     | Extended `AppNavigationRail` (icon + label)    |

- Sections are hosted in an **`IndexedStack`** (not `TabBarView`) so each keeps
  its own scroll position and in-progress state. Swiping is not the interaction
  model.
- Each section shows a minimal `AppBar`: title = section label, actions =
  search + `AppDropdownMenu` (Settings/About). Compact width adds a hamburger.
- The last-selected section is persisted via `section_provider.dart`.

### Tool Registry

`lib/app/navigation/tool_registry.dart` holds `AppTool` and `AppSection` models
and the `appSections` list. One section = one drawer/rail destination. A section
with 5+ loosely related tools lists them in `AppSection.tools`; a single-screen
section has an empty `tools` list.

`AppTool.open()` is the single way to launch a tool. It seeds any required
provider state via `onPrepare`, pushes with `FadePageRoute`, and shows a
`showAppNotice()` "Coming Soon" notice for tools with `isAvailable: false`.
Hub grids, the search delegate and the drawer all route through it.

### Two Patterns Inside a Section

Pick by tool count, not by feature:

| Pattern            | When                                                          |
| ------------------ | ------------------------------------------------------------- |
| **Hub Grid**       | 5+ loosely related tools, or a family that keeps growing      |
| **Segmented workspace** | 2–4 tightly coupled modes sharing one layout (same display + keypad) |

- Hub Grid: `AppHubGrid` of `SharedSurface` cards → `Navigator.push` a screen
  with its own `Scaffold` + `AppBar`. Used by Converter, Currency & Finance and
  Symbolic Math.
- Segmented workspace: `PillSwitcher` / `MultiPillSwitcher` swapping inline, no
  push. Used by Calculator (Standard/Scientific ↔ Fn Evaluator).

### Adding a Section or Tool

1. Add an `AppSection` (or an `AppTool` in an existing section's `tools`) in
   `tool_registry.dart`.
2. For a hub section, set the section's `builder` to its home screen, which
   renders `AppHubGrid` from `appHubItemsForTools(context, ref, section.tools)`.
3. For a new screen, give it a `Scaffold` + `AppBar` whose `title` matches its
   hub card label.
4. Do not touch `AppShell` — the drawer, rail and search pick it up automatically.

### Notes

- Modular Arithmetic is reached from the **Symbolic Math** hub, not the
  Calculator switcher. Its screen code still lives under
  `features/calculator/` (imported, not moved) to keep the diff small; the entry
  point is the registry. `HistoryCategory.modularArithmetic` and its deep link
  are unchanged.

---

## Rust Rules

### Numeric Types

**Always prefer:**

- `num_bigint::BigInt` for integers
- `num_rational::BigRational` for exact fractions
- `bigdecimal::BigDecimal` for high-precision decimals
- `CalcValue` enum for the calculator pipeline

**Never use without explicit justification:**

- `f32` — banned entirely
- `f64` — only for FRB bridge output formatting and trigonometric functions where exact representation is impossible

**Current dependencies (Cargo.toml):**

```toml
num-bigint = "0.4"
num-rational = "0.4"
num-traits = "0.2"
bigdecimal = "0.4"
```

### Overflow Policy

**The calculator must never overflow.**

- Never use `i32` or `i64` for intermediate calculations. Use `i128` as minimum, `BigInt` preferred.
- Never wrap, saturate, or silently truncate.
- Factorial uses `BigInt` accumulation (see `evaluator/mod.rs` Expr::Factorial).
- Modular exponentiation uses `mod_pow()` with square-and-multiply to avoid intermediate overflow.
- If a value genuinely cannot be computed, return a descriptive error — do not return a wrong answer.

### Error Handling

**Use:**

```rust
Result<T, CalcError>   // for calculator operations
Result<T, ModError>    // for modular arithmetic operations
Result<T, CommonError> // for shared operations
Result<T, String>      // only at the FRB bridge boundary
```

**Never use in production code:**

```rust
unwrap()   // BANNED outside tests
expect()   // BANNED outside tests
panic!()   // BANNED outside tests
```

All errors must be converted to user-friendly strings at the bridge layer using `.map_err(|e| e.to_string())`.

### Error Enums

The project has three error enums with `From` conversions:

- `CommonError` → base errors (`shared/error.rs`)
- `CalcError` → calculator errors, `From<CommonError>` (`calculator/error.rs`)
- `ModError` → modular math errors, `From<CommonError>` (`modular_arithmetic/error.rs`)

When adding new error variants, add them to the most specific enum. If shared, add to `CommonError` and update the `From` impls.

### Module Design

- **Small, focused modules.** One responsibility per file.
- **No god objects.** If a file exceeds ~300 lines, consider splitting.
- **Use traits for polymorphism.** See `Evaluator` trait pattern.
- **Use composition over inheritance-like patterns.**
- **Shared logic goes in `shared/`.** Don't duplicate between `calculator/` and `modular_arithmetic/`.

### Adding New Mathematical Systems

When adding a new mathematical domain:

1. Create a new module directory under `rust/src/` (e.g., `rust/src/linear_algebra/`).
2. Implement domain-specific parser, evaluator, and error types.
3. Add bridge functions in `rust/src/bridge/`.
4. Use `history_bridge!()` macro if the system needs history.
5. Register the module in `lib.rs`.
6. **Run `flutter_rust_bridge_codegen generate`** to regenerate Dart bindings.
7. Add tests in `rust/src/tests/`.

---

## Flutter Rust Bridge (FRB)

### Configuration

```yaml
# flutter_rust_bridge.yaml
rust_input: crate::bridge
rust_root: rust/
dart_output: lib/generated/rust
enable_lifetime: true
```

### Rules

- All FRB-exposed functions live in `rust/src/bridge/`.
- Mark synchronous functions with `#[frb(sync)]`.
- Mark FRB-visible structs with `#[frb]`.
- Keep interfaces simple — prefer primitive types and `String` over complex Rust types.
- Error types must implement `std::error::Error` for FRB `Result` returns.
- Generated code goes to `lib/generated/rust/` — **never edit generated files.**

### After Modifying Rust Code

**Always regenerate FRB bindings after changing any file in `rust/src/bridge/`:**

```bash
flutter_rust_bridge_codegen generate
```

Then verify the Dart side compiles:

```bash
flutter analyze
```

---

## Flutter / UI Rules

### Dual-Theme System

The app supports two visual systems:

| Enum Value            | Description                                 |
| --------------------- | ------------------------------------------- |
| `UiStyle.material`    | Standard Material 3 with dynamic color      |
| `UiStyle.liquidGlass` | iOS 26-inspired translucent glass aesthetic |

**Every UI component must work in both modes.** This is non-negotiable.

### How to Build Theme-Aware Components

1. **Accept `UiStyle uiStyle` as a required parameter.**
2. **Use `SharedSurface`** for all container/card/panel surfaces:
   ```dart
   SharedSurface(
     uiStyle: uiStyle,
     glassRole: GlassSurfaceRole.card, // panel, card, button, accent, primary, destructive
     frosted: true,
     borderRadius: BorderRadius.circular(16),
     padding: const EdgeInsets.all(16),
     child: yourContent,
   )
   ```
3. **Branch on `uiStyle`** only for fundamentally different widget trees (e.g., `FilledButton` vs glass button).
4. **Never hardcode colors.** Use `colorScheme.primary`, `colorScheme.surface`, etc.
5. **Use `AppThemeExtension`** for component-specific semantic colors:
   ```dart
   final ext = Theme.of(context).extension<AppThemeExtension>();
   ```
6. **Use `resolveGlassStyle()`** to get role-specific glass colors:
   ```dart
   final style = resolveGlassStyle(
     colorScheme,
     brightness: theme.brightness,
     role: GlassSurfaceRole.card,
     isSelected: isActive,
   );
   ```

### Glass Surface Roles

| Role          | Use For                                                  |
| ------------- | -------------------------------------------------------- |
| `panel`       | Full-width sections, dialog backgrounds, settings panels |
| `card`        | Content cards, input areas, result displays              |
| `button`      | Standard interactive buttons                             |
| `accent`      | Secondary actions, scientific functions                  |
| `primary`     | Primary actions, operators, equals                       |
| `destructive` | Clear, delete, destructive actions                       |

### Reusable Widget Catalog

**Before creating any new widget, check these existing shared widgets:**

| Widget                  | File                                      | Purpose                                                       |
| ----------------------- | ----------------------------------------- | ------------------------------------------------------------- |
| `AppCalcButton`         | `shared/widgets/app_button.dart`          | Calculator keypad buttons (dual-theme)                        |
| `showAppDialog()`       | `shared/widgets/app_dialog.dart`          | Modal dialogs with icon, title, content, actions (dual-theme) |
| `AppDropdownMenu`       | `shared/widgets/app_dropdown_menu.dart`   | Dropdown menus with icon/label trigger (dual-theme)           |
| `AppTabBar`             | `shared/widgets/app_tab_bar.dart`         | Pill-style tab bars (dual-theme)                              |
| `SharedSurface`         | `shared/widgets/glass_utils.dart`         | Unified surface container (dual-theme)                        |
| `SharedGlassBackground` | `shared/widgets/glass_utils.dart`         | App-level glass background                                    |
| `PillSwitcher`          | `shared/widgets/pill_switcher.dart`       | Binary toggle switcher                                        |
| `MultiPillSwitcher`     | `shared/widgets/multi_pill_switcher.dart` | Multi-option toggle switcher                                  |
| `AppHubGrid`            | `shared/widgets/app_hub_grid.dart`        | Hub Grid of tool cards for growing tool families (dual-theme) |
| `AppNavigationDrawer`   | `shared/widgets/app_navigation.dart`      | Compact-width navigation drawer (dual-theme)                  |
| `AppNavigationRail`     | `shared/widgets/app_navigation.dart`      | Medium/expanded navigation rail (dual-theme)                  |
| `AppNotice`             | `shared/widgets/app_notice.dart`          | Transient notice banner; `showAppNotice()` toast              |

**Rules:**

- **Never create one-off UI implementations.** Extract reusable widgets.
- **Never duplicate dialogs, dropdowns, buttons.** Use the shared versions.
- If a shared widget doesn't support your use case, **extend it** — don't create a parallel version.
- New shared widgets go in `lib/shared/widgets/`.

### State Management

- **Riverpod** with code generation (`riverpod_annotation`, `riverpod_generator`).
- Providers live in `features/<feature>/presentation/providers/`.
- State classes live alongside their providers.
- After adding/modifying providers, run:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

### Accessibility

All widgets must support:

- Keyboard navigation
- Screen reader compatibility (semantic labels)
- High contrast themes
- Responsive layouts (portrait and landscape)

### Feature Architecture

Each feature follows clean architecture:

```
features/<feature>/
├── data/            # Repositories, data sources
├── domain/          # Entities, use cases, abstractions
└── presentation/
    ├── screens/     # Full-page screens
    ├── providers/   # Riverpod providers + state
    ├── widgets/     # Feature-specific widgets
    └── state/       # State classes (if separate from providers)
```

---

## Testing

### When to Write Tests

Tests are **required** when modifying:

- Evaluators (basic, function, modular)
- Parsers (calculator, modular, structure)
- Arithmetic logic (`rational.rs`, `mod_arith.rs`)
- Number theory functions
- History systems

### Testing Priority

1. **Mathematical correctness** — verify exact values
2. **Edge cases** — zero, negative, boundary values
3. **Overflow scenarios** — large factorials, large exponents, modular arithmetic with big numbers
4. **Invalid input** — malformed expressions, division by zero, domain errors
5. **Property testing** — where useful for mathematical invariants

### Test Organization

- Rust tests: `rust/src/tests/` (integration) + `#[cfg(test)] mod tests` in source files (unit)
- Run Rust tests:
  ```bash
  cd rust && cargo test
  ```
- Run Flutter tests:
  ```bash
  flutter test
  ```
- Run Flutter analysis:
  ```bash
  flutter analyze
  ```

### Test Examples

```rust
// Good: Tests exact BigInt arithmetic
#[test]
fn factorial_large() {
    let result = evaluate("100!", ...);
    assert_eq!(result.formatted, "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000");
}

// Good: Tests modular arithmetic correctness
#[test]
fn mod_pow_correctness() {
    assert_eq!(mod_pow(17, 22, 21).unwrap(), 4);
}
```

---

## Refactoring Rules

When refactoring:

1. **Preserve behavior.** No functional changes without tests proving equivalence.
2. **Add tests before major changes.** Establish a baseline.
3. **Reduce duplication.** Extract shared patterns (see `history_bridge!` macro as example).
4. **Improve clarity.** Better names, better structure, better docs.
5. **Avoid unnecessary abstractions.** Don't abstract things that aren't duplicated.
6. **Keep diffs small.** Prefer multiple focused PRs over one large change.

---

## Documentation

When introducing:

- New modules → Add `///` doc comments on the module and public items
- New evaluators → Document the evaluation semantics and supported operations
- New mathematical systems → Explain the mathematical background and assumptions
- New shared widgets → Document parameters, usage examples, and theme behavior
- Architectural changes → Update this `AGENTS.md` file to reflect the new architecture, keeping it as the single source of truth for AI agents.

---

## Common Patterns

### Adding a New Bridge Function

```rust
// rust/src/bridge/calculator.rs
#[frb(sync)]
pub fn my_new_function(input: String) -> Result<String, String> {
    crate::calculator::my_module::compute(&input)
        .map_err(|e| e.to_string())
}
```

Then run: `flutter_rust_bridge_codegen generate`

### Adding a New Calculator Mode with History

```rust
// rust/src/shared/history.rs — add a new global instance
pub static NEW_MODE_HISTORY: HistoryManager = HistoryManager::new();

// rust/src/bridge/new_mode.rs — use the macro
crate::history_bridge!(
    new_mode_history_add,
    new_mode_history_get_all,
    new_mode_history_clear,
    new_mode_history_delete,
    new_mode_history_save,
    new_mode_history_load,
    history::NEW_MODE_HISTORY
);
```

### Creating a New Dual-Theme Widget

```dart
class MyWidget extends StatelessWidget {
  final UiStyle uiStyle;
  // ... other parameters

  const MyWidget({super.key, required this.uiStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: _buildContent(colorScheme),
    );
  }
}
```

### Creating a Dual-Theme Dialog

```dart
showAppDialog(
  context: context,
  title: 'Confirm Action',
  icon: Icons.warning_amber_rounded,
  uiStyle: uiStyle,
  isDestructive: true,
  content: Text('Are you sure?'),
  primaryButtonText: 'Delete',
  onPrimaryButtonPressed: () { /* action */ },
  secondaryButtonText: 'Cancel',
);
```

---

## What Success Looks Like

The ideal contribution:

- ✅ Improves mathematical correctness
- ✅ Preserves or improves precision
- ✅ Uses appropriate arbitrary precision types
- ✅ Handles errors explicitly with `Result<T, E>`
- ✅ Works in both Material and Liquid Glass themes
- ✅ Reuses existing shared widgets and abstractions
- ✅ Follows the established architecture
- ✅ Includes tests for mathematical logic
- ✅ Includes documentation
- ✅ Regenerates FRB bindings if Rust bridge code changed
- ✅ Passes `flutter analyze` and `cargo clippy` cleanly

---

## Anti-Patterns to Avoid

| ❌ Don't                         | ✅ Do Instead                                             |
| -------------------------------- | --------------------------------------------------------- |
| Use `f64` for integer arithmetic | Use `BigInt` or `BigRational`                             |
| Use `unwrap()` in production     | Use `?` operator or `map_err()`                           |
| Create one-off dialog widgets    | Use `showAppDialog()`                                     |
| Hardcode colors                  | Use `colorScheme` or `AppThemeExtension`                  |
| Create Material-only widgets     | Support both `UiStyle.material` and `UiStyle.liquidGlass` |
| Put math logic in Flutter        | All computation lives in Rust                             |
| Edit files in `lib/generated/`   | These are auto-generated by FRB                           |
| Skip tests for math changes      | Tests are mandatory for correctness                       |
| Create parallel abstractions     | Extend existing shared widgets                            |
| Use `Container` for surfaces     | Use `SharedSurface`                                       |
