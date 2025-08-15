/*
Simple Go WebAssembly Component

This is a minimal Go component to test TinyGo + WASI Preview 2 basic functionality
without complex networking dependencies.
*/

package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Println("Hello from TinyGo WebAssembly Component!")
	fmt.Printf("Arguments: %v\n", os.Args)
}
