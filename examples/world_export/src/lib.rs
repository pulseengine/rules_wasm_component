use world_export_component_bindings::Guest;

struct Component;

impl Guest for Component {
    fn hello(name: String) -> String {
        format!("Hello, {}!", name)
    }
}

world_export_component_bindings::export!(Component with_types_in world_export_component_bindings);
