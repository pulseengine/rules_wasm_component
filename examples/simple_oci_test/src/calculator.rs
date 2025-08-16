// Simple calculator component implementation
use calculator_component_bindings::exports::simple::calculator::calculate::Guest;

struct Calculator;

impl Guest for Calculator {
    fn add(a: i32, b: i32) -> i32 {
        a + b
    }

    fn subtract(a: i32, b: i32) -> i32 {
        a - b
    }

    fn multiply(a: i32, b: i32) -> i32 {
        a * b
    }

    fn divide(a: i32, b: i32) -> Result<i32, String> {
        if b == 0 {
            Err("Division by zero".to_string())
        } else {
            Ok(a / b)
        }
    }
}

calculator_component_bindings::export!(Calculator with_types_in calculator_component_bindings);
