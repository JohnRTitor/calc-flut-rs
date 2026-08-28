use {crate::converter::converter, flutter_rust_bridge::frb};

/// FFI representation of a physical unit of measurement.
#[frb]
#[derive(Debug, Clone)]
pub struct FfiUnit {
    pub id: String,
    pub name: String,
    pub symbol: String,
    pub multiplier: f64,
    pub offset: f64,
}

/// FFI representation of a category of units.
#[frb]
#[derive(Debug, Clone)]
pub struct FfiConverterCategory {
    pub id: String,
    pub name: String,
    pub icon_name: String,
    pub units: Vec<FfiUnit>,
    pub show_swap_units_toggler: bool,
    pub show_result_section: bool,
}

/// Retrieves all available converter categories for the Flutter UI.
#[frb(sync)]
pub fn get_converter_categories() -> Vec<FfiConverterCategory> {
    converter::get_all_categories()
        .into_iter()
        .map(|c| FfiConverterCategory {
            id: c.id,
            name: c.name,
            icon_name: c.icon_name,
            units: c
                .units
                .into_iter()
                .map(|u| FfiUnit {
                    id: u.id,
                    name: u.name,
                    symbol: u.symbol,
                    multiplier: u.multiplier,
                    offset: u.offset,
                })
                .collect(),
            show_swap_units_toggler: true,
            show_result_section: true,
        })
        .collect()
}

/// Converts a value between two standard units.
#[frb(sync)]
pub fn convert_standard(value: f64, from_unit: FfiUnit, to_unit: FfiUnit) -> f64 {
    let from = converter::Unit {
        id: from_unit.id,
        name: from_unit.name,
        symbol: from_unit.symbol,
        multiplier: from_unit.multiplier,
        offset: from_unit.offset,
    };
    let to = converter::Unit {
        id: to_unit.id,
        name: to_unit.name,
        symbol: to_unit.symbol,
        multiplier: to_unit.multiplier,
        offset: to_unit.offset,
    };
    converter::convert_standard(value, &from, &to)
}

/// Converts a string representing a numeral from one base to another.
#[frb(sync)]
pub fn convert_numeral(value: String, from_base: u32, to_base: u32) -> Option<String> {
    converter::convert_numeral(&value, from_base, to_base)
}

/// FFI representation of a precise date difference
#[frb]
pub struct DateDiffResult {
    pub years: i32,
    pub months: i32,
    pub days: i32,
    pub total_days: i32,
}

/// Calculates the difference between two timestamps (in milliseconds since epoch)
#[frb(sync)]
pub fn calculate_date_difference(start_timestamp_ms: i64, end_timestamp_ms: i64) -> DateDiffResult {
    let diff_ms = (end_timestamp_ms - start_timestamp_ms).abs();
    let total_days = (diff_ms / (1000 * 60 * 60 * 24)) as i32;

    let years = total_days / 365;
    let remaining = total_days % 365;
    let months = remaining / 30;
    let days = remaining % 30;

    DateDiffResult {
        years,
        months,
        days,
        total_days,
    }
}

/// FFI representation of a Body Mass Index (BMI) calculation result.
#[frb]
pub struct BmiResult {
    pub bmi: f64,
    pub category: String,
}

/// Calculates BMI based on weight (kg) and height (m).
#[frb(sync)]
pub fn calculate_bmi(weight_kg: f64, height_m: f64) -> BmiResult {
    if height_m <= 0.0 {
        return BmiResult {
            bmi: 0.0,
            category: "Invalid".to_string(),
        };
    }
    let bmi = weight_kg / (height_m * height_m);

    let category = if bmi < 18.5 {
        "Underweight"
    } else if (18.5..25.0).contains(&bmi) {
        "Normal"
    } else if (25.0..30.0).contains(&bmi) {
        "Overweight"
    } else {
        "Obese"
    };

    BmiResult {
        bmi,
        category: category.to_string(),
    }
}
