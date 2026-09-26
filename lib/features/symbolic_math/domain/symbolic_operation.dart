/// The symbolic operations a workspace can run.
///
/// Lives at feature level rather than inside one screen's state, because more
/// than one tool offers a subset of these: Algebra offers the form operations,
/// Calculus offers the transforms. Each enum value also carries the name sent
/// to the Rust bridge, so a screen can never offer an action the backend would
/// reject as unknown.
enum SymbolicOperation {
  /// Rewrites the expression into an equivalent, canonical form.
  simplify(
    wireName: 'simplify',
    label: 'Simplify',
    formLabel: 'Simplified',
    description: 'Combine like terms and reduce to a canonical form',
  ),

  /// Multiplies out every product.
  expand(
    wireName: 'expand',
    label: 'Expand',
    formLabel: 'Expanded',
    description: 'Multiply out every product',
  ),

  /// Factorises over the integers, with respect to one variable.
  factor(
    wireName: 'factor',
    label: 'Factor',
    formLabel: 'Factored',
    description: 'Factorise over the integers, with respect to one variable',
  ),

  /// Differentiates with respect to one variable.
  differentiate(
    wireName: 'differentiate',
    label: 'Differentiate',
    formLabel: 'Derivative',
    description: 'Differentiate with respect to one variable',
  ),

  /// Finds an antiderivative with respect to one variable.
  ///
  /// The answer carries `+ C`, because an indefinite integral is only ever
  /// determined up to an additive constant and dropping it would present an
  /// incomplete answer as a complete one.
  integrate(
    wireName: 'integrate',
    label: 'Integrate',
    formLabel: 'Antiderivative',
    description: 'Find an antiderivative, up to an arbitrary constant',
  ),

  /// Evaluates the integral between two bounds.
  ///
  /// A separate operation from [integrate] rather than a variant of it, because
  /// the two answers differ in kind: an indefinite integral is a family of
  /// functions, while a definite one is a single exact value with no free
  /// parameter left in it, and therefore no `+ C`.
  integrateDefinite(
    wireName: 'integrate_definite',
    label: 'Integrate',
    formLabel: 'Definite integral',
    description: 'Evaluate the integral between a lower and an upper bound',
  );

  /// The name accepted by the Rust bridge.
  final String wireName;

  /// The chip label that triggers this operation.
  final String label;

  /// The name of this operation's output, used for the alternate-form chips.
  final String formLabel;

  /// One-line explanation, used as the chip's tooltip.
  final String description;

  const SymbolicOperation({
    required this.wireName,
    required this.label,
    required this.formLabel,
    required this.description,
  });

  /// Whether this operation rewrites an expression into an equivalent one.
  ///
  /// A form operation's output can be offered as "another way of writing this".
  /// A transform's output is a *different expression* — the derivative of
  /// `x^2` is not another form of `x^2` — so it must never be listed among the
  /// forms of the expression the user typed.
  bool get isForm =>
      this != SymbolicOperation.differentiate &&
      this != SymbolicOperation.integrate &&
      this != SymbolicOperation.integrateDefinite;

  /// Whether this operation needs to be told which variable to act on.
  ///
  /// Factoring, differentiating and integrating are all defined relative to a
  /// variable, and a constant has none of them.
  bool get requiresVariable =>
      this == SymbolicOperation.factor ||
      this == SymbolicOperation.differentiate ||
      this == SymbolicOperation.integrate ||
      this == SymbolicOperation.integrateDefinite;

  /// Whether this operation needs lower and upper bounds.
  bool get requiresBounds => this == SymbolicOperation.integrateDefinite;

  /// Whether the answer is only determined up to an arbitrary constant.
  ///
  /// Only the indefinite integral. A definite one is a single value, so adding
  /// a constant to it would be nonsense rather than an omission.
  bool get isUpToAConstant => this == SymbolicOperation.integrate;

  /// The operations offered by the Algebra workspace, in presentation order.
  static const List<SymbolicOperation> algebraOperations = [
    SymbolicOperation.simplify,
    SymbolicOperation.expand,
    SymbolicOperation.factor,
  ];

  /// The operations offered by the Calculus workspace, in presentation order.
  ///
  /// Differentiation and integration need a variable, so unlike Algebra this
  /// list starts at operations that take one.
  static const List<SymbolicOperation> calculusOperations = [
    SymbolicOperation.differentiate,
    SymbolicOperation.integrate,
  ];
}

/// Which kind of integration the Calculus workspace is set up for.
///
/// The two are separate operations rather than one operation with an option,
/// so the action row shows exactly one `Integrate` chip and the qualifier
/// reports which kind produced the answer.
enum IntegrationMode {
  /// An antiderivative, up to an arbitrary constant.
  indefinite(SymbolicOperation.integrate, 'Indefinite'),

  /// The integral between a lower and an upper bound.
  definite(SymbolicOperation.integrateDefinite, 'Definite');

  /// The operation this mode runs.
  final SymbolicOperation operation;

  /// Short label for the mode switch.
  final String label;

  const IntegrationMode(this.operation, this.label);

  /// The operations the Calculus workspace offers in this mode.
  ///
  /// Differentiation is always available; only the flavour of integration
  /// changes, so it stays in both.
  static List<SymbolicOperation> operationsFor(IntegrationMode mode) => [
    SymbolicOperation.differentiate,
    mode.operation,
  ];
}
