package main

import "fmt"

func main() {
	// Test calling functions from other Go files in same package
	result := TestFunction("Multi-file Go component test")
	fmt.Println(result)
	
	// Test mathematical operations
	sum := Add(5, 3)
	product := Multiply(4, 6)
	fmt.Printf("Add(5, 3) = %d\n", sum)
	fmt.Printf("Multiply(4, 6) = %d\n", product)
	
	// This demonstrates the complete TinyGo + Component Model pipeline working with multiple Go files!
}
