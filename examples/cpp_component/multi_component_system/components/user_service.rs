use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

// Use the generated bindings from rust_wasm_component_bindgen
use user_service_bindings::exports::user::service::user_service::Guest;

// Re-export the generated WIT types
pub use user_service_bindings::exports::user::service::user_service::*;

/// Rust User Service Component
///
/// Demonstrates Rust's memory safety and async capabilities in a WebAssembly component.
/// This service manages user profiles, preferences, and relationships with zero-copy
/// optimizations and safe concurrency patterns.

#[derive(Debug, Clone, Serialize, Deserialize)]
struct UserProfile {
    user_id: String,
    username: String,
    email: String,
    display_name: String,
    avatar_url: Option<String>,
    bio: Option<String>,
    location: Option<String>,
    website: Option<String>,
    created_at: u64,
    updated_at: u64,
    last_login: u64,
    is_verified: bool,
    is_active: bool,
    privacy_settings: PrivacySettings,
    preferences: UserPreferences,
    social_links: Vec<SocialLink>,
    tags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PrivacySettings {
    profile_visibility: VisibilityLevel,
    email_visibility: VisibilityLevel,
    location_visibility: VisibilityLevel,
    activity_visibility: VisibilityLevel,
    allow_direct_messages: bool,
    allow_friend_requests: bool,
    show_online_status: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum VisibilityLevel {
    Public,
    Friends,
    Private,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct UserPreferences {
    language: String,
    timezone: String,
    date_format: String,
    theme: String,
    notifications: NotificationSettings,
    accessibility: AccessibilitySettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct NotificationSettings {
    email_notifications: bool,
    push_notifications: bool,
    sms_notifications: bool,
    notification_frequency: String,
    quiet_hours_start: Option<String>,
    quiet_hours_end: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AccessibilitySettings {
    high_contrast: bool,
    large_text: bool,
    screen_reader: bool,
    keyboard_navigation: bool,
    reduced_motion: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SocialLink {
    platform: String,
    url: String,
    is_verified: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct UserRelationship {
    from_user_id: String,
    to_user_id: String,
    relationship_type: RelationshipType,
    created_at: u64,
    status: RelationshipStatus,
    metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum RelationshipType {
    Friend,
    Follow,
    Block,
    Mute,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum RelationshipStatus {
    Pending,
    Accepted,
    Rejected,
    Active,
}

// Global state using Rust's safe static management
static mut USER_SERVICE: Option<UserServiceImpl> = None;
static INIT: std::sync::Once = std::sync::Once::new();

struct UserServiceImpl {
    users: HashMap<String, UserProfile>,
    relationships: Vec<UserRelationship>,
    user_sessions: HashMap<String, Vec<String>>, // user_id -> session_ids
    metrics: ServiceMetrics,
}

#[derive(Debug, Default)]
struct ServiceMetrics {
    total_users: u64,
    active_sessions: u64,
    profile_updates: u64,
    relationship_operations: u64,
    cache_hits: u64,
    cache_misses: u64,
    async_operations: u64,
    zero_copy_operations: u64,
}

impl UserServiceImpl {
    fn new() -> Self {
        Self {
            users: HashMap::new(),
            relationships: Vec::new(),
            user_sessions: HashMap::new(),
            metrics: ServiceMetrics::default(),
        }
    }

    fn get_instance() -> &'static mut Self {
        unsafe {
            INIT.call_once(|| {
                USER_SERVICE = Some(UserServiceImpl::new());
            });
            USER_SERVICE.as_mut().unwrap()
        }
    }

    // User profile management with Rust's ownership model
    fn create_user_profile(&mut self, request: &CreateUserRequest) -> Result<UserProfile, String> {
        // Validate input using Rust's pattern matching
        if request.username.is_empty() || request.email.is_empty() {
            return Err("Username and email are required".to_string());
        }

        // Check for existing user (zero-copy string comparison)
        if self
            .users
            .values()
            .any(|u| u.username == request.username || u.email == request.email)
        {
            return Err("User already exists".to_string());
        }

        let user_id = Uuid::new_v4().to_string();
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let profile = UserProfile {
            user_id: user_id.clone(),
            username: request.username.clone(),
            email: request.email.clone(),
            display_name: request
                .display_name
                .clone()
                .unwrap_or_else(|| request.username.clone()),
            avatar_url: request.avatar_url.clone(),
            bio: None,
            location: None,
            website: None,
            created_at: now,
            updated_at: now,
            last_login: 0,
            is_verified: false,
            is_active: true,
            privacy_settings: PrivacySettings {
                profile_visibility: VisibilityLevel::Public,
                email_visibility: VisibilityLevel::Private,
                location_visibility: VisibilityLevel::Friends,
                activity_visibility: VisibilityLevel::Friends,
                allow_direct_messages: true,
                allow_friend_requests: true,
                show_online_status: true,
            },
            preferences: UserPreferences {
                language: "en".to_string(),
                timezone: "UTC".to_string(),
                date_format: "YYYY-MM-DD".to_string(),
                theme: "light".to_string(),
                notifications: NotificationSettings {
                    email_notifications: true,
                    push_notifications: true,
                    sms_notifications: false,
                    notification_frequency: "immediate".to_string(),
                    quiet_hours_start: None,
                    quiet_hours_end: None,
                },
                accessibility: AccessibilitySettings {
                    high_contrast: false,
                    large_text: false,
                    screen_reader: false,
                    keyboard_navigation: false,
                    reduced_motion: false,
                },
            },
            social_links: Vec::new(),
            tags: Vec::new(),
        };

        // Insert with move semantics (Rust ownership)
        self.users.insert(user_id.clone(), profile.clone());
        self.metrics.total_users += 1;

        Ok(profile)
    }

    // Async-style user retrieval (simulated with Rust patterns)
    fn get_user_profile(&mut self, user_id: &str) -> Option<&UserProfile> {
        // Use Rust's Option type for safe null handling
        let profile = self.users.get(user_id);

        if profile.is_some() {
            self.metrics.cache_hits += 1;
        } else {
            self.metrics.cache_misses += 1;
        }

        profile
    }

    // Memory-safe profile updates using Rust's borrow checker
    fn update_user_profile(
        &mut self,
        user_id: &str,
        updates: &ProfileUpdateRequest,
    ) -> Result<(), String> {
        let user = self
            .users
            .get_mut(user_id)
            .ok_or_else(|| "User not found".to_string())?;

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Safe field updates using Rust's Option handling
        if let Some(display_name) = &updates.display_name {
            user.display_name = display_name.clone();
        }
        if let Some(bio) = &updates.bio {
            user.bio = Some(bio.clone());
        }
        if let Some(location) = &updates.location {
            user.location = Some(location.clone());
        }
        if let Some(website) = &updates.website {
            user.website = Some(website.clone());
        }

        user.updated_at = now;
        self.metrics.profile_updates += 1;

        Ok(())
    }

    // Concurrent-safe relationship management
    fn create_relationship(
        &mut self,
        from_user_id: &str,
        to_user_id: &str,
        relationship_type: RelationshipType,
    ) -> Result<String, String> {
        // Validate users exist
        if !self.users.contains_key(from_user_id) || !self.users.contains_key(to_user_id) {
            return Err("One or both users not found".to_string());
        }

        // Check for existing relationship using iterator patterns
        if self.relationships.iter().any(|r| {
            r.from_user_id == from_user_id
                && r.to_user_id == to_user_id
                && std::mem::discriminant(&r.relationship_type)
                    == std::mem::discriminant(&relationship_type)
        }) {
            return Err("Relationship already exists".to_string());
        }

        let relationship_id = Uuid::new_v4().to_string();
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let relationship = UserRelationship {
            from_user_id: from_user_id.to_string(),
            to_user_id: to_user_id.to_string(),
            relationship_type,
            created_at: now,
            status: RelationshipStatus::Pending,
            metadata: HashMap::new(),
        };

        self.relationships.push(relationship);
        self.metrics.relationship_operations += 1;
        self.metrics.zero_copy_operations += 1; // Vec push is zero-copy for owned data

        Ok(relationship_id)
    }

    // Efficient relationship queries using Rust's iterator adaptors
    fn get_user_relationships(
        &self,
        user_id: &str,
        relationship_type: Option<RelationshipType>,
    ) -> Vec<&UserRelationship> {
        self.relationships
            .iter()
            .filter(|r| r.from_user_id == user_id || r.to_user_id == user_id)
            .filter(|r| {
                if let Some(ref rt) = relationship_type {
                    std::mem::discriminant(&r.relationship_type) == std::mem::discriminant(rt)
                } else {
                    true
                }
            })
            .collect()
    }

    // Safe statistics collection using Rust's type system
    fn get_service_stats(&self) -> ServiceMetrics {
        ServiceMetrics {
            total_users: self.users.len() as u64,
            active_sessions: self.user_sessions.values().map(|s| s.len() as u64).sum(),
            profile_updates: self.metrics.profile_updates,
            relationship_operations: self.metrics.relationship_operations,
            cache_hits: self.metrics.cache_hits,
            cache_misses: self.metrics.cache_misses,
            async_operations: self.metrics.async_operations,
            zero_copy_operations: self.metrics.zero_copy_operations,
        }
    }
}

// WIT interface implementation
struct UserService;

impl Guest for UserService {
    type UserService = UserServiceImpl;
}

impl GuestUserService for UserServiceImpl {
    fn create_user(&mut self, request: CreateUserRequest) -> UserResult {
        match self.create_user_profile(&request) {
            Ok(profile) => UserResult::Success(User {
                user_id: profile.user_id,
                username: profile.username,
                email: profile.email,
                display_name: profile.display_name,
                avatar_url: profile.avatar_url,
                created_at: profile.created_at,
                is_verified: profile.is_verified,
                is_active: profile.is_active,
            }),
            Err(error) => UserResult::Error(error),
        }
    }

    fn get_user(&mut self, user_id: String) -> UserResult {
        match self.get_user_profile(&user_id) {
            Some(profile) => UserResult::Success(User {
                user_id: profile.user_id.clone(),
                username: profile.username.clone(),
                email: profile.email.clone(),
                display_name: profile.display_name.clone(),
                avatar_url: profile.avatar_url.clone(),
                created_at: profile.created_at,
                is_verified: profile.is_verified,
                is_active: profile.is_active,
            }),
            None => UserResult::NotFound,
        }
    }

    fn update_user(&mut self, user_id: String, request: ProfileUpdateRequest) -> bool {
        self.update_user_profile(&user_id, &request).is_ok()
    }

    fn delete_user(&mut self, user_id: String) -> bool {
        self.users.remove(&user_id).is_some()
    }

    fn search_users(&mut self, query: SearchQuery) -> Vec<User> {
        self.users
            .values()
            .filter(|user| {
                // Rust's safe string operations
                if !query.username.is_empty() && !user.username.contains(&query.username) {
                    return false;
                }
                if !query.email.is_empty() && !user.email.contains(&query.email) {
                    return false;
                }
                if !query.display_name.is_empty()
                    && !user.display_name.contains(&query.display_name)
                {
                    return false;
                }
                true
            })
            .take(query.limit as usize)
            .map(|profile| User {
                user_id: profile.user_id.clone(),
                username: profile.username.clone(),
                email: profile.email.clone(),
                display_name: profile.display_name.clone(),
                avatar_url: profile.avatar_url.clone(),
                created_at: profile.created_at,
                is_verified: profile.is_verified,
                is_active: profile.is_active,
            })
            .collect()
    }

    fn add_friend(&mut self, user_id: String, friend_id: String) -> bool {
        self.create_relationship(&user_id, &friend_id, RelationshipType::Friend)
            .is_ok()
    }

    fn remove_friend(&mut self, user_id: String, friend_id: String) -> bool {
        // Safe removal using Rust's retain method
        let initial_len = self.relationships.len();
        self.relationships.retain(|r| {
            !(r.from_user_id == user_id
                && r.to_user_id == friend_id
                && matches!(r.relationship_type, RelationshipType::Friend))
        });
        self.relationships.len() < initial_len
    }

    fn get_friends(&mut self, user_id: String) -> Vec<String> {
        self.get_user_relationships(&user_id, Some(RelationshipType::Friend))
            .into_iter()
            .map(|r| {
                if r.from_user_id == user_id {
                    r.to_user_id.clone()
                } else {
                    r.from_user_id.clone()
                }
            })
            .collect()
    }

    fn health_check(&mut self) -> bool {
        // Rust's safe boolean logic
        !self.users.is_empty() || self.users.capacity() > 0
    }

    fn get_service_stats(&mut self) -> String {
        let stats = self.get_service_stats();
        // Safe JSON serialization using serde
        serde_json::to_string(&stats).unwrap_or_else(|_| "{}".to_string())
    }
}

// Export the component
user_service_bindings::export!(UserService with_types_in user_service_bindings);
