"""Mock microservices components for testing and CI builds

These components simulate the external services that would normally be pulled
from various OCI registries (ghcr.io, docker.io, etc.) in a real deployment.
"""

use wit_bindgen::generate;

generate!({
    world: "microservices-world",  
    path: "../wit",
});

// Mock User Service Implementation
pub struct UserService;

impl exports::microservices::user_service::Guest for UserService {
    fn get_user(user_id: u32) -> String {
        format!("Mock User {}", user_id)
    }
    
    fn create_user(name: String, email: String) -> u32 {
        // Mock user creation returning fake user ID
        12345
    }
    
    fn authenticate(user_id: u32, token: String) -> bool {
        // Mock authentication - always succeeds for demo
        true
    }
}

// Mock Product Catalog Implementation  
pub struct ProductCatalog;

impl exports::microservices::product_catalog::Guest for ProductCatalog {
    fn get_product(product_id: u32) -> String {
        format!("Mock Product {} - Sample Item", product_id)
    }
    
    fn search_products(query: String) -> Vec<u32> {
        // Mock search results
        vec![1, 2, 3, 4, 5]
    }
    
    fn get_price(product_id: u32) -> f64 {
        // Mock pricing
        19.99
    }
}

// Mock Payment Processor
pub struct PaymentProcessor;

impl exports::microservices::payment_processor::Guest for PaymentProcessor {
    fn process_payment(amount: f64, payment_method: String) -> bool {
        // Mock payment processing - always succeeds for demo
        true
    }
    
    fn validate_payment_method(payment_method: String) -> bool {
        !payment_method.is_empty()
    }
}

// Mock Notification Service
pub struct NotificationService; 

impl exports::microservices::notification_service::Guest for NotificationService {
    fn send_email(to: String, subject: String, body: String) -> bool {
        println!("Mock Email: {} - {}", subject, to);
        true
    }
    
    fn send_push_notification(user_id: u32, message: String) -> bool {
        println!("Mock Push: User {} - {}", user_id, message);
        true
    }
}

// Export the mock service implementations
wit_bindgen::export!(UserService with_types_in wit_bindgen);
wit_bindgen::export!(ProductCatalog with_types_in wit_bindgen);  
wit_bindgen::export!(PaymentProcessor with_types_in wit_bindgen);
wit_bindgen::export!(NotificationService with_types_in wit_bindgen);