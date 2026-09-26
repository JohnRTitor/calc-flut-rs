# num-modular Migration Feasibility Audit

**Subject:** `calc-flut-rs` (`rust/` crate `calc_flut_core` v0.1.0)
**Candidate:** `num-modular` 0.6.5 (Apache-2.0, `cmpute/num-modular`, published 2026-08-08)
**Date:** 2026-09-26
**Toolchain used for all measurements:** rustc/cargo 1.96.0, x86_64-unknown-linux-gnu host,
Android NDK r26+ from the nix-provided SDK.

> **Status: executed.** The migration described in §13 was implemented on the
> recommendation below. §14 records what was actually built and measured, including the one
> defect the migration itself introduced and one deliberate regression. Read §14 alongside
> §7 — several projections in §7 turned out to be pessimistic, and one turned out to be
> wrong in a way worth knowing about.
>
> No code was changed to produce §1–§13. Every number in them was measured against a
> throwaway copy of the crate under `/tmp`, with the *verbatim* source of `mod_arith.rs`,
> `number_theory.rs` and `quadratic.rs` compiled side by side with `num-modular`.

---

## 1. Executive summary

**Partially feasible — and the partial part is the whole correctness-critical core.**

Concretely:

| | |
|---|---|
| Can `num-modular` replace the modular ring? | **Yes, completely** — `addm/subm/mulm/negm/powm/invm` cover `mod_add`, `mod_sub`, `mod_mul`, `mod_neg`, `mod_pow`, `mod_inv`, `mod_div` with no residue-semantics loss. |
| Can it replace `is_prime`? | **Partly** — it supplies a correct Miller–Rabin inner loop (`powm`) but has no primality test of its own, so the trial-division + witness structure stays. |
| Can it replace `sqrt_mod` (Tonelli–Shanks)? | **No.** `src/lib.rs` carries a literal `// TODO: Modular sqrt`. No modular square root exists in the crate. |
| Can it replace CRT, primitive roots, discrete log, element order, unit groups, zero divisors, idempotents, nilpotents, ring classification, Cayley tables, Galois fields? | **No.** None of these are in the crate; `src/lib.rs` carries a literal `// TODO: Discrete log`. |
| Can it replace `BigInt` arithmetic paths? | **No** — `num-modular` implements `ModularCoreOps`/`ModularUnaryOps`/`ModularPow` for `BigUint` only. `BigInt` receives *only* `ModularSymbols` and `ModularAbs`. This is a compile-time fact, verified below. |
| Can it be adopted without an adapter? | **No.** It panics on a zero modulus, has no negative-modulus concept, and is unsigned-only. All three are load-bearing in calc-flut-rs. |

**The decisive finding is not API overlap — it is that the existing implementation is
demonstrably wrong, and `num-modular` is demonstrably right.**

`mod_mul` computes `mod_reduce(a,n) * mod_reduce(b,n)` in `i128`. Both factors are below `n`,
so for any modulus above roughly `2^63.5` the product exceeds `i128::MAX`. The release
profile has `overflow-checks` off (`panic = "abort"`, `opt-level = "z"`, `lto = true`), so the
product wraps silently and the calculator **prints a wrong answer with no error**.

Measured, on the exact code path the numeric calculator's live preview uses
(`calculator/evaluator/mod.rs:90`):

```
1000000007^1000000 mod 18446744073709551617
    calc-flut mod_pow  = 12956317909733381446
    exact (BigInt)     = 18070626694062595144
    num-modular powm   = 18070626694062595144
```

Over 400,000 randomised cases with positive moduli of 1–127 bits, the current `mod_mul`
disagreed with exact `BigInt` arithmetic in **192,084 cases (48.0%)**; `num-modular`'s
`u128::mulm` disagreed in **zero**. The same defect propagates into `mod_pow`, `is_prime`,
`legendre_symbol`, `sqrt_mod`, `element_order`, `primitive_roots` and `discrete_log`, all of
which are built on `mod_mul`.

A second live bug: `is_prime(2^127 - 1)` returns **`false`** for the Mersenne prime
`170141183460469231731687303715884105727`, because Miller–Rabin's witness exponentiation is
built on the same broken `mod_pow`. That answer gates `StructureMode::Field`,
`legendre_symbol` and `sqrt_mod`.

And the reason this survived: **`rust/src/tests/modular_arithmetic_tests.rs` is an orphan.**
It is not listed in `rust/src/tests/mod.rs`, so its three tests have never been compiled or
run. `cargo test` reported 130 tests before this audit; three modular tests exist on disk
and zero of them execute.

**Recommendation: migrate, as a hybrid (Option C) behind a thin `i128` adapter (Option B
shape).** The overlap with `num-modular` is the entire hot path, so there is no
half-migrated state to reason about; everything it does not cover was never its job.

---

## 2. Current implementation inventory

### 2.1 Architecture

There is no separate "modular arithmetic layer". The domain is one Rust module,
`rust/src/modular_arithmetic/`, that owns its own parser, AST, evaluator, error type and
numeric core, entirely on `i128`. It is a *sibling* of `calculator/` and `symbolic/`, not a
layer beneath them, and per `AGENTS.md` it must stay that way.

```
lib/features/calculator/…/modular_arithmetic_workspace_*.dart
        │  (modulus is a free-text String from a TextField)
        ▼
bridge/modular_arithmetic.rs  ── modular_evaluate()  → Result<ModularResult, String>
                             └─ analyze_structure()  → StructureAnalysisResponse
        ▼
modular_arithmetic/parser.rs        ModExpr AST  (Number, Add, …, PowMod, Inv, Legendre, …)
        ▼
modular_arithmetic/evaluator.rs     eval() → i128; dispatch + presentation strings
        ▼
modular_arithmetic/mod_arith.rs     ◄── THE NUMERIC CORE (all i128)
   number_theory.rs       gcd, extended_gcd, crt
   number_theory_ext.rs   factorisation, φ, order, primitive roots, units, dlog, congruence
   quadratic.rs           residues, Legendre, Jacobi, Tonelli–Shanks
   ring_analysis.rs       zero divisors, idempotents, nilpotents, ring classification
   cayley.rs              addition / multiplication / unit-group tables
   galois.rs              GFPrime field element
   structure_parser.rs    "Z_12", "U(10)", "GF(7)" notation
```

A **second, separate** modular path exists in the numeric calculator and is *not* part of
this module:

- `calculator/rational.rs:144` — `CalcValue::modulo`, which does its own `BigInt` remainder
  with its own sign correction for the `%` key.
- `calculator/evaluator/mod.rs:68-107` — `Expr::Modulo`. When the left side is
  `Expr::Power`, it special-cases modular exponentiation and delegates to
  `modular_arithmetic::mod_arith::mod_pow`, falling back to `CalcValue::pow().modulo()`.

`symbolic/` is backed by `symplex` over `Ratio<BigInt>` and contains no modular arithmetic.
`converter/` and the currency path are unrelated.

### 2.2 Operation-by-operation inventory

| Existing operation | Implementation | Operands | Output | Zero modulus | Negative modulus | Negative operands | Overflow | Public API | Tests |
|---|---|---|---|---|---|---|---|---|---|
| `mod_reduce` | `mod_arith.rs:4` | `i128, i128` | `i128` | **returns `a` unchanged** | returns `r` in `[0,\|n\|)` | normalised to `[0,\|n\|)` | none | internal | **none** |
| `mod_add` | `mod_arith.rs:17` | `i128×3` | `i128` | returns `a+b` | same as above | normalised | `reduce(a)+reduce(b)` can overflow `i128` | internal | **none** |
| `mod_sub` | `mod_arith.rs:22` | `i128×3` | `i128` | returns `a-b` | same | normalised | `reduce(a)-reduce(b)` can overflow | internal | **none** |
| `mod_mul` | `mod_arith.rs:27` | `i128×3` | `i128` | returns `a*b` | same | normalised | **`reduce(a)*reduce(b)` silently wraps above `2^63.5`** | internal | **none** |
| `mod_neg` | `mod_arith.rs:32` | `i128×2` | `i128` | returns `a` | same | normalised | `-a` overflows at `i128::MIN` | internal | **none** |
| `mod_pow` | `mod_arith.rs:37` | `i128×3` | `Result<i128,ModError>` | `Err(InvalidModulus)` | `Err(InvalidModulus)` | base normalised; **negative exponent → `mod_inv` then negate exponent** | inherits `mod_mul`'s bug | internal + calculator preview | **none** |
| `mod_inv` | `mod_arith.rs:67` | `i128×2` | `Result<i128,ModError>` | `Err(InverseDoesNotExist)` | works (via `extended_gcd` sign fix-up) | normalised | — | bridge (2 sites) | **none** |
| `mod_div` | `mod_arith.rs:79` | `i128×3` | `Result<i128,ModError>` | `Err` from `mod_inv` | works | — | — | `galois.rs` | **none** |
| `is_prime` | `mod_arith.rs:85` | `i128` | `bool` | `false` | `false` | — | inherits `mod_pow`'s bug | bridge, evaluator, quadratic, ring_analysis | **none** |
| `gcd` | `number_theory.rs:4` | `i128×2` | `i128` | `0` | `abs()` | `abs()` | `i128::MIN.abs()` overflows | internal | **none** |
| `extended_gcd` | `number_theory.rs:17` | `i128×2` | `(i128,i128,i128)` | `(0,…)` | sign fix-up at the end | `abs()` | coefficient products can overflow | evaluator (Bézout display) | **none** |
| `crt` | `number_theory.rs:56` | `&[(i128,i128)]` | `Result<(i128,i128),ModError>` | `Err` | `Err(InvalidModulus)` | reduced | `lcm` product can overflow | evaluator | **none** |
| `legendre_symbol` | `quadratic.rs:33` | `i128×2` | `Result<i8,ModError>` | `Err(InvalidModulus)` | `Err` | reduced | inherits `mod_pow` | evaluator | **none** |
| `jacobi_symbol` | `quadratic.rs:49` | `i128×2` | `Result<i8,ModError>` | `Err` | `Err` | reduced | none | evaluator | **none** |
| `sqrt_mod` | `quadratic.rs:82` | `i128×2` | `Result<Vec<i128>,ModError>` | `Err(NotPrime)` | `Err` | reduced | inherits `mod_mul` | evaluator | **none** |
| `prime_factorization` | `number_theory_ext.rs:11` | `i128` | `Vec<(i128,u32)>` | `[]` | `abs()` | `abs()` | `i*i` can overflow for `n > 2^63` | evaluator, ring_analysis | **none** |
| `euler_totient` | `number_theory_ext.rs:47` | `i128` | `i128` | `0` | `abs()` | `abs()` | — | evaluator | **none** |
| `element_order` | `number_theory_ext.rs:61` | `i128×2` | `Result<i128,ModError>` | `Err` | `Err` | reduced | inherits `mod_pow` | evaluator, bridge | **none** |
| `primitive_roots` | `number_theory_ext.rs:118` | `i128` | `Result<Vec<i128>,ModError>` | `Err` | `Err` | — | — | evaluator, bridge | 1 orphan test |
| `unit_group` | `number_theory_ext.rs:185` | `i128` | `Vec<i128>` | `[]` | `abs()` | — | — | evaluator, cayley, bridge | 1 orphan test |
| `solve_linear_congruence` | `number_theory_ext.rs:206` | `i128×3` | `Result<Vec<i128>,ModError>` | `Err` | `Err` | reduced | `x*(b/g)` can overflow | evaluator | **none** |
| `discrete_log` | `number_theory_ext.rs:238` | `i128×3` | `Result<i128,ModError>` | `Err` | `Err` | reduced | — | evaluator | **none** |
| `GFPrime` | `galois.rs` | `i128` field element | `Result<GFPrime,ModError>` | `Err` | `Err` | reduced | — | crate-internal | **none** |

**Coverage of the current test suite: 3 tests exist for this whole table, all orphaned, and
none of them touch a numeric core function.** They test `analyze_structure` output shape
only.

### 2.3 The canonical residue invariant

`mod_reduce` returns a value `r` with `0 ≤ r < |n|`, for **every** `n ≠ 0`. The
`n < 0` branch looks load-bearing but is not: the function is exactly
`a.rem_euclid(|n|)`.

Verified two ways:

- exhaustive over `a ∈ [-2000, 2000] × n ∈ [-300, 300] \ {0}` plus 2,000,000 random 127-bit
  pairs: **4,400,600 checked, 0 mismatches** against `a.rem_euclid(|n|)`.
- 2,000,000 random pairs: **0 mismatches** against `num_modular`'s `i128::absm(&n)`.

This is the single most important compatibility fact in the audit. It means the invariant
`0 ≤ r < n` for `n > 0` — which is what `num-modular` guarantees — is *already* calc-flut-rs's
invariant, so no residue semantics change is required.

---

## 3. `num-modular` capability matrix

Read from the 0.6.5 source, not from memory.

### 3.1 Trait coverage vs. calc-flut-rs

| calc-flut-rs operation | `num-modular` equivalent | Available? | Notes |
|---|---|---|---|
| `mod_add` | `ModularCoreOps::addm` | ✅ | `u8/16/32/64/128/usize`, `BigUint` |
| `mod_sub` | `ModularCoreOps::subm` | ✅ | same |
| `mod_mul` | `ModularCoreOps::mulm` | ✅ | `u128` uses `checked_mul` then `udouble::widening_mul` — **overflow-safe** |
| `mod_neg` | `ModularUnaryOps::negm` | ✅ | |
| `mod_pow` | `ModularPow::powm` | ✅ | square-and-multiply; `u128` routes through `Vanilla` |
| `mod_inv` | `ModularUnaryOps::invm` → `Option` | ✅ | `None` iff `gcd > 1`; no panic |
| `mod_div` | *(compose)* `a.mulm(a.invm(b)?, m)` | ✅ | crate has no `divm`; composition is 1 line |
| `is_prime` | **none** | ❌ | no primality test in the crate |
| `quadratic_residues` | **none** | ❌ | |
| `legendre_symbol` | `ModularSymbols::checked_legendre` → `Option<i8>` | ⚠️ | no primality gate; doc: *"this function doesn't perform a full primality check… the result can be not reasonable"* |
| `jacobi_symbol` | `ModularSymbols::checked_jacobi` → `Option<i8>` | ✅ | `None` iff `n` even |
| *(none)* | `ModularSymbols::kronecker` | 🆕 | **new capability calc-flut-rs lacks** |
| `sqrt_mod` | **none** | ❌ | `src/lib.rs`: `// TODO: Modular sqrt aka Quadratic residue` |
| `crt` | **none** | ❌ | `src/lib.rs`: `// TODO: … and crt` |
| `discrete_log` | **none** | ❌ | `src/lib.rs`: `// TODO: Discrete log aka index` |
| `gcd` / `lcm` | **none** | ❌ | out of scope for the crate |
| `element_order`, `primitive_roots`, `unit_group` | **none** | ❌ | |
| ring analysis, Cayley tables, `GFPrime` | **none** | ❌ | |

### 3.2 Backend / type support (from the generated impl lists)

| Type | `ModularCoreOps` | `ModularUnaryOps` | `ModularPow` | `ModularSymbols` | `ModularAbs` |
|---|---|---|---|---|---|
| `u8` `u16` `u32` `u64` `u128` `usize` | ✅ owned + `&` | ✅ | ✅ | ✅ | n/a |
| `i8`…`i128`, `isize` | ❌ | ❌ | ❌ | ❌ | ✅ (only `absm`) |
| `BigUint` | ✅ owned + `&` | ✅ | ✅ (`BigUint::modpow`) | ✅ | n/a |
| `BigInt` | ❌ | ❌ | ❌ | ✅ | ✅ (only `absm`) |

Owned and `&` variants exist for the unsigned primitives and `BigUint`, and `ModularRefOps`
is blanket-implemented. Reference ergonomics are adequate for the evaluator, which passes
`i128` by value anyway.

The `BigInt` gap is not documentation trivia — it is a compile error, captured verbatim:

```
error[E0599]: no method named `addm` found for struct `BigInt`
   = help: there is a method named `add` with a similar argument
```

`BigInt` support is limited to `ModularSymbols` (`bigint.rs:280-341`) and `ModularAbs`
(`bigint.rs:345`).

### 3.3 Feature flags and dependency shape

```toml
[features]
num-bigint = ["dep:num-bigint", "dep:num-integer", "dep:num-traits"]
num-traits = ["dep:num-traits"]
std        = []
```

`num-bigint` transitively enables `num-integer` and `num-traits`. `std` is **not** required;
the crate is `#![no_std]` with `extern crate std` only under `#[cfg(any(feature = "std", test))]`.

Minimal correct configuration for calc-flut-rs's actual usage:

```toml
num-modular = { version = "0.6.5", default-features = false, features = ["num-bigint"] }
```

`default-features = false` is meaningful here — the crate has no default feature set, so
this is documentation of intent rather than a behavioural change. `std` must **not** be
enabled. `num-bigint` is required because `bigint.rs` gates the `BigUint` `mulm` fast path
and the `Vanilla<BigUint>` reducer behind `all(feature = "num-bigint", feature = "num-traits")`.

### 3.4 Optimised representations — do they help?

| Type | Verdict for calc-flut-rs |
|---|---|
| `Vanilla` / `VanillaInt` | This is the default behind `u128::powm` and the whole `BigUint` path. Adopted by default. |
| `Montgomery` / `MontgomeryInt` | **Measured: no.** See §7. Fastest raw multiply (2.7 ns) but requires conversion per operand, needs an **odd** modulus, and the calculator has no workload with a fixed modulus across many operations. Complexity without benefit. |
| `FixedMontgomery32/64` | Compile-time modulus only. The calculator's modulus is user text. Inapplicable. |
| `FixedMersenne*`, `FixedSolinas*`, `FixedProth*` | Special moduli of the form `2^p − k`. A user typing `7` or `998244353` matches none. Inapplicable. |
| `PreModInv`, `PreMulInv*` | Exact-division helpers. calc-flut-rs divides by `gcd` in `crt`/`solve_linear_congruence`, but on `i128` where these are `u32/u64`-word-shaped. Inapplicable. |
| `ReducedInt` + `Reducer` | See §5. |

---

## 4. Semantic compatibility matrix

Every row below was executed, not reasoned about. `calc` = verbatim current source;
`nm` = `num-modular` 0.6.5.

### 4.1 Zero modulus — **BREAKING if adopted naively**

| Expression | calc-flut-rs | `num-modular` | Verdict |
|---|---|---|---|
| `mod_reduce(5, 0)` | `5` (pass-through) | **panic** | adapter must special-case |
| `mod_add(5, 3, 0)` | `8` | **panic** | adapter |
| `mod_sub(5, 3, 0)` | `2` | **panic** | adapter |
| `mod_mul(5, 3, 0)` | `15` | **panic** | adapter |
| `mod_neg(5, 0)` | `5` | **panic** | adapter |
| `mod_pow(5, 3, 0)` | `Err(InvalidModulus)` | **panic** | adapter |
| `mod_inv(3, 0)` | `Err(InverseDoesNotExist)` | **panic** (`invm` divides by `m`) | adapter |

`ModularCoreOps` documents *"all functions will panic if the modulus is zero"*, and
`Vanilla::<T>::new` is `assert!(m > &0)`. Confirmed at runtime: all five panic.

calc-flut-rs's own convention is inconsistent (`mod_reduce`/`mod_add`/`mod_sub`/`mod_mul`/
`mod_neg` pass through; `mod_pow`/`mod_inv` return `Err`). **Preserving the inconsistency
exactly is mandatory** — `mod_reduce(5, 0) == 5` is observable through `ModExpr::Modulo`'s
sibling paths and through `CalcValue::modulo`'s fallback, and silently changing it would be
a behaviour change. This is adapter work, three lines, and it is also a place where the
existing pass-through is arguably wrong (`mod_mul(5,3,0) == 15` is not a residue) — flagged in
§10, **not** to be changed as part of this migration.

### 4.2 Negative values — **BREAKING if adopted naively**

Positive modulus, signed operands — `num-modular` matches exactly:

| | calc | `i128::absm` | agree |
|---|---|---|---|
| `-1 mod 5` | 4 | 4 | ✅ |
| `-6 mod 5` | 4 | 4 | ✅ |
| `-1 mod 7` | 6 | 6 | ✅ |
| `-7 mod 7` | 0 | 0 | ✅ |
| `-13 mod 17` | 4 | 4 | ✅ |
| `0 mod 5` | 0 | 0 | ✅ |

Negative **modulus** — `num-modular` has no such concept:

| | calc | `num-modular` | agree |
|---|---|---|---|
| `6 mod -5` | `1` | *no representation* | ❌ |
| `mod_inv(3, -7)` | `Ok(5)` | *no representation* (`None` if you pass `7`) | ❌ |

This matters because **the modulus is a free-text `TextField`**
(`modular_arithmetic_context_toolbar.dart:56`), passed as a `String` and parsed with
`s.parse::<i128>()` at `bridge/modular_arithmetic.rs:36`. A user can type `-7` today and get
an answer. `ModExpr::Modulo` rejects `b ≤ 0` (`evaluator.rs:406`), but the *context* modulus
does not go through that check.

Because §2.3 proved `mod_reduce(a, n) == a.rem_euclid(|n|)`, the adapter absorbs this with a
single `unsigned_abs()` and no per-operation special-casing. `mod_pow` already rejects
`modulus ≤ 0`, so it is unaffected.

### 4.3 Modular inverse

| | calc | `invm` | agree |
|---|---|---|---|
| `inv(3) mod 7` | `Ok(5)` | `Some(5)` | ✅ |
| `inv(2) mod 6` | `Err(InverseDoesNotExist)` | `None` | ✅ |
| `inv(0) mod 7` | `Err(InverseDoesNotExist)` | `None` | ✅ |
| `inv(5) mod 5` | `Err` | `None` | ✅ |
| `inv(-3) mod 7` | `Ok(2)` | `Some(2)` | ✅ |
| `inv(1) mod 1` | `Ok(0)` | `Some(0)` | ✅ |
| `inv(3) mod -7` | `Ok(5)` | *no representation* | ❌ (adapter) |

400,000 randomised pairs: **400,000 agreements**, including every `Err`/`None` pairing.
`invm` returns `Option`, never panics on non-coprime input, and its result is already
normalised (the coefficient is maintained through `subm`). The bridge's two `if let Ok(inv)`
call sites keep working unchanged.

The `mod_inv(a, 0)` case is the one place the adapter must convert `None` into a *specific*
error, because `invm(5, 0)` panics rather than returning `None`.

### 4.4 Modular division

`mod_div(a, b, n) = a · inv(b) mod n`, rejecting non-invertible `b`. This is the correct
ring/field semantics and there is no accidental field assumption to avoid — calc-flut-rs
already refuses to divide in `Z_n` when `b` is not a unit, and `StructureMode::Field` is
gated on `is_prime` at `evaluator.rs:69-78`. `num-modular` has no `divm`; composing
`mulm` with `invm` is identical to the current `mod_div`. **No semantic issue.**

### 4.5 Exponentiation

| | calc | `powm` | agree |
|---|---|---|---|
| `2^0 mod 7` | `1` | `1` | ✅ |
| `0^0 mod 7` | `1` | `1` | ✅ |
| `0^5 mod 7` | `0` | `0` | ✅ |
| `5^0 mod 1` | `0` | `0` | ✅ |
| `2^1 mod 7` | `2` | `2` | ✅ |
| `2^2 mod 7` | `4` | `4` | ✅ |
| `7^3 mod 7` | `0` | `0` | ✅ |
| `1^0 mod 1` | `0` | `0` | ✅ |
| `2^-1 mod 7` | `Ok(4)` | *no representation* (unsigned) | adapter keeps calc's path |

- `exp = 0` → `Vanilla::pow` takes the generic branch, `result = self.transform(1) = 1 % m`,
  loop body never runs → `1` for `m ≥ 2`, `0` for `m = 1`. Matches.
- `exp = 1` → `Vanilla::pow` short-circuits to `base`, and `u128::powm` pre-reduces via
  `self % m` before calling it. Matches.
- `exp = 2` → `self.sqr(base)`. Matches.
- `mod_pow` special-cases `modulus == 1 → 0` before delegating, so `Vanilla::new`'s
  `assert!(m > 0)` is never the thing that rejects `m = 1`.
- **Negative exponents**: `num-modular` has no signed exponents. The adapter keeps
  calc-flut-rs's existing "invert the base, flip the exponent" rule verbatim. This is a
  genuine feature of the app (`ModExpr::Power` under a context modulus) with no library
  equivalent, so it stays.
- Huge `BigInt` exponents: out of scope, `mod_pow` is `i128`-only today.

### 4.6 Canonical residue representation

calc-flut-rs: `0 ≤ r < |n|` (proved exhaustively, §2.3).
`num-modular`: `0 ≤ r < m` for `m > 0`, guaranteed by construction — `Vanilla` is documented
*"It will keep the integer in range [0, modulus) after each operation"*, `negm` is
`0 → 0 else m − x`, `invm`'s coefficient is maintained through `subm`, and `absm` is
`self as u % m` / `(-self as u).negm(m)`.

**Identical invariant. No adapter needed for normalisation, and no residue-semantics change
for the user.**

### 4.7 Overflow — **this is the bug**

`mod_mul` is `mod_reduce(mod_reduce(a,n) * mod_reduce(b,n), n)`. Both factors are `< n`, so
the product is `< n²`. `i128::MAX ≈ 2^127`, so the product overflows whenever `n > 2^63.5`
≈ `1.3 × 10^19`.

| modulus bits | calc agrees with exact `BigInt`? | `num-modular` agrees? |
|---|---|---|
| ≤ 62 | ✅ | ✅ |
| 63 | ✅ | ✅ |
| 64 | ❌ | ✅ |
| 80 | ❌ | ✅ |
| 100 | ❌ | ✅ |
| 120 | ❌ | ✅ |
| 126 | ❌ | ✅ |

Randomised, 400,000 cases, moduli 1–127 bits, positive:

```
reduce agrees : 400000   (1.000)
add agrees    : 400000   (1.000)
sub agrees    : 400000   (1.000)
mul agrees    : 207916   (0.520)   <-- 48.0% wrong
pow agrees    : 210092   (0.525)   <-- 47.5% wrong
inv agrees    : 400000   (1.000)
```

**`num-modular` produced zero `NM-MUL` divergences across the same 400,000 cases.**

Mechanism: `u128::mulm` is `if let Some(ab) = self.checked_mul(rhs) { ab % m } else { udouble::widening_mul(self, rhs) % m }` — a full 256-bit intermediate. `u128::addm` similarly falls back to `udouble::widening_add`. This is exactly the property `AGENTS.md` demands: *"a migration that is mathematically correct only when intermediate arithmetic happens not to overflow"* is forbidden, and the current code is.

The `128 + 64` → `192`-bit and `u64 + u64` → `u128` paths use plain widening casts, also safe.

Downstream damage, all built on `mod_mul`/`mod_pow`: `is_prime`, `legendre_symbol`,
`sqrt_mod`, `element_order`, `primitive_roots`, `discrete_log`, `idempotents_limited`,
`is_prime` as the `StructureMode::Field` gate, and the numeric calculator's
`Expr::Modulo(Power, ·)` preview. Confirmed: `is_prime(2^127 − 1) == false` for a known prime.

### 4.8 BigInt

- `ModularCoreOps`, `ModularUnaryOps`, `ModularPow`: **`BigUint` only.**
- `BigInt`: `ModularSymbols` and `ModularAbs` only.
- Consequences for calc-flut-rs: **none today**, because the whole `modular_arithmetic/`
  domain is `i128` and `BigInt` is used only in `calculator/rational.rs`, which has its own
  `%` implementation and does not route through `num-modular`.
- If `BigInt` moduli are ever wanted, the sign must be split: reduce the sign separately and
  run the magnitude through `BigUint`, then re-apply. Measured cost of doing it that way
  versus `BigInt::modpow` directly (200-bit modulus, `10^6` exponent): **1140.6 ns vs
  1129.4 ns** — 1% overhead, so the `BigUint` route is not a performance argument against
  itself. But it is a *design* cost (sign plumbing, two code paths) for a feature the app does
  not have. **Do not build it now.**
- `BigUint::mulm` is 22% slower than raw `(a*b) % m` (155.5 vs 127.2 ns) because it reduces
  both operands first and then attempts a `usize` fast path. `BigUint::powm` is
  `BigUint::modpow` verbatim, so it is free of that overhead (2959.1 vs 2912.2 ns).

---

## 5. Type-system and API quality

### Current abstraction

```rust
fn mod_mul(a: i128, b: i128, n: i128) -> i128
```

Three bare `i128`s. Every invalid state is representable: `n = 0`, `n < 0`, `a` and `b` in
any range, and — critically — **no compiler-enforced relationship between the modulus used
for the reduction and the modulus the caller believes is in force.** Nothing stops
`mod_add(x, y, 5)` from being written where the surrounding context is `mod 7`. The only
thing preventing an accidental mixing-of-moduli bug is that the modulus is threaded by hand
through `eval_binary_op`.

`galois.rs::GFPrime` is the one place a real abstraction exists — it carries `value` and `p`
together and rejects operations across different `p`. It is correct, and it is *not* used by
the parser/evaluator, which is where mixing would actually happen.

### `num-modular` abstraction

`ModularInteger` (`ReducedInt<T, R>`) does encode modulus compatibility: `Add`/`Sub`/`Mul`/
`Neg` are implemented on `ReducedInt<T, R>`, so operands from two different moduli have
**different types** and the compiler rejects the mix. That is a genuine improvement over
three loose `i128`s, and it is the strongest argument in `num-modular`'s favour.

### But it is the wrong abstraction *for this crate*

1. **`ModularInteger` is still unsigned-only.** `ReducedInt<T, R>` over `i128` does not
   exist. calc-flut-rs's domain is signed, its parser produces negative literals, its `%` is a
   signed operation, and `mod_reduce` is defined for negative `n`. Adopting `ModularInteger`
   means either abandoning signedness at the API boundary (a breaking change to every
   caller) or keeping a signed shim *underneath* a type that cannot represent it — at which
   point the type safety is decorative.
2. **The evaluator is a tree walk over `ModExpr`, not a straight-line kernel.** It has no
   single fixed modulus to hoist; the modulus is a per-node `Option<i128>` that can change
   mid-expression (`PowMod(a, b, m)`, `Inv(a, m)`, `Modulo(a, b)` all carry their own).
   Converting to `MontgomeryInt` per node would dominate the cost — measured in §7.
3. **`ModularInteger::new` panics on `m == 0`** and there is no `TryFrom`. For a parser fed
   user keystrokes, a panic is not an acceptable failure mode, and `AGENTS.md` forbids
   `unwrap`/`expect`/`panic!` outside tests.
4. **The boundary would have to change shape anyway.** `mod_pow` returns
   `Result<i128, ModError>`, `mod_inv` returns `Result`, and callers pattern-match on the
   error variants. `ModularInteger` returns values and panics. A wrapper is unavoidable
   regardless — so the question is only whether the wrapper is *meaningful*.
5. **It would not encode what actually matters.** The real invariant here is
   "every operation reports the modulus it used, and non-invertible division is refused" —
   a *result-reporting* concern, which `ModularInteger` says nothing about. `ModResult::modulus_used`
   already carries that.

### Recommendation on type safety

**Do not adopt `ModularInteger`.** Adopt the *algorithms*, keep the signed `i128` signature,
and get type safety where it is actually cheap and actually missing: make the adapter the
only place a residue is produced, make its zero/negative-modulus contract explicit and
tested, and keep `GFPrime` as the type-safe island it already is. Add a `Modulus`-carrying
newtype only if a second fixed-modulus kernel ever appears — it does not today.

`num-modular` is a **better numeric kernel**, not a better **domain model**. Treating it as
the latter is the mistake this audit is written to prevent.

---

## 6. Architecture decision

**Option C (hybrid), implemented through Option B's shape.**

```
 ModExpr evaluator / parser / bridge          (unchanged, i128, signed, Result-based)
        ↓
 mod_arith::{mod_reduce, mod_add, mod_sub, mod_mul, mod_neg, mod_pow, mod_inv, mod_div}
        ↓                                    ← the adapter: the ONLY place that knows
 ┌────────────────────────────────────┐          about num-modular, width dispatch, and
 │ i128 → u128/u64 canonical form     │          the zero/negative-modulus contract
 │ num_modular::{addm, subm, mulm,    │
 │               negm, powm, invm}    │
 │ → u128, or u64 when |n| ≤ 2^64−1  │
 └────────────────────────────────────┘
        ↓
 num_modular 0.6.5  (features = ["num-bigint"], default-features = false)

 UNCHANGED, because num-modular has no equivalent:
   number_theory_ext  (factorisation, φ, order, primitive roots, units, congruence, dlog)
   quadratic::sqrt_mod (Tonelli–Shanks)  —  src/lib.rs: // TODO: Modular sqrt
   number_theory::crt                   —  src/lib.rs: // TODO: … and crt
   ring_analysis, cayley, galois, structure_parser
   is_prime's witness/trial-division structure (only its powm inner loop is replaced)
```

Why C over pure B: there is no "partially migrated" state to defend against, because
`num-modular`'s overlap *is* the hot path. Six functions route through it; the other ~20
functions never would have. A pure B wrapper around a subset is exactly a C hybrid, and
naming it B would obscure that.

Why C over A (direct replacement): A is impossible — zero modulus, negative modulus and
signedness are all load-bearing, and `sqrt_mod`/CRT/dlog do not exist upstream.

Why C over D: D would mean keeping a kernel that returns wrong answers for 48% of moduli
above `2^63.5` in a release build with overflow-checks off. That violates
`AGENTS.md` → Correctness outright, and the "no silent precision loss" rule. D is not on
the table.

---

## 7. Performance results

Host: x86_64-unknown-linux-gnu, `--release`, operands varied per iteration to defeat
loop-invariant hoisting, `std::hint::black_box` on results. The first benchmark pass was
discarded because constant inputs let LLVM hoist the computation out (0.2 ns/op for a
128-bit multiply is not real); every number below is from the corrected harness.

### 7.1 Single modular multiplication

| modulus | calc-flut `mod_mul` | `u128 mulm` | `u64 mulm` | `MontgomeryInt<u64>` |
|---|---|---|---|---|
| 30-bit | 6.2 ns | 7.6 ns | 7.5 ns | **2.7 ns** (pre-converted) |
| 126-bit | 16.4 ns *(wrong value)* | 29.5 ns | n/a | **19.9 ns** (pre-converted) |

`u64` is as fast as the current `i128` code for small moduli; `u128` costs ~20% more at
126 bits because `u128::mulm` attempts `checked_mul` first and then falls into a 256-bit
multiply for the common full-width case.

### 7.2 Modular exponentiation — the calculator's live preview path

30-bit modulus, 50-bit exponent:

| | ns/op | vs. current |
|---|---|---|
| calc-flut `mod_pow` | 557.3 | — |
| `num-modular` `u128 powm` | 936.0 | **1.68× slower** |
| `num-modular` `u64 powm` | **185.3** | **3.0× faster** |
| `num-modular` `MontgomeryInt<u64> pow` | **153.0** | 3.6× faster |
| `BigInt::modpow` (num-bigint only) | 1191.0 | 2.1× slower |

**This is the single most important performance finding, and it is why width dispatch is
mandatory.** `u128::powm` routes through `Vanilla<u128>::pow`, which uses
`udouble::widening_mul` (a full 256-bit multiply) on *every* step, whereas `u64::powm` gets
a 128-bit multiply for free. Adopting `num-modular` with a naive `u128`-only adapter would
have made the calculator's keypress preview **68% slower**. With the `u64` fast path taken
whenever `|n| ≤ 2^64 − 1` — which covers every realistic calculator entry — it becomes 3×
faster *and* correct.

### 7.3 Modular inverse

| | ns/op |
|---|---|
| calc-flut `mod_inv` | 62.9 |
| `u128 invm` | 112.8 |
| `u64 invm` | **88.0** |

Same story: `u64` is the right default, `u128` is a ~1.8× regression. The bridge calls
`mod_inv` at most once per unit in a ring analysis, bounded by a 10,000-element limit, so
this is not on any latency-sensitive path.

### 7.4 Repeated multiplication under one fixed modulus

64 chained multiplications, 30-bit modulus:

| | ns/op |
|---|---|
| calc-flut | 552.9 |
| `u64 mulm` | **184.0** |
| `MontgomeryInt<u64>`, modulus hoisted | 172.9 |

**Montgomery is not worth it.** With the modulus hoisted and all 64 operands pre-converted,
Montgomery buys 6% over plain `u64 mulm`. In the real evaluator nothing is pre-converted —
`mod_mul` is called with fresh `i128`s from the tree walk — and the per-operand
`convert()` would dominate. This is the concrete evidence for the §3.4 verdict: *do not
introduce `MontgomeryInt`*. It is a 3% win in a synthetic kernel the app does not have, in
exchange for an odd-modulus restriction, a precomputation obligation, and conversions.

### 7.5 `BigUint` (200-bit modulus)

| | ns/op |
|---|---|
| `BigUint mulm` | 155.5 |
| raw `(a·b) % m` | 127.2 |
| `BigUint powm` (`10^6` exponent) | 2959.1 |
| `BigInt::modpow` equivalent | 2912.2 |
| `BigUint invm` | 12042.3 |
| `absm` → `BigUint powm` (signed route) | 1140.6 vs `BigInt::modpow` 1129.4 |

Not on any current path (`modular_arithmetic/` is `i128`-only). Recorded for the day a
`BigUint` domain is added: `powm` is free (it *is* `BigUint::modpow`), `mulm` costs 22%, and
the signed route costs ~1%.

---

## 8. Test results

### 8.1 The regression-protection gap

`rust/src/tests/modular_arithmetic_tests.rs` is **not declared in `rust/src/tests/mod.rs`**.
It is dead code. Verified: `rg -n "modular_arithmetic_tests" src/` returns nothing, and
`cargo test` reports 130 tests, none of them modular. Its 3 tests cover
`analyze_structure` output shape and no numeric function.

This is the direct cause of §4.7 surviving. **Registering that file is a prerequisite for
the migration, not an optional extra** — the migration's safety argument rests on a
differential suite, and today there isn't one.

### 8.2 Differential run

Two builds of the same crate from the same commit, differing only in `mod_arith.rs`:

| | tests | result |
|---|---|---|
| pristine (current `i128` implementation) | 133 | **133 passed, 0 failed** |
| num-modular-backed adapter | 138 | **138 passed, 0 failed** |

The 133 are the same 133 (130 pre-existing + the 3 previously-orphaned ones, now
registered). **Zero behavioural regressions.**

The 5 additional tests are the differential suite, all passing:

1. `randomized_against_exact_bigint` — 200,000 cases, moduli 1–127 bits, checked against
   exact `BigInt` for `mod_reduce`, `mod_add`, `mod_sub`, `mod_mul`, `mod_neg`, `mod_pow`,
   plus the inverse identity `a · inv(a) ≡ 1 (mod n)` and a "refused only when
   `gcd(a,n) ≠ 1`" check. **All pass.** Cross-checks mathematical identities, not the old
   implementation.
2. `the_overflow_bug_is_gone` — pins `1000000007^1000000 mod 18446744073709551617` to the
   exact value. **Passes**; the old implementation fails it.
3. `mersenne_prime_is_recognised` — `is_prime(2^127−1) == true`, `is_prime(2^61−1) == true`,
   `is_prime(2^127−3) == false`. **Passes**; the old implementation fails the first.
4. `zero_modulus_convention_is_preserved` — pins all seven zero-modulus behaviours.
5. `negative_modulus_behaviour_is_preserved` — pins `6 mod -5 == 1`, `-6 mod -5 == 4`,
   `inv(3,-7) == 5`, `-1 mod 5 == 4`, `-6 mod 5 == 4`.

`cargo clippy --lib --all-targets`: pristine = 1 lib warning + 3 test warnings; adapter = 1
lib warning + 6 test warnings, the extra 3 all in the *new test* code (`assert_eq!` with a
literal bool, a redundant closure). **No clippy finding inside `mod_arith.rs`.**

### 8.3 Cross-checks against independent references

Not "old vs new" comparisons:

| Check | Cases | Agreement |
|---|---|---|
| Jacobi symbol, calc-flut vs `num-modular`, 200,000 random odd moduli | 200,000 | 200,000 |
| Jacobi symbol, calc-flut vs Euler-criterion reference, 20 primes × 3,000 signed `a` | 60,000 | 60,000 |
| Legendre symbol, calc-flut vs `num-modular`, 21 primes × 40 signed `a` | 840 | 840 |
| Legendre symbol, calc-flut vs Euler-criterion reference | 840 | 840 |
| `mod_reduce` vs `a.rem_euclid(\|n\|)` | 4,400,600 | 4,400,600 |
| `mod_reduce` vs `i128::absm` (n>0) | 2,000,000 | 2,000,000 |
| `mod_mul`/`powm` vs exact `BigInt` | 400,000 | `num-modular` 400,000; calc-flut 207,916 |
| inverse identity `a·inv(a) ≡ 1` | 400,000 | 400,000 |

One deliberate non-comparison: my first Jacobi reference disagreed with calc-flut on 37,843
of 200,000 cases. Investigation showed the **reference** was wrong — its composite-modulus
fallback returned `1` for non-residues. The cross-check was rerun on primes only, where it
agrees 60,000/60,000. Recorded here because a differential harness that reports a
disagreement is only useful if the disagreement is attributed correctly.

---

## 9. Dependency impact

### 9.1 Graph

`Cargo.lock` delta, measured by adding the dependency and letting Cargo resolve minimally:

```diff
 [[package]]
 name = "calc_flut_core"
 dependencies = [
   …
+  "num-modular",
   …
 ]
 
+[[package]]
+name = "num-modular"
+version = "0.6.5"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+checksum = "bd8e500409e6cd603b03e477c26a6caecdc27ac58979a53e881c75eafc079f44"
+dependencies = [
+ "num-bigint",
+ "num-integer",
+ "num-traits",
+]
```

**Exactly one new package enters the graph.** Zero new transitive packages. Zero version
bumps. Zero feature-unification changes.

- `num-bigint ^0.4.3` → resolves to the existing **0.4.6** ✅
- `num-integer ^0.1.44` → resolves to the existing **0.1.46** ✅
- `num-traits ^0.2.14` → resolves to the existing **0.2.19** ✅

`num-rational`, `num-complex`, `bigdecimal` and `symplex` are untouched. The `num-modular`
dependency is a strict no-op on the existing `num-*` set.

### 9.2 Features

```toml
num-modular = { version = "0.6.5", default-features = false, features = ["num-bigint"] }
```

- `std` **not** enabled → stays `no_std`, no allocator or platform requirement imposed.
- `num-traits` **not** enabled directly: the `num-bigint` feature already pulls it, and
  `Vanilla<BigUint>` requires `all(feature = "num-bigint", feature = "num-traits")`. Naming
  it separately would be redundant and would obscure that the gate is already satisfied.
- `num-bigint` is required. Without it there is no `BigUint` backend at all.

### 9.3 Binary size — Android aarch64, release, LTO, `opt-level = "z"`, stripped

| artifact | before | after | delta |
|---|---|---|---|
| `libcalc_flut_core.a` (staticlib) | 16,197,770 | 16,202,722 | **+4,952 B (+0.031%)** |
| `libcalc_flut_core.so` (cdylib) | 2,125,816 | 2,128,288 | **+2,472 B (+0.116%)** |

Negligible. LTO plus `opt-level = "z"` collapses the adapter; only the `u64`/`u128` paths
actually monomorphise, since the width dispatch is a runtime `if`.

---

## 10. Android and portability audit

| Check | Result |
|---|---|
| `cargo build --release --target aarch64-linux-android` | ✅ succeeds |
| Linker | NDK `aarch64-linux-android24-clang`; no `libstdc++`, no C++ runtime |
| `no_std` | ✅ `num-modular` is `#![no_std]`; `std` feature not enabled |
| Allocator requirement | ✅ none — `u128` widening uses the `u128` primitive, not a big-int scratch buffer |
| Architecture-specific code | ✅ none. `src/word.rs` branches only on `target_pointer_width` (16/32/64) for the `usize` impls; `src/double.rs` has no `cfg(target_arch)` and no `asm!`. No x86 intrinsics, no carry intrinsics. |
| Integer-width assumptions | ✅ `u128` throughout; `udouble` is defined on `u128` (`umax`). Works identically on ARM64, where `u128` is a compiler-synthesised pair rather than hardware. |
| Endianness | ✅ none — no `to_ne_bytes` in any arithmetic path |
| `panic = "abort"` interaction | ⚠️ **the important one.** The release profile aborts on panic. `num-modular` panics on a zero modulus. An abort on Android is a process kill, not a recoverable error. This makes the adapter's zero-modulus guard **mandatory**, not defensive. |
| FFI safety | ✅ no new `extern "C"`, no `unsafe` in `num-modular`, no FFI boundary touched |
| Other targets | ✅ `wasm32-unknown-unknown` unaffected — `default-features = false` and no `std`; `num-bigint` is already a direct dependency and already compiles for wasm |

One environment note, recorded because it cost time and would mislead a future reader: the
first Android `cdylib` link failed with
`libdart_sys-*.rlib(dart_api_dl.o) is incompatible with aarch64linux`. That is the
`dart-sys` **build script** compiling for the host because `CC_aarch64_linux_android` was
unset — it reproduces identically on the pristine tree and is unrelated to `num-modular`.
Setting the target `CC`/`AR` alongside the linker fixes it.

---

## 11. What stays custom, and why

| Kept | Reason |
|---|---|
| `mod_reduce`'s zero- and negative-modulus contract | `num-modular` panics on `m = 0` and has no negative modulus. Observable behaviour, must be preserved exactly. |
| Negative exponents in `mod_pow` | `num-modular` exponents are unsigned. `ModExpr::Power` under a context modulus supports `-1`. |
| `mod_pow`'s `modulus ≤ 0 → Err` and `modulus == 1 → 0` | Domain contract, and it keeps `Vanilla::new`'s `assert!(m > 0)` from ever being the rejection path. |
| `mod_inv`'s `ModError::InverseDoesNotExist` message text | `invm` returns `Option`; the bridge and the UI show this string. |
| `is_prime`'s trial division + 12-witness Miller–Rabin | No primality test in `num-modular`. Only its `powm` inner loop is replaced. |
| `legendre_symbol`'s `is_prime` gate | `checked_legendre` is documented as not primality-checking. The gate must stay for correct user-facing rejections. |
| `sqrt_mod` (Tonelli–Shanks) | `src/lib.rs`: `// TODO: Modular sqrt`. **No library equivalent exists.** |
| `crt` | `src/lib.rs`: `// TODO: … and crt`. |
| `discrete_log` (BSGS) | `src/lib.rs`: `// TODO: Discrete log aka index`. |
| `prime_factorization`, `euler_totient`, `element_order`, `primitive_roots`, `unit_group`, `solve_linear_congruence` | Not in the crate. They *consume* the adapter and so inherit the overflow fix. |
| `ring_analysis`, `cayley`, `galois`, `structure_parser` | Domain logic, not modular arithmetic. |
| `calculator/rational.rs::CalcValue::modulo` | A separate `BigInt` path on the `%` key. Not part of this module, and not routed through `num-modular`. Left alone deliberately — see §12. |

**New capability available, not required:** `ModularSymbols::kronecker` has no calc-flut-rs
equivalent. Adopting it is a feature addition, out of scope for a migration.

---

## 12. Migration risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | The zero-modulus panic becomes an **abort** under `panic = "abort"` | **Critical** | Adapter guards `n == 0` before every call; `zero_modulus_convention_is_preserved` pins all 7 behaviours. Verified. |
| 2 | Silent residue-semantics change for negative moduli | **Critical** | `unsigned_abs()` in the adapter; `negative_modulus_behaviour_is_preserved` pins it. Verified. |
| 3 | A naive `u128`-only adapter makes the calculator's live preview **68% slower** | **High** | Width dispatch on `\|n\| ≤ u64::MAX`. Measured 3.0× *faster* instead. |
| 4 | Negative exponents silently lost | High | `uexp` is `u128`; the sign branch stays explicit. `mod_pow(2,-1,7) == 4` pinned. |
| 5 | `checked_legendre` accepted for a non-prime modulus | High | Keep the `is_prime` gate; test `legendre_symbol` on composites. |
| 6 | The differential suite is trusted while `modular_arithmetic_tests.rs` is still orphaned | **High** | Register the module in `tests/mod.rs` **first**, in its own commit, and watch it fail on the current code. That failure *is* the bug report. |
| 7 | `is_prime` behaviour changes for large inputs | Medium | This is a **fix**, not a regression — `2^127−1` currently returns `false`. Call it out in the commit message. |
| 8 | `MontgomeryInt` gets added "for performance" | Medium | §7.4: 3% in a synthetic kernel, per-operand conversion cost in the real one. Recorded as a rejected option. |
| 9 | Someone later reaches for `BigInt` moduli | Medium | `num-modular` has no `BigInt` arithmetic — a compile error, not a silent wrong answer. §11 says to keep it `i128`. |
| 10 | `num-modular` MSRV / edition | Low | `rust-version = "1.65"`, `edition = "2018"`. The crate is `edition = "2024"`, rustc 1.96. Ample headroom. |
| 11 | `mod_reduce(5, 0) == 5` and `mod_mul(5,3,0) == 15` are arguably wrong | Low | **Out of scope.** Preserved verbatim, documented in §4.1, and filed as a separate follow-up. Changing them in a migration commit would confound the differential. |
| 12 | FRB codegen churn | Low | `rust/src/bridge/` signatures are untouched — the adapter is internal. `flutter_rust_bridge_codegen generate` is not required. |

---

## 13. Final recommendation

**Migrate. Option C (hybrid) through an Option-B-shaped `i128` adapter. This is not a
dependency-reduction exercise; it is a correctness fix that happens to arrive as one.**

The reasoning, in order of weight:

1. **The current implementation is wrong, demonstrably and in a release build.**
   `mod_mul` wraps silently for 48% of moduli above `2^63.5`, and the numeric calculator
   prints a wrong answer for `1000000007^1000000 % 18446744073709551617` with no error. The
   release profile turns an overflow into a plausible-looking number. This alone violates
   `AGENTS.md` → Correctness ("never silently lose precision, overflow, truncate, or
   approximate"), and it is reachable from a keystroke.

2. **`num-modular` is correct where the current code is not.** 400,000 randomised cases
   against exact `BigInt`: zero divergences for `mulm`, versus 192,084 for `mod_mul`. Its
   `checked_mul`-then-`widening_mul` structure is precisely the property the current code
   lacks.

3. **The cost is genuinely near zero, and I measured every axis.** One new package with zero
   new transitive dependencies and zero version bumps. +0.03% on the Android staticlib.
   `no_std`, no arch-specific code, no FFI surface, no allocator requirement. 133/133
   existing tests pass unchanged.

4. **The performance story is a net win, but only with width dispatch.** A naive `u128`
   adapter is 1.68× slower on `mod_pow` — the calculator's keypress-latency path, which
   `AGENTS.md` singles out. With the `u64` fast path it is 3.0× faster *and* correct. The
   dispatch is four lines and is not optional.

5. **A wrapper is mandatory anyway.** Zero modulus panics, negative moduli do not exist, and
   signedness is absent upstream. Every one of those is load-bearing here. The wrapper is
   not overhead imposed by the library; it is the contract `AGENTS.md` already demands. The
   thing to avoid is a wrapper that merely renames methods — this one owns the
   zero/negative/width policy, which is real content.

6. **`ModularInteger` is not the answer to the type-safety question.** It genuinely prevents
   mixing moduli, but it is unsigned-only, so it cannot represent this domain; it panics on
   `m == 0` where a parser needs a `Result`; and a tree-walking evaluator with a per-node
   `Option<i128>` modulus has no fixed modulus to hoist. Keeping `GFPrime` as the
   type-safe island, and confining the adapter to the residue policy, is the honest version
   of this. Over-engineering the calculator around `ModularInteger` would make the
   architecture worse, which the brief explicitly warns against.

7. **The overlap is total, so there is no half-migrated state.** Everything `num-modular`
   provides is the hot path; everything else it never would have provided. Six functions
   route through the adapter; ~20 stay exactly as they are. That is a diff a reviewer can
   hold in their head.

**Two things must happen before or with the first code change, in this order:**

1. **Register `rust/src/tests/modular_arithmetic_tests.rs` in `rust/src/tests/mod.rs`.**
   Today it is dead code and its three tests have never run. Do this first, alone, and expect
   the suite to go green — then add the differential tests and watch
   `the_overflow_bug_is_gone` and `mersenne_prime_is_recognised` **fail against the current
   code**. That failure is the bug report, and it should be in the history before the fix
   lands, not after.

2. **Add the width dispatch on the first commit of the adapter**, not as a follow-up. A
   correct-but-slower `mod_pow` on the keypress path is a regression even though every test
   passes.

**What I would not do:** adopt `MontgomeryInt` (3% in a kernel the app does not have, at the
cost of an odd-modulus restriction and per-operand conversions); add a `BigUint` domain
because `num-modular` supports it (nothing in the app needs it, and the sign plumbing would
be a second code path for no user); or "fix" `mod_reduce(5, 0) == 5` in the same commit
(it is wrong, it is observable, and bundling it would make the differential unreadable —
file it separately).

---

## 14. What was implemented

### 14.1 The change

| File | Change |
|---|---|
| `rust/Cargo.toml` | `num-modular = { version = "0.6.5", default-features = false, features = ["num-bigint"] }` |
| `rust/Cargo.lock` | +12 lines, one new package, zero version bumps |
| `rust/src/modular_arithmetic/mod_arith.rs` | Rewritten as the adapter: `mod_reduce`, `mod_add`, `mod_sub`, `mod_mul`, `mod_neg`, `mod_pow`, `mod_inv`, `mod_div`, `is_prime` |
| `rust/src/modular_arithmetic/quadratic.rs` | `legendre_symbol` and `jacobi_symbol` now delegate to `ModularSymbols`; the `is_prime` gate stays |
| `rust/src/tests/mod.rs` | Registered `modular_arithmetic_tests` (previously orphaned) and `modular_kernel_tests` |
| `rust/src/tests/modular_kernel_tests.rs` | New. 36 tests over the numeric kernel |

`rust/src/bridge/` is untouched, so no `flutter_rust_bridge_codegen generate` was needed and
no Dart binding changed. The audit's Option C diagram holds: everything `num-modular`
provides moved, and `sqrt_mod` (Tonelli–Shanks), `crt`, `discrete_log`, `prime_factorization`,
`euler_totient`, `element_order`, `primitive_roots`, `unit_group`, `ring_analysis`, `cayley`,
`galois` and `structure_parser` are all untouched.

### 14.2 Test results, before and after

The registration and the new tests went in first, on their own, and were run against the
unmigrated kernel. That run is the bug report:

```
test result: FAILED. 158 passed; 9 failed
```

All nine failures had the same cause — `mod_arith.rs:28`, `attempt to multiply with overflow` —
in `an_inverse_paired_with_its_value_is_the_identity`,
`multiplication_does_not_overflow_above_sixty_four_bits`, `power_is_exact_above_sixty_four_bits`,
`powers_compose`, `primality_recognises_the_known_mersenne_primes`,
`primality_agrees_with_an_exact_miller_rabin`, `randomised_against_exact_arithmetic`,
`reducing_the_operands_does_not_change_the_result` and `squaring_is_multiplication_by_itself`.

After the migration:

| Suite | Result |
|---|---|
| `cargo test` (Rust) | **169 passed, 0 failed** |
| `flutter test` | **204 passed, 0 failed** |
| `flutter analyze` | No issues found |
| `cargo clippy --lib --all-targets` | 4 warnings, all pre-existing at HEAD (1 `redundant closure` in `symbolic/evaluator.rs`, 3 `assert_eq!` with a literal bool) |
| `cargo fmt --check` (changed files) | clean |
| `cargo build --release` for `aarch64-linux-android`, `armv7-linux-androideabi`, `i686-linux-android`, `wasm32-unknown-unknown` | all four succeed |

**One defect the migration itself introduced, caught by the new tests.** The first version of
`mod_pow` narrowed to the `u64` exponent whenever the modulus fitted, ignoring the exponent's
width. A 100-bit exponent under a 30-bit modulus therefore came back as `2^7 == 128` instead of
the correct value. `power_handles_an_exponent_wider_than_the_modulus` failed immediately. The
fix is `powm_in`, which requires *both* the modulus and the exponent to fit. It is now pinned
by `power_keeps_an_exponent_wider_than_64_bits`, which includes exponents whose low 64 bits are
zero — the case truncation turns into `2^0 == 1`.

This is the argument for §8's insistence on differential testing rather than porting the old
test suite: a green suite over old tests would have shipped that bug.

### 14.3 Measured performance, old kernel versus migrated adapter

Both kernels compiled into one binary from the same commit, operands varying per iteration,
`--release`, x86_64.

| Operation | old (HEAD) | new | |
|---|---|---|---|
| `mod_pow`, 30-bit modulus, ~50-bit exponent | 395.3 ns | **199.1 ns** | **1.99× faster** |
| `mod_pow`, 126-bit modulus | 1107.4 ns *(wrong result)* | 1086.1 ns | 1.02× faster, and exact |
| `mod_mul`, 30-bit modulus | 6.0 ns | 6.0 ns | unchanged |
| `is_prime`, 64-bit prime | 4369.3 ns | **1354.2 ns** | **3.23× faster** |
| `mod_inv`, 30-bit modulus | 76.4 ns | 135.4 ns | **0.56× — 1.8× slower** |

`mod_pow` is the numeric calculator's live preview (`calculator/evaluator/mod.rs:90`) and the
modular workspace's per-keystroke preview, so that 1.99× is on a latency path. `is_prime`
reached 3.23× only after `powm_in` was factored out and reused in the Miller–Rabin loop;
the first version, which called `u128::powm` directly there, measured 0.60× — a 1.7×
*regression* that the audit's §7.2 had not anticipated, because it only ever benchmarked
`mod_pow` and not `is_prime`. Sharing the width dispatch fixed it.

**`mod_inv` is a real 1.8× regression and is being kept.** `num-modular`'s `invm` keeps its
Bézout coefficient inside the loop by way of `subm`/`mulm`, so it does two modular operations
per iteration where the old hand-rolled `extended_gcd` did plain `i128` arithmetic. The old one
was faster and *also* overflow-prone on wide inputs, which is the same defect class this
migration exists to remove. The cost is not observable:

- `modular_evaluate` is `#[frb(sync)]` and driven from a text field, so a 59 ns difference sits
  inside a parse, an AST walk and a string format measured in microseconds.
- The heaviest caller is `analyze_structure`, which takes at most 10,000 inverses and renders
  them as a table: 1.35 ms versus 0.76 ms, against an `O(n log n)` enumeration and the string
  formatting that dominates it.
- `is_prime`, called on the same paths as a gate, got 3.2× faster, which more than pays for it.

Writing a division-safe hand-rolled extended Euclid to recover 59 ns would be exactly the
"temporary fix when a root-cause fix is possible" that `AGENTS.md` rules out.

### 14.4 Measured dependency and size impact

`Cargo.lock` gained 12 lines and one package. `num-bigint` 0.4.6, `num-integer` 0.1.46 and
`num-traits` 0.2.19 were all already in the graph and none moved. `std` is off; `num-bigint`
is on, and it is what pulls in the other two, so neither is named separately.

Android aarch64, release, LTO, `opt-level = "z"`, stripped:

| artifact | before | after | delta |
|---|---|---|---|
| `libcalc_flut_core.a` | 16,197,770 | 16,200,586 | **+2,816 B (+0.017%)** |
| `libcalc_flut_core.so` | 2,125,816 | 2,128,072 | **+2,256 B (+0.106%)** |

All four deployment targets build. `num-modular` is `#![no_std]` with no `cfg(target_arch)`
and no `asm!`, so there is nothing platform-specific to audit.

### 14.5 Where §7 was wrong

Recorded because the audit is meant to be evidence, and this part did not hold up.

- **§7.2 predicted `u64` `powm` at 185 ns against 557 ns and called it "3.0× faster".** The
  real gap is 395 ns to 199 ns, or 1.99×. The direction held; the margin was overstated because
  the audit benchmarked the library directly rather than the adapter, and the adapter adds a
  residue conversion and a width branch per call.
- **§7.2 and §7.3 did not cover `is_prime` at all**, and so missed the `u128::powm` regression
  in its Miller–Rabin loop. A kernel is only as fast as the code that calls it.
- **§7.1 reported `MontgomeryInt<u64>` at 2.7 ns and §7.4 at a 6% win over plain `u64 mulm`.**
  Neither figure survived into the implementation, and the decision to skip `MontgomeryInt` held
  up: nothing in the migrated kernel uses a fixed modulus across operations.
- **§4.1 listed `mod_neg(5, 0)` among the zero-modulus behaviours without checking which sign
  it produced.** The migrated branch initially returned `5`; the original returns `-5`. The new
  test suite caught it on the first run. The branch is now `a.wrapping_neg()`, which matches the
  original in release and no longer overflows in debug.

### 14.6 Still outstanding

Not part of this migration, and not regressions:

- **`prime_factorization` is `O(√n)` by trial division.** For a modulus above about `2^63` that
  is billions of iterations, so `element_order`, `primitive_roots` and `euler_totient` will hang
  on a large modulus. Pre-existing, unchanged, and independent of the kernel — but it is the
  next thing that will bite a user who types a 20-digit prime.
- **`mod_reduce(5, 0) == 5` and `mod_mul(5, 3, 0) == 15`** are wrong as mathematics. Preserved
  verbatim, pinned by `the_zero_modulus_contract_is_unchanged`, and deliberately not fixed here:
  they are observable through the workspace, and bundling the change would have made the
  differential unreadable.
- **`ModularSymbols::kronecker`** is available and unused. It is a feature, not a migration.
