# Build Standards

Helper for the `code-style` skill. Covers architecture boundaries, package handling,
and the build pipeline. For where a *new* feature belongs, see the
`backend-architecture` skill; for creating a package, see `package-scaffold`.

## Architecture

### Hexagonal (ports and adapters)

- **Domain** — entities and ports (interfaces). No external dependencies.
- **Service** — business logic. Depends only on ports.
- **Adapters (driven)** — implement ports against real infrastructure.
- **Channels (driving)** — entry points. HTTP lives in `channels/http/` and is the
  only layer that imports the web framework.
- **Framework-agnostic core** — services, adapters, entities, and ports are plain
  TypeScript.

```
Request → channels/http → service → ports ← adapters
```

### Module layout

```
<module>/
├── entities/
├── ports/
├── adapters/
├── service/
├── schemas/
└── index.ts
```

`channels/http/` sits at the application level, not inside the module.

## Main logic is a class, helpers are functional

- **Main logic** — classes. Singleton or multi-instance as the requirement dictates.
- **Helpers** — pure arrow functions in `helpers/*.util.ts`. No static utility
  classes.

| Layer | Class | Example |
| ----- | ----- | ------- |
| Service | `ThingService` | `UserService` |
| Routes | `ThingRoutes` | `UserRoutes` with `register(router)` |
| Adapter | `<Backing>ThingRepository` | `PostgresUserRepository` |
| Factory | `ThingFactory` | `LoggerFactory` |
| Helpers | pure arrow functions | `build-target.util.ts` |

## SOLID

- **S** — one class, one concern.
- **O** — extend through new adapters, not by editing the core.
- **L** — adapters implement their port faithfully; subtypes stay substitutable.
- **I** — small, focused ports.
- **D** — services depend on the port, never the concrete adapter. Inject through the
  constructor or a factory.

## Design patterns in practice

| Pattern | Use | Example |
| ------- | --- | ------- |
| Repository | Abstract persistence | `UserRepository` port with a driver-specific adapter |
| Factory | Create configured instances | `LoggerFactory.getLogger()` at application level |
| Lazy loading | Defer heavy imports | dynamic `import()` in `bootstrap()`, secrets fetched on first access |
| Adapter | Bridge external systems | `channels/http` adapting the web framework to service calls |

**Pluggable provider packages** (logging, secrets, storage):

- Provider config types live beside the provider, not in a central types module.
- Shared logic goes in a common helper rather than being copy-pasted per provider.
- No package-level singleton — the application creates the instance; a manager class
  wraps the chosen provider.
- Optional peer dependencies define their types in the provider file, so consumers
  who skip the peer never see a broken type reference.
- When a file principally defines the core contract, name it `interfaces.ts`, not
  `types.ts`.

## Package handling

### Dependency direction

- Packages may depend on other packages.
- Applications depend on packages through the workspace protocol.
- Packages must never depend on applications, and applications must never depend on
  other applications.

### Package or application code?

| Create a package | Keep it in the application |
| ---------------- | -------------------------- |
| Reusable across applications | Single-application feature logic |
| Shared infrastructure (logging, secrets, HTTP server bootstrap) | Domain entities specific to one API |
| Framework utilities | Route wiring |
| Pure utilities with no application coupling | Module-specific adapters |

### Adding a package

1. Create `<packages-dir>/<pkg-prefix><name>/`.
2. Set `"name": "<pkg-scope>/<name>"` in `package.json`, with `main`, `types`, and
   `exports`.
3. Add a project reference in the root `tsconfig.json`.
4. Confirm the workspace glob already covers the directory.
5. Install, implement with tests and a README, then build and test.

### `package.json` conventions

- Internal dependencies use the workspace protocol (`workspace:*` for pnpm and yarn,
  `*` with npm workspaces).
- `exports` subpaths when consumers need fine-grained imports.
- `peerDependencies` for optional integrations.
- `files: ["dist"]` so only built output ships.
- `private: true` for application packages; omit for publishable ones.

### Adding dependencies

Use `<pkg-manager>`'s filter or workspace flag to target one package rather than the
root. Add at the latest version unless compatibility forces a pin. If A depends on B
and B needs A, extract the shared types into a third package rather than accepting a
cycle.

### Barrel exports

Re-export the public API from `src/index.ts`. Do not export internals. Use subpath
exports for heavy or optional modules. Prefer named exports over a default.

## Build pipeline

When `build-orchestrator` is `turbo` or `nx`:

- `build` depends on upstream `build`.
- `test` depends on upstream `build`.
- Cache `dist/**` as the build output.
- Run from the root so the graph resolves.

When it is `none`, the root `package.json` scripts fan out to workspaces directly and
build order is the developer's responsibility — document it in the root README.

## Error handling and resilience

- **Domain errors** — throw typed errors; map them to status codes in channels.
- **Port failures** — adapters catch external errors and wrap them, so the service
  stays agnostic of the backing technology.
- **Secrets** — never committed; read through the configured secrets mechanism; fail
  fast when a required value is missing.
- **Logging** — inject the logger into services; log at boundaries (request start and
  end, errors), not on every internal call.

## Checklist before a pull request

- [ ] Main logic class-based, helpers functional
- [ ] SOLID boundaries respected
- [ ] Hexagonal boundaries intact — only channels import the framework
- [ ] Tests present and passing
- [ ] README updated for any touched package
- [ ] Naming follows `naming-conventions.md`
- [ ] Lazy loading applied to heavy or optional dependencies
- [ ] No circular dependencies between packages
- [ ] Dependencies added to the specific package, not the root
