use service_b_component_bindings::exports::test::service_b::api::Guest;
use service_b_component_bindings::test::service_a::storage;

struct Component;

impl Guest for Component {
    fn create_user(name: String, email: String) -> u32 {
        let id = name.len() as u32 + email.len() as u32; // Simple ID generation
        let user_data = format!("{}:{}", name, email);
        storage::store(&id.to_string(), &user_data);
        id
    }

    fn get_user(id: u32) -> Option<String> {
        storage::retrieve(&id.to_string())
    }
}

service_b_component_bindings::export!(Component with_types_in service_b_component_bindings);
