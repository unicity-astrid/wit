# Astrid WIT Interfaces

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/License-MIT%20OR%20Apache--2.0-blue.svg)](LICENSE-MIT)

**Canonical WIT interface definitions for [Astrid OS](https://github.com/unicity-astrid/astrid).**

This repo is the single source of truth for the typed contracts between capsules. All SDKs (Rust, Python, Go, etc.) generate bindings from these definitions. The Astrid CLI installs them to `~/.astrid/wit/astrid/` during `astrid init`.

## Interfaces

| File | Package | Description |
|------|---------|-------------|
| `llm.wit` | `astrid:llm@1.0.0` | LLM generation requests and streaming responses |
| `session.wit` | `astrid:session@1.0.0` | Conversation session storage and retrieval |
| `spark.wit` | `astrid:spark@1.0.0` | Agent identity and system prompt construction |
| `context.wit` | `astrid:context@1.0.0` | Context window compaction and management |
| `prompt.wit` | `astrid:prompt@1.0.0` | Prompt assembly from components |
| `tool.wit` | `astrid:tool@1.0.0` | Tool dispatch and execution results |
| `hook.wit` | `astrid:hook@1.0.0` | Lifecycle hook fan-out and response collection |
| `registry.wit` | `astrid:registry@1.0.0` | Model registry operations |
| `types.wit` | `astrid:types@1.0.0` | Shared types used across interfaces |

## How capsules use these

Capsules declare which interfaces they import and export in their `Capsule.toml`:

```toml
[imports.astrid]
llm = "^1.0"
session = { version = "^1.0", optional = true }

[exports.astrid]
session = "1.0.0"
```

The kernel validates at boot that every required import has a matching export from another loaded capsule. The WIT files define the message schemas carried over the IPC bus.

## How SDKs use these

SDKs use `wit-bindgen` (or equivalent) to generate typed bindings from these definitions. The generated types match the IPC payload schemas so capsule authors get compile-time type safety.

## Related

- [Astrid OS](https://github.com/unicity-astrid/astrid) -- kernel and CLI
- [Rust SDK](https://github.com/unicity-astrid/sdk-rust) -- Rust capsule SDK
- [RFCs](https://github.com/unicity-astrid/rfcs) -- design proposals

## License

Dual-licensed under [MIT](LICENSE-MIT) and [Apache 2.0](LICENSE-APACHE).

Copyright (c) 2025-2026 Joshua J. Bouw and Unicity Labs.
