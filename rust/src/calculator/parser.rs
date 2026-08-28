use crate::calculator::error::CalcError;

/// Represents a single lexical token in a mathematical expression.
#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Number(f64),
    Plus,
    Minus,
    Multiply,
    Divide,
    Modulo,
    Percentage,
    Power,
    Factorial,
    LParen,
    RParen,
    Sin,
    Cos,
    Tan,
    Asin,
    Acos,
    Atan,
    Sinh,
    Cosh,
    Tanh,
    Asinh,
    Acosh,
    Atanh,
    Log,
    LogBase,
    Ln,
    Sqrt,
    Pi,
    E,
    Ans,
    Variable(String),
}

/// Converts a string representation of a mathematical expression into a sequence of tokens.
///
/// Returns a list of `Token`s if successful, or a `CalcError` if the input contains
/// invalid characters or syntax.
pub fn tokenize(input: &str) -> Result<Vec<Token>, CalcError> {
    let mut tokens = Vec::new();
    let mut chars = input.chars().peekable();

    while let Some(&c) = chars.peek() {
        match c {
            ' ' | '\t' | '\n' | '\r' => {
                chars.next();
            }
            '+' => {
                tokens.push(Token::Plus);
                chars.next();
            }
            '-' | '−' => {
                tokens.push(Token::Minus);
                chars.next();
            }
            '*' | '×' => {
                tokens.push(Token::Multiply);
                chars.next();
            }
            '/' | '÷' => {
                tokens.push(Token::Divide);
                chars.next();
            }
            '%' => {
                tokens.push(Token::Percentage);
                chars.next();
            }
            '^' => {
                tokens.push(Token::Power);
                chars.next();
            }
            '!' => {
                tokens.push(Token::Factorial);
                chars.next();
            }
            '(' => {
                tokens.push(Token::LParen);
                chars.next();
            }
            ')' => {
                tokens.push(Token::RParen);
                chars.next();
            }
            'π' => {
                tokens.push(Token::Pi);
                chars.next();
            }
            'e' if tokens.is_empty()
                || matches!(
                    tokens.last(),
                    Some(
                        Token::Plus
                            | Token::Minus
                            | Token::Multiply
                            | Token::Divide
                            | Token::Modulo
                            | Token::Power
                            | Token::LParen
                    )
                ) =>
            {
                // simple 'e' constant vs exponential notation (handled in number parsing)
                tokens.push(Token::E);
                chars.next();
            }
            '0'..='9' | '.' => {
                let mut num_str = String::new();
                let mut has_dot = false;
                let mut has_e = false;

                while let Some(&nc) = chars.peek() {
                    if nc.is_ascii_digit() {
                        num_str.push(nc);
                        chars.next();
                    } else if nc == '.' && !has_dot {
                        num_str.push(nc);
                        has_dot = true;
                        chars.next();
                    } else if (nc == 'e' || nc == 'E') && !has_e {
                        let mut is_exp = false;
                        let mut peek_chars = chars.clone();
                        peek_chars.next(); // skip 'e'
                        if let Some(&nc2) = peek_chars.peek() {
                            if nc2.is_ascii_digit() {
                                is_exp = true;
                            } else if nc2 == '+' || nc2 == '-' || nc2 == '−' {
                                peek_chars.next();
                                if let Some(&nc3) = peek_chars.peek()
                                    && nc3.is_ascii_digit()
                                {
                                    is_exp = true;
                                }
                            }
                        }

                        if is_exp {
                            num_str.push(nc);
                            has_e = true;
                            chars.next();
                            if let Some(&sign) = chars.peek()
                                && (sign == '+' || sign == '-' || sign == '−')
                            {
                                num_str.push(if sign == '−' { '-' } else { sign });
                                chars.next();
                            }
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }

                let num = num_str.parse::<f64>().map_err(|_| {
                    CalcError::InvalidToken(format!("Invalid number: {}", num_str))
                })?;
                tokens.push(Token::Number(num));
            }
            c if c.is_alphabetic() => {
                let mut ident = String::new();
                while let Some(&nc) = chars.peek() {
                    if nc.is_alphabetic() || nc == '_' {
                        ident.push(nc);
                        chars.next();
                    } else {
                        break;
                    }
                }

                match ident.to_lowercase().as_str() {
                    "mod" => tokens.push(Token::Modulo),
                    "sin" => tokens.push(Token::Sin),
                    "cos" => tokens.push(Token::Cos),
                    "tan" => tokens.push(Token::Tan),
                    "asin" => tokens.push(Token::Asin),
                    "acos" => tokens.push(Token::Acos),
                    "atan" => tokens.push(Token::Atan),
                    "sinh" => tokens.push(Token::Sinh),
                    "cosh" => tokens.push(Token::Cosh),
                    "tanh" => tokens.push(Token::Tanh),
                    "asinh" => tokens.push(Token::Asinh),
                    "acosh" => tokens.push(Token::Acosh),
                    "atanh" => tokens.push(Token::Atanh),
                    "log" => tokens.push(Token::Log),
                    "log_" => tokens.push(Token::LogBase),
                    "ln" => tokens.push(Token::Ln),
                    "sqrt" => tokens.push(Token::Sqrt),
                    "pi" => tokens.push(Token::Pi),
                    "e" => tokens.push(Token::E),
                    "ans" => tokens.push(Token::Ans),
                    _ => {
                        tokens.push(Token::Variable(ident));
                    }
                }
            }
            _ => {
                return Err(CalcError::InvalidToken(c.to_string()));
            }
        }
    }

    // Insert implicit multiplications
    let mut i = 0;
    while i < tokens.len() {
        if i + 1 < tokens.len() {
            let left_is_value = matches!(
                tokens[i],
                Token::Number(_)
                    | Token::Pi
                    | Token::E
                    | Token::Ans
                    | Token::Variable(_)
                    | Token::RParen
                    | Token::Percentage
                    | Token::Factorial
            );
            
            let right_is_start = matches!(
                tokens[i + 1],
                Token::Number(_)
                    | Token::Pi
                    | Token::E
                    | Token::Ans
                    | Token::Variable(_)
                    | Token::LParen
                    | Token::Sin
                    | Token::Cos
                    | Token::Tan
                    | Token::Asin
                    | Token::Acos
                    | Token::Atan
                    | Token::Sinh
                    | Token::Cosh
                    | Token::Tanh
                    | Token::Asinh
                    | Token::Acosh
                    | Token::Atanh
                    | Token::Log
                    | Token::LogBase
                    | Token::Ln
                    | Token::Sqrt
            );

            if left_is_value && right_is_start {
                tokens.insert(i + 1, Token::Multiply);
                i += 1; // skip the newly inserted token
            }
        }
        i += 1;
    }

    Ok(tokens)
}

/// Represents a node in the Abstract Syntax Tree (AST) of a mathematical expression.
#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    Number(f64),
    Pi,
    E,
    Add(Box<Expr>, Box<Expr>),
    Subtract(Box<Expr>, Box<Expr>),
    Multiply(Box<Expr>, Box<Expr>),
    Divide(Box<Expr>, Box<Expr>),
    Modulo(Box<Expr>, Box<Expr>),
    Power(Box<Expr>, Box<Expr>),
    Negate(Box<Expr>),
    Factorial(Box<Expr>),
    Percentage(Box<Expr>),
    Sin(Box<Expr>),
    Cos(Box<Expr>),
    Tan(Box<Expr>),
    Asin(Box<Expr>),
    Acos(Box<Expr>),
    Atan(Box<Expr>),
    Sinh(Box<Expr>),
    Cosh(Box<Expr>),
    Tanh(Box<Expr>),
    Asinh(Box<Expr>),
    Acosh(Box<Expr>),
    Atanh(Box<Expr>),
    Log10(Box<Expr>),
    Log { base: Box<Expr>, value: Box<Expr> },
    Ln(Box<Expr>),
    Sqrt(Box<Expr>),
    Ans,
    Variable(String),
}

/// A parser that constructs an Abstract Syntax Tree (AST) from a sequence of `Token`s.
pub struct Parser<'a> {
    tokens: &'a [Token],
    pos: usize,
}

impl<'a> Parser<'a> {
    /// Creates a new `Parser` instance for the given slice of tokens.
    pub fn new(tokens: &'a [Token]) -> Self {
        Parser { tokens, pos: 0 }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn consume(&mut self) -> Option<&Token> {
        let token = self.tokens.get(self.pos);
        self.pos += 1;
        token
    }

    fn match_token(&mut self, token: &Token) -> bool {
        if self.peek() == Some(token) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    /// Parses the tokens into an `Expr` (AST).
    ///
    /// Returns an `Expr` if successful, or a `CalcError` if the token sequence
    /// is not a valid mathematical expression.
    pub fn parse(&mut self) -> Result<Expr, CalcError> {
        if self.tokens.is_empty() {
            return Err(CalcError::MissingOperand("Empty expression".to_string()));
        }
        let expr = self.parse_expression()?;
        if self.pos < self.tokens.len() {
            return Err(CalcError::InvalidToken(
                format!("Unexpected token at end of expression: {:?}", self.tokens[self.pos]),
            ));
        }
        Ok(expr)
    }

    fn parse_expression(&mut self) -> Result<Expr, CalcError> {
        self.parse_term()
    }

    fn parse_term(&mut self) -> Result<Expr, CalcError> {
        let mut left = self.parse_factor()?;

        while let Some(op) = self.peek() {
            match op {
                Token::Plus => {
                    self.consume();
                    let right = self.parse_factor()?;
                    left = Expr::Add(Box::new(left), Box::new(right));
                }
                Token::Minus => {
                    self.consume();
                    let right = self.parse_factor()?;
                    left = Expr::Subtract(Box::new(left), Box::new(right));
                }
                _ => break,
            }
        }

        Ok(left)
    }

    fn parse_factor(&mut self) -> Result<Expr, CalcError> {
        let mut left = self.parse_unary()?;

        while let Some(op) = self.peek() {
            match op {
                Token::Multiply => {
                    self.consume();
                    let right = self.parse_unary()?;
                    left = Expr::Multiply(Box::new(left), Box::new(right));
                }
                Token::Divide => {
                    self.consume();
                    let right = self.parse_unary()?;
                    left = Expr::Divide(Box::new(left), Box::new(right));
                }
                Token::Modulo => {
                    self.consume();
                    let right = self.parse_unary()?;
                    left = Expr::Modulo(Box::new(left), Box::new(right));
                }
                _ => break,
            }
        }

        Ok(left)
    }

    fn parse_unary(&mut self) -> Result<Expr, CalcError> {
        if self.match_token(&Token::Plus) {
            self.parse_unary()
        } else if self.match_token(&Token::Minus) {
            let expr = self.parse_unary()?;
            Ok(Expr::Negate(Box::new(expr)))
        } else {
            self.parse_power()
        }
    }

    fn parse_power(&mut self) -> Result<Expr, CalcError> {
        let left = self.parse_postfix()?;

        if self.match_token(&Token::Power) {
            let right = self.parse_power()?; // Right-associative
            return Ok(Expr::Power(Box::new(left), Box::new(right)));
        }

        Ok(left)
    }

    fn parse_postfix(&mut self) -> Result<Expr, CalcError> {
        let mut expr = self.parse_primary()?;

        loop {
            if self.match_token(&Token::Factorial) {
                expr = Expr::Factorial(Box::new(expr));
            } else if self.match_token(&Token::Percentage) {
                expr = Expr::Percentage(Box::new(expr));
            } else {
                break;
            }
        }

        Ok(expr)
    }

    fn parse_primary(&mut self) -> Result<Expr, CalcError> {
        let token = self
            .consume()
            .ok_or_else(|| CalcError::MissingOperand("Unexpected end of input".to_string()))?
            .clone();

        match token {
            Token::Number(n) => Ok(Expr::Number(n)),
            Token::Pi => Ok(Expr::Pi),
            Token::E => Ok(Expr::E),
            Token::LParen => {
                let expr = self.parse_expression()?;
                if !self.match_token(&Token::RParen) {
                    return Err(CalcError::MissingClosingParenthesis);
                }
                Ok(expr)
            }
            Token::Sin => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Sin(Box::new(expr)))
            }
            Token::Cos => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Cos(Box::new(expr)))
            }
            Token::Tan => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Tan(Box::new(expr)))
            }
            Token::Asin => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Asin(Box::new(expr)))
            }
            Token::Acos => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Acos(Box::new(expr)))
            }
            Token::Atan => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Atan(Box::new(expr)))
            }
            Token::Sinh => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Sinh(Box::new(expr)))
            }
            Token::Cosh => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Cosh(Box::new(expr)))
            }
            Token::Tanh => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Tanh(Box::new(expr)))
            }
            Token::Asinh => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Asinh(Box::new(expr)))
            }
            Token::Acosh => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Acosh(Box::new(expr)))
            }
            Token::Atanh => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Atanh(Box::new(expr)))
            }
            Token::Log => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Log10(Box::new(expr)))
            }
            Token::LogBase => {
                let base = self.parse_power()?;
                // Consume implicit multiplication inserted between base and value
                if self.peek() == Some(&Token::Multiply) {
                    self.consume();
                }
                let value = self.parse_primary_arg()?;
                Ok(Expr::Log {
                    base: Box::new(base),
                    value: Box::new(value),
                })
            }
            Token::Ln => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Ln(Box::new(expr)))
            }
            Token::Sqrt => {
                let expr = self.parse_primary_arg()?;
                Ok(Expr::Sqrt(Box::new(expr)))
            }
            Token::Ans => Ok(Expr::Ans),
            Token::Variable(name) => Ok(Expr::Variable(name)),
            _ => Err(CalcError::InvalidToken(format!(
                "{:?}", token
            ))),
        }
    }

    fn parse_primary_arg(&mut self) -> Result<Expr, CalcError> {
        // Allow things like `sin(x)` or `sin x`
        if self.peek() == Some(&Token::LParen) {
            self.parse_primary() // Handles the parenthesis block
        } else {
            self.parse_power() // Tighter binding for function arguments
        }
    }
}
