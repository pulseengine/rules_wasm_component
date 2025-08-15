use wit_bindgen::generate;

// Generate bindings for the hello-world interface
generate!({
    world: "hello-world",
    exports: {
        "component:hello-world/hello": HelloWorld,
    },
});

struct HelloWorld;

impl Guest for HelloWorld {
    fn hello() -> String {
        "Hello from WebAssembly OCI component!".to_string()
    }
}

impl exports::component::hello_world::hello::Guest for HelloWorld {
    fn hello() -> String {
        "Hello from WebAssembly OCI component!".to_string()
    }
}
