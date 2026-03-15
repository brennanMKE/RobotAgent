# Coding Standards & Guidelines

This document provides an overview of coding standards for the RobotAgent project. For detailed guidance, refer to the linked documentation.

---

## Quick Reference

### 1. **Actor Isolation & Concurrency**
**File**: [`ActorIsolation.md`](./ActorIsolation.md)

The project uses **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** mode. All unannotated declarations default to `@MainActor` isolation.

**Key Rules**:
- ✅ Mark immutable value types (structs) with `nonisolated` to opt out
- ✅ Mark protocol requirements with `nonisolated` when appropriate
- ✅ Use `actor` for reference types that manage shared mutable state
- ⚠️ Use `@unchecked Sendable` sparingly, only for mock/test objects
- ✅ Mark file-scoped loggers as `nonisolated private let`

**Quick Decision Tree**:
```
Is it a value type (struct)?
  → YES: Add nonisolated (copy semantics = no isolation needed)
  → NO: Is it an actor?
    → YES: No annotation needed (actor isolation is explicit)
    → NO: Is it a UI class (@Observable)?
      → YES: @MainActor (or default)
      → NO: Make it an actor or @unchecked Sendable
```

---

### 2. **Concurrency**
**File**: [`Concurrency.md`](./Concurrency.md)

**Rule**: Use **modern Swift Concurrency** exclusively. Never use Combine or Dispatch for concurrency.

**What this means**:
- ✅ Use `async/await` for asynchronous operations
- ✅ Use `Task` for background work
- ✅ Use `actor` for exclusive access to mutable state
- ❌ Don't use `DispatchQueue`, `DispatchGroup`, or GCD
- ❌ Don't use Combine's Scheduler or threading operators
- ❌ Don't use `@escaping` closures (prefer `async` functions)

---

### 3. **Logging**
**File**: [`Logging.md`](./Logging.md)

Use **Apple's unified logging system** (`os.log`) for all debugging and diagnostics.

**Setup**:
```swift
import os.log

nonisolated private let logger = Logger(
  subsystem: Logging.subsystem,
  category: "CategoryName"
)
```

**Log Levels** (use the appropriate level):
- `debug(...)` — Verbose tracing: method calls, state transitions, values
- `info(...)` — Informational: significant but expected events
- `notice(...)` — Default level: important runtime events
- `warning(...)` — Unexpected but recoverable situations
- `error(...)` — Errors that affect functionality
- `fault(...)` — Programming errors / assertions

**Privacy**:
- Dynamic strings are redacted in release builds by default
- Use `privacy: .public` to make values visible in production logs
- Keep sensitive data redacted (user input, tokens, etc.)

**Viewing Logs**:
```bash
# Real-time streaming
log stream --predicate 'subsystem == "com.brennanmke.robotagent"' --level debug

# File export
log show --info --last 2m > logs.txt
```

---

### 4. **Performance**
**File**: [`Performance.md`](./Performance.md)

Performance optimization recommendations prioritized by impact. Key areas:

**Critical Issues**:
1. **View Identity** — Use stable, immutable IDs in `ForEach` loops
2. **Caching** — Cache expensive computations (filtering, sorting) that repeat frequently
3. **Layer Composition** — Cache sorted keys to avoid repeated sorting

**High-Priority Issues**:
4. **Allocations** — Extract repeated array/object creation into properties
5. **Code Duplication** — Remove duplicate view definitions and state updates

**Low-Priority Issues**:
6. **Code Clarity** — Extract complex expressions into named properties

**Measurement Tools**:
- Xcode Instruments (System Trace)
- `os.signpost` for operation timing
- `os.log` for event logging

---

## File Organization

- **`ActorIsolation.md`** — Detailed rules for `@MainActor`, `nonisolated`, `actor`, and `@unchecked Sendable`
- **`Concurrency.md`** — Why and how to use Swift Concurrency exclusively
- **`Logging.md`** — Structured logging with `os.log`, log levels, privacy, and viewing tools
- **`Performance.md`** — Optimization strategies, measurement techniques, and baseline metrics

---

## Most Important Rules

1. **Actor Isolation**: Mark value types and protocols as `nonisolated`; use `actor` for reference types with state
2. **Concurrency**: Always use `async/await` and `Task`, never Combine or Dispatch
3. **Logging**: Use `os.log` with the Logging subsystem; mark loggers as `nonisolated private let`
4. **Performance**: Cache expensive computations; use stable IDs in view loops; measure with instruments

---

## When in Doubt

- Check [`ActorIsolation.md`](./ActorIsolation.md) for isolation questions
- Check [`Concurrency.md`](./Concurrency.md) for async patterns
- Check [`Logging.md`](./Logging.md) for instrumentation
- Check [`Performance.md`](./Performance.md) for optimization strategies
