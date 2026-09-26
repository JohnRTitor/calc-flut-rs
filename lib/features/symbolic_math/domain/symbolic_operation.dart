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
  bool get isForm => this != SymbolicOperation.differentiate;

  /// Whether this operation needs to be told which variable to act on.
  ///
  /// Both factoring and differentiating are defined relative to a variable,
  /// and a constant has neither.
  bool get requiresVariable =>
      this == SymbolicOperation.factor || this == SymbolicOperation.differentiate;

  /// The operations offered by the Algebra workspace, in presentation order.
  static const List<SymbolicOperation> algebraOperations = [
    SymbolicOperation.simplify,
    SymbolicOperation.expand,
    SymbolicOperation.factor,
  ];

  /// The operations offered by the Calculus workspace, in presentation order.
  ///
  /// Differentiation needs a variable and a single expression, so unlike
  /// Algebra this list starts at exactly one.
  static const List<SymbolicOperation> calculusOperations = [
    SymbolicOperation.differentiate,
  ];
}
