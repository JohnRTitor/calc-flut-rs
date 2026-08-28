use crate::{
    bridge::converter::{calculate_bmi, calculate_date_difference},
    converter::converter::{convert_numeral, convert_standard, get_all_categories},
};

#[test]
fn test_length_conversion() {
    let cats = get_all_categories();
    let length_cat = cats.iter().find(|c| c.id == "length").unwrap();

    let m = length_cat.units.iter().find(|u| u.id == "m").unwrap();
    let km = length_cat.units.iter().find(|u| u.id == "km").unwrap();
    let cm = length_cat.units.iter().find(|u| u.id == "cm").unwrap();

    // 1000 m = 1 km
    let res1 = convert_standard(1000.0, m, km);
    assert!((res1 - 1.0).abs() < 1e-9);

    // 1 km = 100000 cm
    let res2 = convert_standard(1.0, km, cm);
    assert!((res2 - 100000.0).abs() < 1e-9);
}

#[test]
fn test_temperature_conversion() {
    let cats = get_all_categories();
    let temp_cat = cats.iter().find(|c| c.id == "temperature").unwrap();
    let c = temp_cat.units.iter().find(|u| u.id == "c").unwrap();
    let f = temp_cat.units.iter().find(|u| u.id == "f").unwrap();
    let k = temp_cat.units.iter().find(|u| u.id == "k").unwrap();

    // 0 C = 32 F
    let res1 = convert_standard(0.0, c, f);
    assert!((res1 - 32.0).abs() < 1e-9);

    // 100 C = 212 F
    let res2 = convert_standard(100.0, c, f);
    assert!((res2 - 212.0).abs() < 1e-9);

    // 0 C = 273.15 K
    let res3 = convert_standard(0.0, c, k);
    assert!((res3 - 273.15).abs() < 1e-9);
}

#[test]
fn test_mass_conversion() {
    let cats = get_all_categories();
    let mass_cat = cats.iter().find(|c| c.id == "mass").unwrap();
    let kg = mass_cat.units.iter().find(|u| u.id == "kg").unwrap();
    let g = mass_cat.units.iter().find(|u| u.id == "g").unwrap();
    let lb = mass_cat.units.iter().find(|u| u.id == "lb").unwrap();

    // 1 kg = 1000 g
    let res1 = convert_standard(1.0, kg, g);
    assert!((res1 - 1000.0).abs() < 1e-9);

    // 1 kg = 2.20462 lb (approx)
    let res2 = convert_standard(1.0, kg, lb);
    assert!((res2 - 2.20462262).abs() < 1e-5);
}

#[test]
fn test_numeral_conversion() {
    // Dec to Hex
    let hex_val = convert_numeral("255", 10, 16).unwrap();
    assert_eq!(hex_val, "FF");

    // Hex to Dec
    let dec_val = convert_numeral("FF", 16, 10).unwrap();
    assert_eq!(dec_val, "255");

    // Bin to Dec
    let dec_val2 = convert_numeral("1010", 2, 10).unwrap();
    assert_eq!(dec_val2, "10");

    // Oct to Bin
    let bin_val = convert_numeral("77", 8, 2).unwrap();
    assert_eq!(bin_val, "111111");

    // Invalid input
    let invalid = convert_numeral("G", 16, 10);
    assert!(invalid.is_none());
}

#[test]
fn test_bmi_calculation() {
    // Normal
    let res1 = calculate_bmi(70.0, 1.75);
    assert!((res1.bmi - 22.857142857142858).abs() < 1e-9);
    assert_eq!(res1.category, "Normal");

    // Underweight
    let res2 = calculate_bmi(50.0, 1.80);
    assert_eq!(res2.category, "Underweight");

    // Overweight
    let res3 = calculate_bmi(85.0, 1.75);
    assert_eq!(res3.category, "Overweight");

    // Obese
    let res4 = calculate_bmi(100.0, 1.70);
    assert_eq!(res4.category, "Obese");

    // Zero height (Edge case)
    let res5 = calculate_bmi(70.0, 0.0);
    assert_eq!(res5.bmi, 0.0);
    assert_eq!(res5.category, "Invalid");
}

#[test]
fn test_date_difference() {
    // Basic difference: 2023-01-01 to 2024-01-01
    // Timestamps in ms
    let start_ts = 1672531200000; // 2023-01-01T00:00:00Z
    let end_ts = 1704067200000; // 2024-01-01T00:00:00Z

    let diff = calculate_date_difference(start_ts, end_ts);
    assert_eq!(diff.years, 1);
    assert_eq!(diff.months, 0);
    assert_eq!(diff.days, 0);

    // Negative difference (end before start)
    let diff2 = calculate_date_difference(end_ts, start_ts);
    // The implementation might return absolute values or handle it specifically.
    // If it returns absolute values:
    assert_eq!(diff2.years, 1);
    assert_eq!(diff2.months, 0);
    assert_eq!(diff2.days, 0);
}
