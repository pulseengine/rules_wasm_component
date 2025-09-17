// Mock Product Catalog Service implementation for local microservices architecture

use product_catalog_bindings::exports::microservices::catalog::catalog_management::{
    Guest as CatalogGuest, PriceUpdate, Product, SearchFilter,
};
use std::collections::HashMap;

// Mock product database
static mut PRODUCTS: Option<HashMap<u32, Product>> = None;
static mut NEXT_ID: u32 = 2000;

fn get_products() -> &'static mut HashMap<u32, Product> {
    unsafe {
        PRODUCTS.get_or_insert_with(|| {
            let mut products = HashMap::new();
            // Pre-populate with test products
            products.insert(
                1,
                Product {
                    id: 1,
                    name: "Wireless Headphones".to_string(),
                    description: "High-quality bluetooth headphones with noise cancellation"
                        .to_string(),
                    price: 159.99,
                    category: "Electronics".to_string(),
                    stock_quantity: 50,
                    active: true,
                    created_at: 1672531200,
                },
            );
            products.insert(
                2,
                Product {
                    id: 2,
                    name: "Running Shoes".to_string(),
                    description: "Comfortable running shoes for daily training".to_string(),
                    price: 89.99,
                    category: "Sports".to_string(),
                    stock_quantity: 25,
                    active: true,
                    created_at: 1672617600,
                },
            );
            products.insert(
                3,
                Product {
                    id: 3,
                    name: "Coffee Maker".to_string(),
                    description: "Automatic drip coffee maker with programmable timer".to_string(),
                    price: 79.99,
                    category: "Kitchen".to_string(),
                    stock_quantity: 0, // Out of stock
                    active: true,
                    created_at: 1672704000,
                },
            );
            products.insert(
                4,
                Product {
                    id: 4,
                    name: "Smartphone Case".to_string(),
                    description: "Protective case for latest smartphone models".to_string(),
                    price: 24.99,
                    category: "Electronics".to_string(),
                    stock_quantity: 100,
                    active: true,
                    created_at: 1672790400,
                },
            );
            products.insert(
                5,
                Product {
                    id: 5,
                    name: "Yoga Mat".to_string(),
                    description: "Non-slip yoga mat for indoor and outdoor practice".to_string(),
                    price: 39.99,
                    category: "Sports".to_string(),
                    stock_quantity: 30,
                    active: false, // Discontinued
                    created_at: 1672876800,
                },
            );
            products
        })
    }
}

// Component implementation
struct ProductCatalog;

impl CatalogGuest for ProductCatalog {
    fn get_product(product_id: u32) -> Option<Product> {
        get_products().get(&product_id).cloned()
    }

    fn create_product(
        name: String,
        description: String,
        price: f64,
        category: String,
        stock: u32,
    ) -> Result<u32, String> {
        if name.trim().is_empty() {
            return Err("Product name cannot be empty".to_string());
        }
        if price < 0.0 {
            return Err("Price cannot be negative".to_string());
        }

        unsafe {
            let product_id = NEXT_ID;
            NEXT_ID += 1;

            let product = Product {
                id: product_id,
                name,
                description,
                price,
                category,
                stock_quantity: stock,
                active: true,
                created_at: 1693843200, // Mock timestamp
            };

            get_products().insert(product_id, product);
            Ok(product_id)
        }
    }

    fn update_product(
        product_id: u32,
        name: Option<String>,
        description: Option<String>,
        price: Option<f64>,
    ) -> Result<(), String> {
        let products = get_products();
        let product = products
            .get_mut(&product_id)
            .ok_or_else(|| "Product not found".to_string())?;

        if let Some(new_name) = name {
            if new_name.trim().is_empty() {
                return Err("Product name cannot be empty".to_string());
            }
            product.name = new_name;
        }

        if let Some(new_description) = description {
            product.description = new_description;
        }

        if let Some(new_price) = price {
            if new_price < 0.0 {
                return Err("Price cannot be negative".to_string());
            }
            product.price = new_price;
        }

        Ok(())
    }

    fn delete_product(product_id: u32) -> Result<(), String> {
        match get_products().remove(&product_id) {
            Some(_) => Ok(()),
            None => Err("Product not found".to_string()),
        }
    }

    fn search_products(query: String, filter: Option<SearchFilter>) -> Vec<u32> {
        let products = get_products();
        let query_lower = query.to_lowercase();

        products
            .values()
            .filter(|product| {
                // Basic text search
                let matches_query = query.is_empty()
                    || product.name.to_lowercase().contains(&query_lower)
                    || product.description.to_lowercase().contains(&query_lower)
                    || product.category.to_lowercase().contains(&query_lower);

                if !matches_query {
                    return false;
                }

                // Apply filters if provided
                if let Some(ref f) = filter {
                    if let Some(ref category) = f.category {
                        if product.category != *category {
                            return false;
                        }
                    }

                    if let Some(min_price) = f.min_price {
                        if product.price < min_price {
                            return false;
                        }
                    }

                    if let Some(max_price) = f.max_price {
                        if product.price > max_price {
                            return false;
                        }
                    }

                    if f.in_stock_only && product.stock_quantity == 0 {
                        return false;
                    }
                }

                product.active
            })
            .map(|product| product.id)
            .collect()
    }

    fn get_products_by_category(category: String) -> Vec<u32> {
        get_products()
            .values()
            .filter(|product| product.active && product.category == category)
            .map(|product| product.id)
            .collect()
    }

    fn get_featured_products(limit: u32) -> Vec<u32> {
        get_products()
            .values()
            .filter(|product| product.active && product.stock_quantity > 0)
            .take(limit as usize)
            .map(|product| product.id)
            .collect()
    }

    fn get_price(product_id: u32) -> Option<f64> {
        get_products().get(&product_id).map(|product| product.price)
    }

    fn update_price(update: PriceUpdate) -> Result<(), String> {
        let products = get_products();
        let product = products
            .get_mut(&update.product_id)
            .ok_or_else(|| "Product not found".to_string())?;

        if update.new_price < 0.0 {
            return Err("Price cannot be negative".to_string());
        }

        product.price = update.new_price;
        Ok(())
    }

    fn check_stock(product_id: u32) -> Option<u32> {
        get_products()
            .get(&product_id)
            .map(|product| product.stock_quantity)
    }

    fn update_stock(product_id: u32, quantity: u32) -> Result<(), String> {
        let products = get_products();
        let product = products
            .get_mut(&product_id)
            .ok_or_else(|| "Product not found".to_string())?;

        product.stock_quantity = quantity;
        Ok(())
    }

    // Cross-service integration - mock user lookup
    fn user_lookup(user_id: u32) -> Option<String> {
        // Mock user lookup - in real implementation would call user service
        match user_id {
            1 => Some("Alice Johnson".to_string()),
            2 => Some("Bob Smith".to_string()),
            3 => Some("Carol Wilson".to_string()),
            _ => None,
        }
    }
}

// Component implementation exported via rust_wasm_component_bindgen build rule
