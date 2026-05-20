# Astrid WIT Interfaces

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/License-MIT%20OR%20Apache--2.0-blue.svg)](LICENSE-MIT)

**Canonical WIT contracts for [Astrid OS](https://github.com/unicity-astrid/astrid).**

This repo is the single source of truth for two kinds of typed contracts: capsule-to-capsule IPC interfaces (`interfaces/`) and the kernel-to-capsule host ABI (`host/`). The kernel and every SDK (Rust, JS/TS, Python, Go, etc.) submodule from this repo so contract drift across consumers becomes detectable instead of silent.

The Astrid CLI installs the capsule-to-capsule interfaces to `~/.astrid/wit/astrid/` during `astrid init` for offline `astrid build` resolution.

## Host ABI (`host/`)

The kernel-to-capsule contract. Capsules import these interfaces; the kernel provides the implementations. Lives outside `interfaces/` because the consumer set is fixed (the kernel + each SDK that wraps the imports) rather than open-ended.

| File | Package | Description |
|------|---------|-------------|
| `host/astrid-capsule.wit` | `astrid:capsule@0.1.0` | The 49 host functions across 11 domain-specific interfaces (`fs`, `ipc`, `kv`, `net`, `http`, `sys`, `process`, `elicit`, `approval`, `identity`, `uplink`, `types`) plus the 4 guest exports (`astrid-hook-trigger`, `run`, `astrid-install`, `astrid-upgrade`) that make up the `capsule` world. |

## Capsule interfaces (`interfaces/`)

The capsule-to-capsule contracts. Capsules declare which they import/export in `Capsule.toml`; the kernel validates at boot that every required import has a matching export.

| File | Package | Description |
|------|---------|-------------|
| `interfaces/llm.wit` | `astrid:llm@1.0.0` | LLM generation requests and streaming responses |
| `interfaces/session.wit` | `astrid:session@1.0.0` | Conversation session storage and retrieval |
| `interfaces/spark.wit` | `astrid:spark@1.0.0` | Agent identity and system prompt construction |
| `interfaces/context.wit` | `astrid:context@1.0.0` | Context window compaction and management |
| `interfaces/prompt.wit` | `astrid:prompt@1.0.0` | Prompt assembly from components |
| `interfaces/tool.wit` | `astrid:tool@1.0.0` | Tool dispatch and execution results |
| `interfaces/hook.wit` | `astrid:hook@1.0.0` | Lifecycle hook fan-out and response collection |
| `interfaces/registry.wit` | `astrid:registry@1.0.0` | Model registry operations |
| `interfaces/types.wit` | `astrid:types@1.0.0` | Shared types used across interfaces |
| `interfaces/users.wit` | `astrid:users@1.0.0` | Within-principal user identity store — platform-to-AstridUserId mapping |

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

SDKs use `wit-bindgen` (Rust), `ComponentizeJS` (JS/TS), or equivalent toolchains to generate typed bindings from these definitions. The generated types match the IPC payload schemas so capsule authors get compile-time type safety.

The kernel uses `wasmtime::component::bindgen!` against `host/astrid-capsule.wit` to generate the host-side trait the host implementations satisfy.

## Cross-repo coordination

Both kinds of WIT files change rarely but breakingly. The repos that submodule from here are:

- [`unicity-astrid/astrid`](https://github.com/unicity-astrid/astrid) -- kernel (host implementations bound to `host/astrid-capsule.wit`)
- [`unicity-astrid/sdk-rust`](https://github.com/unicity-astrid/sdk-rust) -- Rust SDK (guest bindings + capsule contracts)
- [`unicity-astrid/sdk-js`](https://github.com/unicity-astrid/sdk-js) -- JavaScript / TypeScript SDK (same)

When a contract changes here, each consumer bumps its submodule pointer. CI lints can compare submodule SHAs across consumers to catch silent drift.

## Related

- [Astrid OS](https://github.com/unicity-astrid/astrid) -- kernel and CLI
- [Rust SDK](https://github.com/unicity-astrid/sdk-rust) -- Rust capsule SDK
- [RFCs](https://github.com/unicity-astrid/rfcs) -- design proposals

## License

Dual-licensed under [MIT](LICENSE-MIT) and [Apache 2.0](LICENSE-APACHE).

Copyright (c) 2025-2026 Joshua J. Bouw and Unicity Labs.
