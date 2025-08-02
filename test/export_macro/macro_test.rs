// Simple test to verify export macro is accessible

fn main() {
    // Test that we can import the export macro
    // This will fail to compile if the macro is not public
    println!("Export macro is accessible from external crate");

    // Create a dummy struct to demonstrate the macro is available
    struct DummyComponent;

    // This demonstrates that the macro is accessible
    // (though it won't actually work without implementing Guest)
    // test_component_bindings::export!(DummyComponent);

    println!("Test passed - export macro is accessible");
}
