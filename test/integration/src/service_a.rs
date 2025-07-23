use service_a_component_bindings::exports::test::service_a::storage::Guest;
use std::collections::HashMap;
use std::sync::Mutex;

static STORAGE: Mutex<HashMap<String, String>> = Mutex::new(HashMap::new());

struct Component;

impl Guest for Component {
    fn store(key: String, value: String) {
        let mut storage = STORAGE.lock().unwrap();
        storage.insert(key, value);
    }
    
    fn retrieve(key: String) -> Option<String> {
        let storage = STORAGE.lock().unwrap();
        storage.get(&key).cloned()
    }
}

service_a_component_bindings::export!(Component with_types_in service_a_component_bindings);