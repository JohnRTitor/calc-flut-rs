use {
    crate::modular_arithmetic::{evaluator, parser},
    flutter_rust_bridge::frb,
};

/// Represents the result of a modular calculation
#[frb]
pub struct ModularResult {
    pub value: String,
    pub details: Option<String>,
    pub modulus_used: Option<String>,
    pub steps: Option<String>,
}

#[frb(sync)]
pub fn modular_evaluate(
    expression: String,
    context_modulus: Option<String>,
    mode: String,
    show_steps: bool,
) -> Result<ModularResult, String> {
    if expression.trim().is_empty() {
        return Ok(ModularResult {
            value: "0".to_string(),
            details: None,
            modulus_used: None,
            steps: None,
        });
    }

    let tokens = parser::tokenize(&expression).map_err(|e| e.to_string())?;
    let ast = parser::parse(&tokens).map_err(|e| e.to_string())?;

    let modulus_i128 = match context_modulus {
        Some(ref s) if !s.trim().is_empty() => Some(
            s.parse::<i128>()
                .map_err(|_| "Invalid context modulus".to_string())?,
        ),
        _ => None,
    };

    let struct_mode = match mode.to_lowercase().as_str() {
        "field" => evaluator::StructureMode::Field,
        "crt" => evaluator::StructureMode::Crt,
        _ => evaluator::StructureMode::Ring,
    };

    let result = evaluator::evaluate_mod_expr(&ast, modulus_i128, struct_mode, show_steps)
        .map_err(|e| e.to_string())?;

    Ok(ModularResult {
        value: result.value,
        details: result.details,
        modulus_used: result.modulus_used.map(|m| m.to_string()),
        steps: result.steps,
    })
}

#[frb]
pub struct InversePair {
    pub element: String,
    pub inverse: String,
}

#[frb]
pub struct ElementOrderPair {
    pub element: String,
    pub order: String,
}

#[frb]
pub struct CayleyTable {
    pub operation: String,
    pub headers: Vec<String>,
    pub rows: Vec<Vec<String>>,
}

#[frb]
pub struct StructureAnalysis {
    pub label: String,
    pub order: String,
    pub is_cyclic: bool,
    pub identity: String,
    pub elements: String,
    pub generators: Vec<String>,
    pub units_count: String,
    pub units: Vec<String>,
    pub zero_divisors_count: String,
    pub zero_divisors: Vec<String>,
    pub idempotents_count: String,
    pub idempotents: Vec<String>,
    pub nilpotents_count: String,
    pub nilpotents: Vec<String>,
    pub inverses: Vec<InversePair>,
    pub element_orders: Vec<ElementOrderPair>,
    pub cayley_table: Option<CayleyTable>,
    pub classification: String,
    pub is_truncated: bool,
}

#[frb]
pub struct StructureAnalysisResponse {
    pub success: bool,
    pub analysis: Option<StructureAnalysis>,
    pub error_message: Option<String>,
    pub suggestion: Option<String>,
    pub interpreted_as: Option<String>,
}

#[frb(sync)]
pub fn analyze_structure(
    structure_type: String,
    n: String,
) -> Result<StructureAnalysisResponse, String> {
    // 1. Parse Notation
    let parsed = match crate::modular_arithmetic::structure_parser::parse_structure_input(
        &n,
        &structure_type,
    ) {
        Ok(p) => p,
        Err(e) => {
            return Ok(StructureAnalysisResponse {
                success: false,
                analysis: None,
                error_message: Some(e),
                suggestion: None,
                interpreted_as: None,
            });
        }
    };

    // If there is a suggestion, we return it without running the analysis
    if let Some(suggestion) = parsed.suggestion {
        return Ok(StructureAnalysisResponse {
            success: false,
            analysis: None,
            error_message: None,
            suggestion: Some(suggestion),
            interpreted_as: None,
        });
    }

    let modulus = parsed.modulus;

    // 2. Math Validation
    if modulus <= 1 {
        return Ok(StructureAnalysisResponse {
            success: false,
            analysis: None,
            error_message: Some("Modulus must be > 1".to_string()),
            suggestion: None,
            interpreted_as: None,
        });
    }

    let limit = 10000;

    // 3. Analyze
    let analysis = match structure_type.to_lowercase().as_str() {
        "ring" => {
            let info = crate::modular_arithmetic::ring_analysis::ring_classify(modulus);
            let mut inverses = Vec::new();
            for &u in &info.units {
                if let Ok(inv) = crate::modular_arithmetic::mod_arith::mod_inv(u, modulus) {
                    inverses.push(InversePair {
                        element: u.to_string(),
                        inverse: inv.to_string(),
                    });
                }
            }

            let cayley = if modulus <= 25 {
                if let Ok(table) = crate::modular_arithmetic::cayley::addition_table(modulus) {
                    let headers = (0..modulus).map(|x| x.to_string()).collect();
                    let rows = table
                        .into_iter()
                        .map(|row| row.into_iter().map(|num| num.to_string()).collect())
                        .collect();
                    Some(CayleyTable {
                        operation: "+".to_string(),
                        headers,
                        rows,
                    })
                } else {
                    None
                }
            } else {
                None
            };

            StructureAnalysis {
                label: parsed.canonical_notation.clone(),
                order: format!("|{}| = {}", parsed.canonical_notation, modulus),
                is_cyclic: true, // Z_n is always cyclic under addition
                identity: "0".to_string(),
                elements: format!("{{0, 1, ..., {}}}", modulus - 1),
                generators: vec!["1".to_string()],
                units_count: info.units_count.to_string(),
                units: info.units.iter().map(|x| x.to_string()).collect(),
                zero_divisors_count: info.zero_divisors_count.to_string(),
                zero_divisors: info.zero_divisors.iter().map(|x| x.to_string()).collect(),
                idempotents_count: info.idempotents_count.to_string(),
                idempotents: info.idempotents.iter().map(|x| x.to_string()).collect(),
                nilpotents_count: info.nilpotents_count.to_string(),
                nilpotents: info.nilpotents.iter().map(|x| x.to_string()).collect(),
                inverses,
                element_orders: Vec::new(), // Too verbose for additive group
                cayley_table: cayley,
                classification: info.classification,
                is_truncated: info.is_truncated,
            }
        }
        "group" => {
            let units = crate::modular_arithmetic::number_theory_ext::unit_group(modulus);
            let generators = crate::modular_arithmetic::number_theory_ext::primitive_roots(modulus)
                .ok()
                .unwrap_or_default();

            let mut element_orders = Vec::new();
            if units.len() <= limit {
                for &u in &units {
                    if let Ok(ord) =
                        crate::modular_arithmetic::number_theory_ext::element_order(u, modulus)
                    {
                        element_orders.push(ElementOrderPair {
                            element: u.to_string(),
                            order: ord.to_string(),
                        });
                    }
                }
            }

            let mut inverses = Vec::new();
            if units.len() <= limit {
                for &u in &units {
                    if let Ok(inv) = crate::modular_arithmetic::mod_arith::mod_inv(u, modulus) {
                        inverses.push(InversePair {
                            element: u.to_string(),
                            inverse: inv.to_string(),
                        });
                    }
                }
            }

            let cayley = if units.len() <= 25 {
                if let Ok((_, table)) = crate::modular_arithmetic::cayley::unit_group_table(modulus)
                {
                    let headers = units.iter().map(|x| x.to_string()).collect();
                    let rows = table
                        .into_iter()
                        .map(|row| row.into_iter().map(|num| num.to_string()).collect())
                        .collect();
                    Some(CayleyTable {
                        operation: "*".to_string(),
                        headers,
                        rows,
                    })
                } else {
                    None
                }
            } else {
                None
            };

            let is_truncated = units.len() > limit;

            StructureAnalysis {
                label: parsed.canonical_notation.clone(),
                order: format!(
                    "|{}| = φ({}) = {}",
                    parsed.canonical_notation,
                    modulus,
                    units.len()
                ),
                is_cyclic: !generators.is_empty(),
                identity: "1".to_string(),
                elements: format!(
                    "{{{}}}",
                    units
                        .iter()
                        .map(|x| x.to_string())
                        .collect::<Vec<_>>()
                        .join(", ")
                ),
                generators: generators.iter().map(|x| x.to_string()).collect(),
                units_count: units.len().to_string(),
                units: Vec::new(), // Itself
                zero_divisors_count: "0".to_string(),
                zero_divisors: Vec::new(), // None in a group
                idempotents_count: "0".to_string(),
                idempotents: Vec::new(),
                nilpotents_count: "0".to_string(),
                nilpotents: Vec::new(),
                inverses,
                element_orders,
                cayley_table: cayley,
                classification: if !generators.is_empty() {
                    "Cyclic Group".to_string()
                } else {
                    "Abelian Group".to_string()
                },
                is_truncated,
            }
        }
        "field" => {
            // Check for math errors
            if !crate::modular_arithmetic::mod_arith::is_prime(modulus) {
                // Determine if it was parsed as an extension field originally
                let is_extension = parsed.canonical_notation.contains('^');
                let error_msg = if is_extension {
                    format!(
                        "{} requires a prime modulus in this version (extension fields not yet supported).",
                        parsed.canonical_notation
                    )
                } else {
                    format!(
                        "{} is not a field because {} is not prime.",
                        parsed.canonical_notation, modulus
                    )
                };

                return Ok(StructureAnalysisResponse {
                    success: false,
                    analysis: None,
                    error_message: Some(error_msg),
                    suggestion: None,
                    interpreted_as: None,
                });
            }

            let elements = format!("{{0, 1, ..., {}}}", modulus - 1);
            let generators = crate::modular_arithmetic::number_theory_ext::primitive_roots(modulus)
                .ok()
                .unwrap_or_default();

            StructureAnalysis {
                label: parsed.canonical_notation.clone(),
                order: format!("|{}| = {}", parsed.canonical_notation, modulus),
                is_cyclic: true, // Multiplicative group is cyclic
                identity: "0 (Add), 1 (Mul)".to_string(),
                elements,
                generators: generators.iter().map(|x| format!("{} (Mul)", x)).collect(),
                units_count: (modulus - 1).to_string(),
                units: Vec::new(),
                zero_divisors_count: "0".to_string(),
                zero_divisors: Vec::new(),
                idempotents_count: "2".to_string(),
                idempotents: vec!["0".to_string(), "1".to_string()],
                nilpotents_count: "1".to_string(),
                nilpotents: vec!["0".to_string()],
                inverses: Vec::new(),
                element_orders: Vec::new(),
                cayley_table: None, // Fields get too large fast, skip for field summary
                classification: "Finite Field (Galois Field)".to_string(),
                is_truncated: false,
            }
        }
        _ => {
            return Ok(StructureAnalysisResponse {
                success: false,
                analysis: None,
                error_message: Some(
                    "Invalid structure type. Use 'ring', 'group', or 'field'.".to_string(),
                ),
                suggestion: None,
                interpreted_as: None,
            });
        }
    };

    Ok(StructureAnalysisResponse {
        success: true,
        analysis: Some(analysis),
        error_message: None,
        suggestion: None,
        interpreted_as: parsed.interpreted_as,
    })
}
