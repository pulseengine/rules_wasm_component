// Mock Payment Service implementation for local microservices architecture

use payment_service_bindings::exports::microservices::payment::payment_processing::{
    Guest as PaymentGuest, PaymentMethodValidation, PaymentRequest, PaymentResult, RefundRequest,
};
use std::collections::HashMap;

// Mock transaction database
static mut TRANSACTIONS: Option<HashMap<String, PaymentResult>> = None;
static mut NEXT_TRANSACTION_ID: u32 = 100000;

fn get_transactions() -> &'static mut HashMap<String, PaymentResult> {
    unsafe {
        TRANSACTIONS.get_or_insert_with(|| {
            let mut transactions = HashMap::new();

            // Pre-populate with some test transactions
            transactions.insert(
                "txn_98765".to_string(),
                PaymentResult {
                    success: true,
                    transaction_id: Some("txn_98765".to_string()),
                    status: "completed".to_string(),
                    amount_charged: Some(159.99),
                    error_message: None,
                    processing_fee: Some(4.79),
                },
            );

            transactions.insert(
                "txn_98764".to_string(),
                PaymentResult {
                    success: false,
                    transaction_id: Some("txn_98764".to_string()),
                    status: "failed".to_string(),
                    amount_charged: None,
                    error_message: Some("Insufficient funds".to_string()),
                    processing_fee: None,
                },
            );

            transactions
        })
    }
}

fn generate_transaction_id() -> String {
    unsafe {
        let id = NEXT_TRANSACTION_ID;
        NEXT_TRANSACTION_ID += 1;
        format!("txn_{}", id)
    }
}

fn calculate_processing_fee(amount: f64, payment_method: &str) -> f64 {
    match payment_method {
        "credit_card" => amount * 0.029 + 0.30, // 2.9% + $0.30
        "debit_card" => amount * 0.015 + 0.25,  // 1.5% + $0.25
        "bank_transfer" => 1.00,                // Flat $1.00
        "digital_wallet" => amount * 0.020,     // 2.0%
        _ => amount * 0.035,                    // 3.5% for unknown methods
    }
}

// Component implementation
struct PaymentService;

impl PaymentGuest for PaymentService {
    fn process_payment(request: PaymentRequest) -> PaymentResult {
        // Basic validation
        if request.amount <= 0.0 {
            return PaymentResult {
                success: false,
                transaction_id: None,
                status: "failed".to_string(),
                amount_charged: None,
                error_message: Some("Amount must be positive".to_string()),
                processing_fee: None,
            };
        }

        if request.currency != "USD" {
            return PaymentResult {
                success: false,
                transaction_id: None,
                status: "failed".to_string(),
                amount_charged: None,
                error_message: Some("Only USD currency is supported".to_string()),
                processing_fee: None,
            };
        }

        // Validate payment method
        let validation = Self::validate_payment_method(request.payment_method.clone());
        if !validation.valid {
            return PaymentResult {
                success: false,
                transaction_id: None,
                status: "failed".to_string(),
                amount_charged: None,
                error_message: validation.error,
                processing_fee: None,
            };
        }

        let transaction_id = generate_transaction_id();
        let processing_fee = calculate_processing_fee(request.amount, &request.payment_method);

        // Mock payment processing logic - simulate some failures
        let success = match request.payment_method.as_str() {
            "credit_card" => request.amount < 10000.0, // Fail large transactions
            "debit_card" => request.user_id != 999,    // Fail for test user 999
            "bank_transfer" => true,                   // Always succeed
            "digital_wallet" => request.amount < 5000.0, // Fail very large transactions
            _ => false,                                // Unknown payment methods fail
        };

        let result = if success {
            PaymentResult {
                success: true,
                transaction_id: Some(transaction_id.clone()),
                status: "completed".to_string(),
                amount_charged: Some(request.amount),
                error_message: None,
                processing_fee: Some(processing_fee),
            }
        } else {
            let error_msg = match request.payment_method.as_str() {
                "credit_card" => "Transaction amount too large",
                "debit_card" => "Payment method declined",
                "digital_wallet" => "Transaction limit exceeded",
                _ => "Payment method not supported",
            };

            PaymentResult {
                success: false,
                transaction_id: Some(transaction_id.clone()),
                status: "failed".to_string(),
                amount_charged: None,
                error_message: Some(error_msg.to_string()),
                processing_fee: None,
            }
        };

        // Store transaction in mock database
        get_transactions().insert(transaction_id, result.clone());
        result
    }

    fn get_payment_status(transaction_id: String) -> Option<PaymentResult> {
        get_transactions().get(&transaction_id).cloned()
    }

    fn refund_payment(request: RefundRequest) -> PaymentResult {
        let transactions = get_transactions();

        let original_transaction = match transactions.get(&request.transaction_id) {
            Some(txn) if txn.success => txn.clone(),
            Some(_) => {
                return PaymentResult {
                    success: false,
                    transaction_id: None,
                    status: "failed".to_string(),
                    amount_charged: None,
                    error_message: Some("Cannot refund failed transaction".to_string()),
                    processing_fee: None,
                }
            }
            None => {
                return PaymentResult {
                    success: false,
                    transaction_id: None,
                    status: "failed".to_string(),
                    amount_charged: None,
                    error_message: Some("Original transaction not found".to_string()),
                    processing_fee: None,
                }
            }
        };

        let refund_amount = request
            .amount
            .unwrap_or(original_transaction.amount_charged.unwrap_or(0.0));

        if refund_amount > original_transaction.amount_charged.unwrap_or(0.0) {
            return PaymentResult {
                success: false,
                transaction_id: None,
                status: "failed".to_string(),
                amount_charged: None,
                error_message: Some("Refund amount cannot exceed original charge".to_string()),
                processing_fee: None,
            };
        }

        let refund_transaction_id = generate_transaction_id();
        let refund_result = PaymentResult {
            success: true,
            transaction_id: Some(refund_transaction_id.clone()),
            status: "refunded".to_string(),
            amount_charged: Some(-refund_amount), // Negative for refund
            error_message: None,
            processing_fee: None, // No fee for refunds
        };

        transactions.insert(refund_transaction_id, refund_result.clone());
        refund_result
    }

    fn validate_payment_method(method: String) -> PaymentMethodValidation {
        match method.as_str() {
            "credit_card" => PaymentMethodValidation {
                method,
                valid: true,
                error: None,
                supported_currencies: vec!["USD".to_string(), "EUR".to_string(), "GBP".to_string()],
            },
            "debit_card" => PaymentMethodValidation {
                method,
                valid: true,
                error: None,
                supported_currencies: vec!["USD".to_string()],
            },
            "bank_transfer" => PaymentMethodValidation {
                method,
                valid: true,
                error: None,
                supported_currencies: vec!["USD".to_string(), "EUR".to_string()],
            },
            "digital_wallet" => PaymentMethodValidation {
                method,
                valid: true,
                error: None,
                supported_currencies: vec![
                    "USD".to_string(),
                    "EUR".to_string(),
                    "GBP".to_string(),
                    "JPY".to_string(),
                ],
            },
            _ => PaymentMethodValidation {
                method,
                valid: false,
                error: Some("Unsupported payment method".to_string()),
                supported_currencies: vec![],
            },
        }
    }

    fn get_supported_methods() -> Vec<String> {
        vec![
            "credit_card".to_string(),
            "debit_card".to_string(),
            "bank_transfer".to_string(),
            "digital_wallet".to_string(),
        ]
    }

    fn get_supported_currencies() -> Vec<String> {
        vec![
            "USD".to_string(),
            "EUR".to_string(),
            "GBP".to_string(),
            "JPY".to_string(),
        ]
    }

    fn get_user_transactions(user_id: u32, offset: u32, limit: u32) -> Vec<PaymentResult> {
        // Mock implementation - in reality would filter by user_id
        get_transactions()
            .values()
            .skip(offset as usize)
            .take(limit as usize)
            .cloned()
            .collect()
    }

    fn get_transaction_details(transaction_id: String) -> Option<PaymentResult> {
        get_transactions().get(&transaction_id).cloned()
    }

    // Cross-service integration - mock user validation
    fn user_validation(user_id: u32) -> Result<bool, String> {
        // Mock user validation - in real implementation would call user service
        match user_id {
            1..=1000 => Ok(true), // Valid user ID range
            999 => Ok(false),     // Test user that fails validation
            _ => Err("User not found".to_string()),
        }
    }
}

// Component implementation exported via rust_wasm_component_bindgen build rule
