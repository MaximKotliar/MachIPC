# MachIPC

A Swift library for Mach-based Inter-Process Communication (IPC) on Darwin systems (macOS, iOS, etc.). MachIPC provides a high-level, type-safe API for sending and receiving messages between processes using Mach ports.

## ⚠️ Status

**This project is work in progress.** The API may change and features may be incomplete.

## TODO

- [ ] Extensive tests
- [ ] Add secure layer
- [ ] Proper benchmarks
- [ ] RPC layer
- [ ] Codegen over RPC (protobuf?)

## Features

- **Type-safe messaging**: Protocol-based message system with `MachMessageConvertible`
- **Local and remote communication**: Automatically handles both in-process and cross-process messaging
- **Bootstrap service integration**: Uses Mach bootstrap services for service discovery
- **Zero-copy local optimization**: Direct message passing for in-process communication
- **Logger support**: Optional logging for debugging and monitoring
- **Swift concurrency ready**: Built with `Sendable` conformance for modern Swift

## Performance

MachIPC is optimized for high-throughput messaging:

- **~400,000 messages per second** on a single core
- **~2.5 microseconds** per message latency
- **At least 2x faster** than XPC for message passing

These benchmarks demonstrate the efficiency of direct Mach message passing compared to higher-level IPC frameworks.

## Security

⚠️ **Important**: Messages sent through MachIPC are **not encrypted**. Do not use this library for transmitting sensitive information such as passwords, authentication tokens, or personal data without additional encryption.

A separate secure layer is planned for future releases to provide end-to-end encryption for sensitive communications.

## Requirements

- Swift 5.4 or later
- macOS, iOS, or other Darwin-based systems

## Installation

### Swift Package Manager

Add MachIPC to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MaximKotliar/MachIPC", branch: "master")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies...
2. Enter the repository URL
3. Select the master branch

## Usage

### Basic Example

#### Creating a Host (Receiver)

```swift
import MachIPC

// Create a host that listens for messages
let host = try MachHost<String>(endpoint: "com.example.service")

// Set up message handler
host.callback = { message in
    print("Received message: \(message)")
}

// Keep the host alive (e.g., in your app's lifecycle)
```

#### Creating a Client (Sender)

```swift
import MachIPC

// Create a client to send messages
let client = try MachClient<String>(endpoint: "com.example.service")

// Send a message
try client.sendMessage("Hello, Mach IPC!")
```

### Custom Message Types

Implement `MachMessageConvertible` for your custom types:

```swift
struct MyMessage: MachMessageConvertible {
    let id: Int
    let data: String
    
    init(machPayload: Data) {
        // Deserialize from Data
        let decoder = JSONDecoder()
        self = try! decoder.decode(MyMessage.self, from: machPayload)
    }
    
    var machPayload: Data {
        // Serialize to Data
        let encoder = JSONEncoder()
        return try! encoder.encode(self)
    }
}

// Use with MachHost and MachClient
let host = try MachHost<MyMessage>(endpoint: "com.example.service")
let client = try MachClient<MyMessage>(endpoint: "com.example.service")
```

### Logging

The logging system is designed to be flexible: conform to the `Logger` protocol for custom logging implementations, or use the provided `ConsoleLogger` for simple print-based logging.

```swift
// Use the provided ConsoleLogger for simple prints
let logger = ConsoleLogger()
let host = try MachHost<String>(endpoint: "com.example.service", logger: logger)
let client = try MachClient<String>(endpoint: "com.example.service", logger: logger)

// Or implement your own Logger
struct MyLogger: Logger {
    func log(_ level: Int32, _ message: String) {
        // Custom logging implementation
    }
}
```

⚠️ **Performance Note**: In high-speed scenarios, logging can become a bottleneck and significantly impact throughput. Use logging carefully and consider disabling it in production builds or using asynchronous logging implementations.

## Architecture

### Components

- **`MachHost<Message>`**: Receives messages on a registered endpoint
  - Registers with Mach bootstrap service for remote access
  - Uses `DispatchSourceMachReceive` for asynchronous message reception
  - Supports local in-process message passing for performance

- **`MachClient<Message>`**: Sends messages to a registered endpoint
  - Automatically resolves local or remote endpoints
  - Uses Mach message passing for cross-process communication
  - Falls back to direct in-process calls when possible

- **`MachMessageConvertible`**: Protocol for message types
  - Provides serialization/deserialization to/from `Data`
  - Built-in support for `Data` and `String` types

- **`MachLocalhostRegistry`**: Manages in-process endpoint registry
  - Enables zero-copy local message passing
  - Thread-safe endpoint lookup

### Message Flow

1. **Local (in-process)**:
   - Client automatically resolves if host is in the same process via local registry
   - Direct function call to host's callback
   - Zero-copy message passing
   - Note: Local resolution can be disabled via `MachLocalhostRegistry.shared.isLookupEnabled`

2. **Remote (cross-process)**:
   - Client looks up endpoint via bootstrap service
   - Message serialized to `Data` and sent via Mach message
   - Host receives message via `DispatchSourceMachReceive`
   - Message deserialized and passed to callback

## License

This project is licensed under the MIT License.

## Contributing
Contributions are welcome! Please note that this project is work in progress, so expect API changes.
