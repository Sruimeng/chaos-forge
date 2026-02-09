---
id: tech-stack
type: reference
related_ids: [build-system, platform-config]
---

# Tech Stack

> **Summary:** Godot 4.6 Mobile game engine with Jolt Physics, targeting Android/Mobile platforms.

## Engine

| Component | Version | Config |
|-----------|---------|--------|
| Godot | 4.6.stable | Mobile Feature Profile |
| Physics Engine | Jolt Physics 3D | Default Config |
| Rendering Driver | D3D12 | Windows Only |

## Target Platforms

| Platform | Status | Build Version |
|----------|--------|---------------|
| Android | Active | 4.6.stable |
| Mobile (Generic) | Enabled | - |

## Project Configuration

```ini
[application]
config/name="锻刀大赛"
config/features=PackedStringArray("4.6", "Mobile")

[physics]
3d/physics_engine="Jolt Physics"

[rendering]
rendering_device/driver.windows="d3d12"
```

## Build System

| Tool | Path | Purpose |
|------|------|---------|
| Android Build | `android/build/` | Native Android Packaging |
| Godot Cache | `.godot/` | Editor & Import Cache |

## Critical Constraints

* **Mobile-First:** All features must target mobile performance profiles.
* **Physics:** Jolt Physics is non-negotiable (replaces Godot Physics).
* **Windows Dev:** D3D12 required for Windows development environment.
* **Android:** Build system pre-configured, version locked to 4.6.stable.

## Dependencies

```
godot: 4.6.stable
jolt-physics: (bundled with Godot 4.6)
android-sdk: (via android/build/)
```
