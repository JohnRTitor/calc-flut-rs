use num_bigint::BigInt;

use symplex::ntheory as nt;

use crate::symbolic::error::SymbolicError;

/// Largest integer accepted, in decimal digits.
///
/// **This bounds the input, not the work.** Factorisation difficulty depends on
/// the number's factors rather than its size, so no digit cap can promise a
/// quick answer: measured on this build, a 60-digit number took 7.5s and a
/// 100-digit one 49s, while a 40-digit number took 26ms. 30 digits keeps
/// hand-entered input — which is what this app is for — comfortably inside
/// milliseconds in every case measured, and the async bridge plus the "still
/// working" notice cover whatever remains.
///
/// It is a floor on sanity, not a performance guarantee, and the help text says
/// so rather than implying a bound that is not there.
pub const MAX_DIGITS: usize = 30;

/// One prime-power term of a factorisation.
#[derive(Debug, Clone)]
pub struct PrimeFactor {
    /// The prime, as written.
    pub prime: String,
    /// How many times it occurs.
    pub power: u32,
}

/// Everything worth knowing about one integer, computed in one pass.
#[derive(Debug, Clone)]
pub struct NumberAnalysis {
    /// The number, echoed exactly as it was given.
    pub value: String,
    /// Whether it is prime. Neither 0, 1 nor any negative number is.
    pub is_prime: bool,
    /// Whether it is a perfect square.
    pub is_square: bool,
    /// Whether it is a perfect number.
    pub is_perfect: bool,
    /// Whether it is a Carmichael number.
    pub is_carmichael: bool,
    /// The prime factorisation, empty for 0, 1 and -1.
    ///
    /// Carries a `-1` term first when the number is negative, because the
    /// factorisation of `-12` is `-1 * 2^2 * 3` and reporting only `2^2 * 3`
    /// would lose the sign without saying so.
    pub factors: Vec<PrimeFactor>,
    /// Every positive divisor, in order.
    pub divisors: Vec<String>,
    /// How many divisors it has.
    pub divisor_count: usize,
    /// The sum of its divisors.
    pub divisor_sum: String,
    /// Euler's totient: how many integers up to it share no factor with it.
    pub totient: String,
    /// The next prime above it.
    pub next_prime: String,
    /// The largest prime below it.
    pub previous_prime: String,
    /// Facts that explain any of the above being absent.
    pub details: Option<String>,
}

/// Parses an integer exactly.
///
/// Rejects anything that is not a whole number: silently rounding `2.5` to `2`
/// would answer a different question, and "nearest prime" to a number that is
/// not an integer is meaningless.
fn parse(source: &str) -> Result<BigInt, SymbolicError> {
    let trimmed = source.trim();
    if trimmed.is_empty() {
        return Err(SymbolicError::EmptyNumber);
    }
    // Accept a leading sign, digits only after that.
    let body = trimmed.strip_prefix('-').or_else(|| trimmed.strip_prefix('+')).unwrap_or(trimmed);
    if body.is_empty() || !body.chars().all(|c| c.is_ascii_digit()) {
        return Err(SymbolicError::NotAnInteger {
            value: trimmed.to_string(),
        });
    }
    if trimmed.trim_start_matches(['-', '+']).len() > MAX_DIGITS {
        return Err(SymbolicError::TooLarge(format!(
            "over {MAX_DIGITS} digits"
        )));
    }
    trimmed
        .parse::<BigInt>()
        .map_err(|_| SymbolicError::NotAnInteger {
            value: trimmed.to_string(),
        })
}

/// Analyses one integer.
///
/// Every result is exact. `0`, `1` and negatives all have real answers for most
/// of these, and the ones that do not are reported as absent with a reason
/// rather than as a value of zero.
pub fn analyse(source: &str) -> Result<NumberAnalysis, SymbolicError> {
    let value = parse(source)?;
    let magnitude = value.magnitude().clone();
    let is_negative = value.sign() == num_bigint::Sign::Minus;
    let is_zero = value.sign() == num_bigint::Sign::NoSign;
    let is_one = value == BigInt::from(1i64) || value == BigInt::from(-1i64);

    let mut details: Vec<String> = Vec::new();

    // Factorisation is taken over the magnitude, so the sign is restored here
    // rather than being quietly dropped.
    let mut factors: Vec<PrimeFactor> = nt::factorint(magnitude.clone())
        .into_iter()
        .map(|(prime, power)| PrimeFactor {
            prime: prime.to_string(),
            power,
        })
        .collect();
    if is_negative && !is_zero {
        factors.insert(
            0,
            PrimeFactor {
                prime: "-1".to_string(),
                power: 1,
            },
        );
    }
    if is_zero {
        details.push("0 has no prime factorisation.".to_string());
    } else if is_one {
        details.push("1 has no prime factors.".to_string());
    }

    let divisors: Vec<String> = if is_zero {
        // Every positive integer divides 0, so there is no finite list to give.
        details.push("Every positive integer divides 0, so it has infinitely many divisors.".to_string());
        Vec::new()
    } else {
        nt::divisors(magnitude.clone())
            .into_iter()
            .map(|divisor| divisor.to_string())
            .collect()
    };

    let divisor_count = if is_zero { 0 } else { divisors.len() };
    let divisor_sum = if is_zero {
        String::new()
    } else {
        nt::divisor_sum(magnitude.clone()).to_string()
    };

    // Totient is conventionally defined for positive integers; phi(1) = 1, and
    // for 0 there is no meaningful count.
    let totient = if is_zero {
        details.push("The totient is not defined for 0.".to_string());
        String::new()
    } else if is_one {
        "1".to_string()
    } else {
        nt::totient(magnitude.clone()).to_string()
    };

    // `nextprime` is unbounded and `prevprime` is not, so only the smaller
    // neighbour can genuinely be absent.
    let next_prime = nt::nextprime(magnitude.clone()).to_string();
    if is_negative {
        details.push("Prime neighbours are given for the magnitude.".to_string());
    }

    let previous_prime = if is_negative || is_zero {
        String::new()
    } else {
        nt::prevprime(magnitude.clone())
            .map(|n| n.to_string())
            .unwrap_or_default()
    };
    if !is_negative && !is_zero && previous_prime.is_empty() {
        details.push("There is no smaller prime.".to_string());
    }

    Ok(NumberAnalysis {
        value: value.to_string(),
        is_prime: !is_negative && nt::isprime(magnitude.clone()),
        is_square: !is_negative && nt::is_square(magnitude.clone()),
        is_perfect: !is_negative && nt::is_perfect(magnitude.clone()),
        is_carmichael: !is_negative && nt::is_carmichael(magnitude.clone()),
        factors,
        divisors,
        divisor_count,
        divisor_sum,
        totient,
        next_prime,
        previous_prime,
        details: (!details.is_empty()).then(|| details.join(" ")),
    })
}

/// The greatest common divisor of two integers, always non-negative.
pub fn gcd(first: &str, second: &str) -> Result<String, SymbolicError> {
    let a = parse(first)?;
    let b = parse(second)?;
    Ok(nt::gcd(a.magnitude().clone(), b.magnitude().clone()).to_string())
}

/// The least common multiple of two integers, always non-negative.
pub fn lcm(first: &str, second: &str) -> Result<String, SymbolicError> {
    let a = parse(first)?;
    let b = parse(second)?;
    if a.sign() == num_bigint::Sign::NoSign || b.sign() == num_bigint::Sign::NoSign {
        // The lcm of anything and 0 is 0. Computing it via gcd/lcm would divide
        // by the shared factor, so it is stated rather than derived.
        return Ok("0".to_string());
    }
    Ok(nt::lcm(a.magnitude().clone(), b.magnitude().clone()).to_string())
}

/// Whether two integers share no common factor other than 1.
pub fn coprime(first: &str, second: &str) -> Result<bool, SymbolicError> {
    let a = parse(first)?;
    let b = parse(second)?;
    Ok(nt::is_coprime(a.magnitude().clone(), b.magnitude().clone()))
}
