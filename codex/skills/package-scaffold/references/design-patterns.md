# Design Patterns Reference

Helper for the `package-scaffold` skill. Optional — reach for a pattern when it
solves a real problem in front of you, not to demonstrate that you know it.

## Creational

| Pattern | When it earns its place in a package |
| ------- | ------------------------------------ |
| **Abstract Factory** | Families of related objects — several providers behind one interface |
| **Builder** | Step-by-step construction of a config object with many optional fields |
| **Factory Method** | Deferred creation — a factory that picks the provider from config |
| **Prototype** | Cloning rather than rebuilding — duplicating config templates |
| **Singleton** | A genuinely shared stateful resource. Use sparingly; prefer injection |

## Structural

| Pattern | When it earns its place in a package |
| ------- | ------------------------------------ |
| **Adapter** | Bridging incompatible interfaces — a framework adapter over a portable core |
| **Bridge** | Separating an abstraction from its implementations — one interface, many providers |
| **Composite** | Tree structures treated uniformly — nested config, route trees |
| **Decorator** | Adding behavior without subclassing — a caching or logging wrapper |
| **Facade** | One simple entry point over a complex subsystem |
| **Flyweight** | Sharing state across many instances — shared compiled schemas |
| **Proxy** | Lazy loading, access control, instrumentation — deferred heavy imports |

## Behavioral

| Pattern | When it earns its place in a package |
| ------- | ------------------------------------ |
| **Chain of Responsibility** | A handler pipeline — middleware, validation chains |
| **Command** | Requests as objects — queued operations, undo |
| **Interpreter** | Evaluating a grammar — query parsers, rule engines |
| **Iterator** | Traversal without exposing internals — paginated results, streams |
| **Mediator** | Reducing coupling between components — an event bus |
| **Memento** | Capture and restore state — snapshots, audit trails |
| **Observer** | Notifying dependents of change — event emitters |
| **State** | Behavior varying with internal state — connection lifecycle |
| **Strategy** | Interchangeable algorithms — validation strategies, storage backends |
| **Template Method** | An algorithm skeleton with overridable steps |
| **Visitor** | New operations over a fixed structure — serializers, transformers |

## In short

- **Creational** — how objects come into being
- **Structural** — how objects compose
- **Behavioral** — how objects collaborate

Most packages need Adapter, Factory, and Strategy, and nothing else. If a pattern
name appears in a class name but the pattern is not actually being used, remove the
name.
