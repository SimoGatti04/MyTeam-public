# Historical decision: autonomous updater architecture

> **Current baseline:** implementation details and release gates are governed by [RELEASE-BASELINE.md](../RELEASE-BASELINE.md) and [PRODUCTION-RELEASE.md](../PRODUCTION-RELEASE.md). This concise historical record supersedes older local/private operational notes; it contains no private endpoints, key-provider references, or credential instructions.

## Stable technical decisions

- Updates are platform-specific and use versioned HTTPS artifacts plus a detached Ed25519 signature over the exact manifest bytes. The production public trust key is pinned in the client; QA uses a distinct trust key and channel. Invalid signatures, channel mismatches, version rollback, and hash/size mismatches fail closed.
- Android production and QA use separate application identities and signing certificates. Production update identity must remain stable across releases.
- Windows uses the stable Inno Setup AppId declared in the installer source and installs per-user. User preferences and data remain outside replaceable program files. During update, the installer requests graceful application closure and does not force-kill the process.
- A/B testing must verify monotonic version progression, same-certificate upgrades, graceful shutdown, and data retention on supported target environments.

Historical implementation notes that conflict with these decisions or the current source are superseded and must not be used as operational guidance.
