// Mock User Service implementation for local microservices architecture

use user_service_bindings::exports::microservices::user::user_management::{Guest as UserServiceGuest, User, AuthResult};
use std::collections::HashMap;

// Mock user database
static mut USERS: Option<HashMap<u32, User>> = None;
static mut NEXT_ID: u32 = 1000;

fn get_users() -> &'static mut HashMap<u32, User> {
    unsafe {
        USERS.get_or_insert_with(|| {
            let mut users = HashMap::new();
            // Pre-populate with test users
            users.insert(1, User {
                id: 1,
                name: "Alice Johnson".to_string(),
                email: "alice@example.com".to_string(),
                created_at: 1672531200, // Jan 1, 2023
                active: true,
            });
            users.insert(2, User {
                id: 2,
                name: "Bob Smith".to_string(),
                email: "bob@example.com".to_string(),
                created_at: 1672617600, // Jan 2, 2023
                active: true,
            });
            users.insert(3, User {
                id: 3,
                name: "Carol Wilson".to_string(),
                email: "carol@example.com".to_string(),
                created_at: 1672704000, // Jan 3, 2023
                active: false,
            });
            users
        })
    }
}

// Component implementation
struct UserService;

impl UserServiceGuest for UserService {
    fn get_user(user_id: u32) -> Option<User> {
        get_users().get(&user_id).cloned()
    }

    fn create_user(name: String, email: String) -> Result<u32, String> {
        if name.trim().is_empty() {
            return Err("Name cannot be empty".to_string());
        }
        if email.trim().is_empty() || !email.contains('@') {
            return Err("Invalid email address".to_string());
        }

        // Check if email already exists
        for user in get_users().values() {
            if user.email == email {
                return Err("Email already exists".to_string());
            }
        }

        unsafe {
            let user_id = NEXT_ID;
            NEXT_ID += 1;

            let user = User {
                id: user_id,
                name,
                email,
                created_at: 1693843200, // Mock timestamp
                active: true,
            };

            get_users().insert(user_id, user);
            Ok(user_id)
        }
    }

    fn update_user(user_id: u32, name: Option<String>, email: Option<String>) -> Result<(), String> {
        let users = get_users();
        
        // Check if user exists first
        if !users.contains_key(&user_id) {
            return Err("User not found".to_string());
        }

        // Validate email uniqueness before getting mutable reference
        if let Some(ref new_email) = email {
            if new_email.trim().is_empty() || !new_email.contains('@') {
                return Err("Invalid email address".to_string());
            }
            // Check if email already exists for a different user
            for (id, existing_user) in users.iter() {
                if *id != user_id && existing_user.email == *new_email {
                    return Err("Email already exists".to_string());
                }
            }
        }

        // Now get mutable reference and update
        let user = users.get_mut(&user_id).unwrap(); // Safe because we checked above

        if let Some(new_name) = name {
            if new_name.trim().is_empty() {
                return Err("Name cannot be empty".to_string());
            }
            user.name = new_name;
        }

        if let Some(new_email) = email {
            user.email = new_email;
        }

        Ok(())
    }

    fn delete_user(user_id: u32) -> Result<(), String> {
        match get_users().remove(&user_id) {
            Some(_) => Ok(()),
            None => Err("User not found".to_string()),
        }
    }

    fn authenticate(user_id: u32, token: String) -> AuthResult {
        // Mock authentication - check if user exists and is active
        match get_users().get(&user_id) {
            Some(user) if user.active => {
                // Simple token validation (mock)
                if token.starts_with("valid-token-") {
                    AuthResult {
                        success: true,
                        user_id: Some(user_id),
                        token: Some(format!("session-{}-{}", user_id, "authenticated")),
                        error: None,
                    }
                } else {
                    AuthResult {
                        success: false,
                        user_id: None,
                        token: None,
                        error: Some("Invalid token".to_string()),
                    }
                }
            }
            Some(_) => AuthResult {
                success: false,
                user_id: None,
                token: None,
                error: Some("User account is inactive".to_string()),
            },
            None => AuthResult {
                success: false,
                user_id: None,
                token: None,
                error: Some("User not found".to_string()),
            },
        }
    }

    fn validate_token(token: String) -> Result<u32, String> {
        // Mock token validation
        if token.starts_with("session-") {
            // Extract user ID from mock session token
            let parts: Vec<&str> = token.split('-').collect();
            if parts.len() >= 2 {
                match parts[1].parse::<u32>() {
                    Ok(user_id) => {
                        if get_users().contains_key(&user_id) {
                            Ok(user_id)
                        } else {
                            Err("Token references non-existent user".to_string())
                        }
                    }
                    Err(_) => Err("Invalid token format".to_string()),
                }
            } else {
                Err("Invalid token format".to_string())
            }
        } else {
            Err("Invalid token".to_string())
        }
    }

    fn find_user_by_email(email: String) -> Option<User> {
        get_users().values().find(|user| user.email == email).cloned()
    }

    fn list_users(offset: u32, limit: u32) -> Vec<User> {
        get_users()
            .values()
            .skip(offset as usize)
            .take(limit as usize)
            .cloned()
            .collect()
    }
}

// Component implementation exported via rust_wasm_component_bindgen build rule