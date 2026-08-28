use crate::modular_arithmetic::{
    error::ModError,
    mod_arith::{mod_add, mod_mul},
    number_theory_ext::unit_group,
};

const MAX_CAYLEY_N: i128 = 25;

pub fn addition_table(n: i128) -> Result<Vec<Vec<i128>>, ModError> {
    let n = n.abs();
    if n > MAX_CAYLEY_N {
        return Err(ModError::TooLarge(format!(
            "Modulus {} exceeds maximum Cayley table size of {}",
            n, MAX_CAYLEY_N
        )));
    }

    let mut table = Vec::with_capacity(n as usize);
    for i in 0..n {
        let mut row = Vec::with_capacity(n as usize);
        for j in 0..n {
            row.push(mod_add(i, j, n));
        }
        table.push(row);
    }
    Ok(table)
}

pub fn multiplication_table(n: i128) -> Result<Vec<Vec<i128>>, ModError> {
    let n = n.abs();
    if n > MAX_CAYLEY_N {
        return Err(ModError::TooLarge(format!(
            "Modulus {} exceeds maximum Cayley table size of {}",
            n, MAX_CAYLEY_N
        )));
    }

    let mut table = Vec::with_capacity(n as usize);
    for i in 0..n {
        let mut row = Vec::with_capacity(n as usize);
        for j in 0..n {
            row.push(mod_mul(i, j, n));
        }
        table.push(row);
    }
    Ok(table)
}

pub fn unit_group_table(n: i128) -> Result<(Vec<i128>, Vec<Vec<i128>>), ModError> {
    let n = n.abs();
    if n > MAX_CAYLEY_N {
        return Err(ModError::TooLarge(format!(
            "Modulus {} exceeds maximum Cayley table size of {}",
            n, MAX_CAYLEY_N
        )));
    }

    let units = unit_group(n);
    let mut table = Vec::with_capacity(units.len());

    for &u1 in &units {
        let mut row = Vec::with_capacity(units.len());
        for &u2 in &units {
            row.push(mod_mul(u1, u2, n));
        }
        table.push(row);
    }

    Ok((units, table))
}
