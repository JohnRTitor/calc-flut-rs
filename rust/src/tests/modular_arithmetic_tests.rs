#[cfg(test)]
mod tests {
    use crate::bridge::modular_arithmetic::analyze_structure;

    #[test]
    fn test_ring_classification() {
        let res = analyze_structure("ring".to_string(), "12".to_string()).unwrap();
        let analysis = res.analysis.unwrap();
        assert_eq!(analysis.label, "Z_12");
        assert_eq!(analysis.order, "|Z_12| = 12");
        assert_eq!(analysis.is_cyclic, true);
        assert_eq!(analysis.units, vec!["1", "5", "7", "11"]);
        assert_eq!(
            analysis.zero_divisors,
            vec!["2", "3", "4", "6", "8", "9", "10"]
        );
        assert_eq!(analysis.idempotents, vec!["0", "1", "4", "9"]);
        assert_eq!(analysis.nilpotents, vec!["0", "6"]);
    }

    #[test]
    fn test_group_classification() {
        let res = analyze_structure("group".to_string(), "10".to_string()).unwrap();
        let analysis = res.analysis.unwrap();
        assert_eq!(analysis.label, "U(10)");
        assert_eq!(analysis.order, "|U(10)| = φ(10) = 4");
        assert_eq!(analysis.is_cyclic, true);
        assert_eq!(analysis.generators, vec!["3", "7"]);
    }

    #[test]
    fn test_field_classification() {
        let res = analyze_structure("field".to_string(), "7".to_string()).unwrap();
        let analysis = res.analysis.unwrap();
        assert_eq!(analysis.label, "GF(7)");
        assert_eq!(analysis.order, "|GF(7)| = 7");
        assert_eq!(analysis.is_cyclic, true);

        let err_res = analyze_structure("field".to_string(), "10".to_string()).unwrap();
        assert!(!err_res.success);
        assert!(err_res.error_message.is_some());
    }
}
