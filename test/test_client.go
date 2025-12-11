package main

import (
	"context"
	"fmt"
	"log"
	"time"

	// Go module path to the protos
	"github.com/DonaldLucy/faasd/pkg/junctiond"
)

// The path to the Unix Domain Socket file that the C++ server is listening on.
// **FIXED: Changed from /tmp/junctiond.sock to /run/junctiond.sock
// based on previous terminal output.**
const socketPath = "/run/junctiond.sock" 

func main() {
	// 1. Setup Context and Timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	fmt.Printf("1. Connecting to junctiond daemon at %s...\n", socketPath)

	// 2. Instantiate the Client
	client, err := junctiond.New(socketPath)
	if err != nil {
		log.Fatalf("❌ Failed to create client: %v", err)
	}
	defer client.Close()
	fmt.Println("✅ Connection established.")

	// --- TEST 1: SPAWN COMMAND ---
	fmt.Println("\n--- TEST 1: Calling client.Spawn ---")

	// Data for the function you want to "spawn"
	testData := &junctiond.FunctionData{
		Name:     "test-func-httpd",
		Rootfs:   "/var/lib/faasd/rootfs",
		Cpu:      1,
		MemoryMB: 256,
	}

	// Call the high-level Spawn method in your client wrapper
	spawnErr := client.Spawn(ctx, testData)

	if spawnErr != nil {
		log.Printf("⚠️ Spawn returned a failure (Checking logic): %v\n", spawnErr)
	} else {
		fmt.Println("✅ Spawn Succeeded (Server returned success=true).")
	}

	// --- TEST 2: LIST COMMAND ---
	fmt.Println("\n--- TEST 2: Calling client.List ---")

	functions, listErr := client.List(ctx)
	if listErr != nil {
		log.Fatalf("❌ List Failed: %v", listErr)
	}

	fmt.Printf("✅ List Succeeded. Found %d running functions.\n", len(functions))
	if len(functions) > 0 {
		// Assuming FunctionStatus has a GetName() method
		fmt.Printf("  First function name: %s\n", functions[0].GetName())
	}

	// --- TEST 3: REMOVE COMMAND ---
	fmt.Println("\n--- TEST 3: Calling client.Remove ---")

	removeErr := client.Remove(ctx, testData.Name)
	if removeErr != nil {
		log.Printf("⚠️ Remove Failed (Checking logic): %v\n", removeErr)
	} else {
		fmt.Println("✅ Remove Succeeded.")
	}

	fmt.Println("\nTest sequence complete.")
}