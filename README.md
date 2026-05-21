# Astrid WIT Interfaces

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/License-MIT%20OR%20Apache--2.0-blue.svg)](LICENSE-MIT)

**Canonical WIT contracts for [Astrid OS](https://github.com/unicity-astrid/astrid).**

This repo is the single source of truth for two kinds of typed contracts: capsule-to-capsule IPC interfaces (`interfaces/`) and the kernel-to-capsule host ABI (`host/`). The kernel and every SDK (Rust, JS/TS, Python, Go, etc.) submodule from this repo so contract drift across consumers becomes detectable instead of silent.

The Astrid CLI installs the capsule-to-capsule interfaces to `~/.astrid/wit/astrid/` during `astrid init` for offline `astrid build` resolution.

## Host ABI (`host/`)

The kernel-to-capsule contract. Capsules import these interfaces; the kernel provides the implementations. Lives outside `interfaces/` because the consumer set is fixed (the kernel + each SDK that wraps the imports) rather than open-ended.

Each domain is its own package, frozen at a per-file version. A capsule imports only the domains it uses; bumping one domain does not affect capsules that do not import it.

| File | Package | Description |
|------|---------|-------------|
| `host/fs@1.0.0.wit` | `astrid:fs@1.0.0` | Filesystem operations within the workspace boundary — whole-file IO, file handles with positional read/write, metadata, canonicalize, read-link, hard-link. |
| `host/ipc@1.0.0.wit` | `astrid:ipc@1.0.0` | Publish/subscribe IPC event bus. |
| `host/uplink@1.0.0.wit` | `astrid:uplink@1.0.0` | Inbound message ingestion from external platforms. |
| `host/kv@1.0.0.wit` | `astrid:kv@1.0.0` | Per-capsule, per-principal key-value storage with atomic compare-and-swap and paginated key listing. |
| `host/net@1.0.0.wit` | `astrid:net@1.0.0` | Unix-domain sockets, gated outbound TCP, inbound TCP listener, gated UDP (unconnected + connected mode), gated DNS resolution. |
| `host/http@1.0.0.wit` | `astrid:http@1.0.0` | HTTP client with SSRF protection and streaming. |
| `host/sys@1.0.0.wit` | `astrid:sys@1.0.0` | Logging, config, time, caller context, entropy, sleep, capability introspection. |
| `host/process@1.0.0.wit` | `astrid:process@1.0.0` | OS-sandboxed host process spawn (with stdin/env/cwd), wait, signal, kill, read-logs, stdin streaming. |
| `host/elicit@1.0.0.wit` | `astrid:elicit@1.0.0` | Interactive user input during install/upgrade lifecycle. |
| `host/approval@1.0.0.wit` | `astrid:approval@1.0.0` | Human-in-the-loop approval gate for sensitive actions. |
| `host/identity@1.0.0.wit` | `astrid:identity@1.0.0` | Multi-platform identity resolve and link. |
| `host/guest@1.0.0.wit` | `astrid:guest@1.0.0` | Guest export contract — `astrid-hook-trigger`, `run`, `astrid-install`, `astrid-upgrade`. Each entry point lives in its own world (`interceptor`, `background`, `installable`, `upgradable`) so capsules `include` only what they implement. |

A capsule's world declares only the imports it uses plus the guest-export worlds it actually implements:

```wit
// Interceptor-only capsule:
world router {
    include astrid:guest/interceptor@1.0.0;
    import astrid:ipc/host@1.0.0;
    // intentionally not importing net, http, identity, …
}

// Run-loop capsule with an install hook:
world cli {
    include astrid:guest/interceptor@1.0.0;
    include astrid:guest/background@1.0.0;
    include astrid:guest/installable@1.0.0;
    import astrid:ipc/host@1.0.0;
    import astrid:uplink/host@1.0.0;
    import astrid:net/host@1.0.0;
}
```

Per-export worlds matter: the wasm32-wasip2 toolchain auto-stubs every export declared in a world the component targets. Bundling all four entry points into one mandatory world forced stubs for the unused ones, which then required kernel-side parsing to distinguish real implementations from toolchain stubs. With per-export worlds, an export only appears in the wasm binary when the capsule actually implements it.

### Evolution discipline

Once a `host/<name>@X.Y.Z.wit` file is shipped (i.e. on `main`), it is **immutable forever**. The wasmtime Component Model linker enforces structural typing on every `(package, version)` pair, so any record-field add or function add in a published WIT file causes every capsule built against the prior shape to fail to instantiate. The fix is to never edit a published file in place.

Shape changes ship as a new file at a new version:

```
host/
  ipc@1.0.0.wit           # frozen
  ipc@1.1.0.wit           # frozen (additive change from 1.0.0)
  ipc@2.0.0.wit           # current (breaking change from 1.x)
```

To evolve a package:

1. Copy the latest frozen file: `cp host/ipc@1.0.0.wit host/ipc@1.1.0.wit`.
2. Bump the package declaration inside the new file: `package astrid:ipc@1.1.0;`.
3. Make your shape changes in the new file.
4. Leave the existing frozen file untouched.
5. The kernel registers both versions in its linker (`bindings::ipc_v1_0::add_to_linker` and `bindings::ipc_v1_1::add_to_linker`) so old and new capsules both load.

CI enforces this via `scripts/lint-wit-immutability.sh` — any PR that modifies or deletes a published `*@X.Y.Z.wit` file fails the build.

See [RFC: Host ABI](https://github.com/unicity-astrid/rfcs/pull/22) for the full design (per-domain packages, multi-version kernel registration, frozen-file rule) and [issue #750](https://github.com/unicity-astrid/astrid/issues/750) for the motivating bug.

## Capsule interfaces (`interfaces/`) — the `astrid-bus:*` namespace

The capsule-to-capsule contracts. Distinct namespace (`astrid-bus:*`) from the host ABI (`astrid:*`) — the medium is different: host fns are direct wasmtime CM linker calls, bus interfaces are schemas for events that flow over the IPC bus between capsules. Capsules declare which they import/export in `Capsule.toml`; the kernel validates at boot that every required import has a matching export.

| File | Package | Description |
|------|---------|-------------|
| `interfaces/llm.wit` | `astrid-bus:llm@1.0.0` | LLM generation requests and streaming responses |
| `interfaces/session.wit` | `astrid-bus:session@1.0.0` | Conversation session storage and retrieval |
| `interfaces/spark.wit` | `astrid-bus:spark@1.0.0` | Agent identity and system prompt construction |
| `interfaces/context.wit` | `astrid-bus:context@1.0.0` | Context window compaction and management |
| `interfaces/prompt.wit` | `astrid-bus:prompt@1.0.0` | Prompt assembly from components |
| `interfaces/tool.wit` | `astrid-bus:tool@1.0.0` | Tool dispatch and execution results |
| `interfaces/hook.wit` | `astrid-bus:hook@1.0.0` | Lifecycle hook fan-out and response collection |
| `interfaces/registry.wit` | `astrid-bus:registry@1.0.0` | Model registry operations |
| `interfaces/types.wit` | `astrid-bus:types@1.0.0` | Shared types used across bus interfaces |
| `interfaces/users.wit` | `astrid-bus:users@1.0.0` | Within-principal user identity store — platform-to-AstridUserId mapping |

(Plus `agent`, `approval`, `client`, `elicit`, `onboarding`, `system`, `user` — see `interfaces/` for the full set.)

## How capsules use these

Capsules declare which host packages and bus interfaces they import/export in their `Capsule.toml`. The two namespaces stay distinct:

```toml
# Host ABI — kernel-mediated syscalls.
[imports.astrid]
fs = "1.0.0"
ipc = "1.0.0"

# Capsule-to-capsule event schemas, on the IPC bus.
[imports.astrid-bus]
llm = "^1.0"
session = { version = "^1.0", optional = true }

[exports.astrid-bus]
session = "1.0.0"
```

The kernel validates at boot that every required `astrid-bus` import has a matching `astrid-bus` export from another loaded capsule. The WIT files in `interfaces/` define the message schemas carried over the IPC bus.

## How SDKs use these

SDKs use `wit-bindgen` (Rust), `ComponentizeJS` (JS/TS), or equivalent toolchains to generate typed bindings from these definitions. The generated types match the IPC payload schemas so capsule authors get compile-time type safety.

The kernel uses `wasmtime::component::bindgen!` against each `host/<name>@<version>.wit` to generate one binding module per `(package, version)` pair. The kernel's linker setup registers every supported version explicitly — there is no implicit version negotiation in the Component Model.

## Cross-repo coordination

Both kinds of WIT files change rarely but breakingly. The repos that submodule from here are:

- [`unicity-astrid/astrid`](https://github.com/unicity-astrid/astrid) -- kernel (host implementations bound to each `host/<name>@<version>.wit`)
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
