---
name: unity-csharp-guide
description: Unity C# code generation best practices. Use when writing C# for Unity (MonoBehaviour, ScriptableObject, serialization, async/await, IL2CPP, hot-path allocation) to avoid common AI mistakes and version-gated API misuse.
---

# Unity C# Practice Guide

Best practices for AI when generating C# for Unity.
Unity is not plain .NET: the engine owns object lifetime, the main thread, serialization, and the AOT compiler. Most AI mistakes come from applying standard .NET patterns that the engine silently breaks.

Each `#if UNITY_..._OR_NEWER` guard marks an API that only exists from that version. When the target version is unknown, prefer the guarded (newer) API and keep the guard.

## MonoBehaviour lifetime

Unity constructs, serializes, and destroys `MonoBehaviour`/`ScriptableObject` for you. Never use `new`, and never rely on constructors.

```csharp
// NG: engine cannot attach this to a GameObject; fields stay null, Awake never runs
var enemy = new EnemyController();
// Warning: "You are trying to create a MonoBehaviour using the 'new' keyword.
//          This is not allowed. MonoBehaviours can only be added using AddComponent()."

// OK: MonoBehaviour is added to a GameObject
var enemy = gameObject.AddComponent<EnemyController>();

// OK: ScriptableObject is created via the factory
var config = ScriptableObject.CreateInstance<EnemyConfig>();
```

Constructors run on Unity's loading thread before serialization, so parameters and field access there are meaningless.

```csharp
// NG: constructor on a MonoBehaviour — never called by the engine with your args
public sealed class Turret : MonoBehaviour
{
    public Turret(int damage) { _damage = damage; } // dead code
    int _damage;
}

// OK: dependencies come from serialized fields or an explicit Init after AddComponent
public sealed class Turret : MonoBehaviour
{
    [SerializeField] int _damage;

    public void Init(int damage) => _damage = damage;
}
```

```csharp
// NG: async void Start — exceptions are unobservable and lost to the caller
async void Start() { await LoadAsync(); }

// OK (2023.1+): async Awaitable is awaited by the engine and observes exceptions
#if UNITY_2023_1_OR_NEWER
async Awaitable Start() { await LoadAsync(); }
#else
// OK (older): fire-and-forget but wrap so exceptions surface in the console
async void Start()
{
    try { await LoadAsync(); }
    catch (Exception e) { Debug.LogException(e); }
}
#endif
```

`async void` swallows exceptions: they escape to the `SynchronizationContext` instead of the caller, so a failed `Start`/`OnEnable` fails silently. Only use `async void` for genuine event handlers that must return `void`, and even then wrap the body in try/catch.

## Serialization

The Inspector serializes fields, not properties. Expose state as `[SerializeField]` private fields, not public fields, so other code cannot mutate them freely.

```csharp
// NG: public field — no encapsulation, and public is not required for the Inspector
public float speed = 5f;

// OK: private field, editable in Inspector, read-only to other code
[SerializeField, Tooltip("Units per second")] float _speed = 5f;
public float Speed => _speed;

// OK: auto-property backing field serialized via [field: SerializeField] (2020.1+)
[field: SerializeField] public float Health { get; private set; }
```

Use `const` for values that never change and `[SerializeField]` for values a designer tunes. Document non-obvious ranges with `[Tooltip]` / `[Range]` rather than a comment.

```csharp
const float GravityScale = 9.81f;          // fixed constant, no Inspector entry
[SerializeField, Range(0f, 1f)] float _drag; // tunable, clamped in Inspector
```

## async/await on the Unity main thread

Unity's API is single-threaded. Blocking the main thread on a `Task` deadlocks the editor and player.

```csharp
// NG: blocks the main thread waiting for a Task that resumes on the main thread -> deadlock
var data = LoadAsync().Result;
LoadAsync().Wait();

// OK: await it
var data = await LoadAsync();
```

Pick the return type by where the continuation must run:

```csharp
// Pure computation / IO with no Unity API after the await -> Task
async Task<byte[]> ReadFileAsync(string path) =>
    await File.ReadAllBytesAsync(path);

#if UNITY_2023_1_OR_NEWER
// Touches transforms, components, etc. after awaiting -> Awaitable (resumes on main thread)
async Awaitable SpawnAsync()
{
    await Awaitable.WaitForSecondsAsync(1f);
    transform.position = Vector3.zero; // safe: back on the main thread
}
#endif
```

Cancellation: catch `OperationCanceledException` **before** the general `catch`, otherwise a normal cancel is logged as an error.

```csharp
async Awaitable RunAsync(CancellationToken token)
{
    try
    {
        await StepAsync(token);
    }
    catch (OperationCanceledException) { /* expected on cancel, swallow */ }
    catch (Exception e) { Debug.LogException(e); } // real failures only
}
```

```csharp
#if UNITY_2022_2_OR_NEWER
// OK: token that fires when the object is destroyed — stops orphaned async work
await StepAsync(destroyCancellationToken);
#endif
```

## IL2CPP (AOT) constraints

IL2CPP compiles ahead-of-time and strips unused code. Runtime code generation and reflection-only members break.

```csharp
// NG: Reflection.Emit / DynamicMethod — no JIT under IL2CPP, throws at runtime
var dm = new DynamicMethod(...); // ExecutionEngineException / not supported

// OK: source generators or hand-written code instead of runtime emit
```

Anything reached only via reflection (JSON binding, DI, `SendMessage`) can be stripped. Mark it to survive:

```csharp
using UnityEngine.Scripting;

// OK: [Preserve] keeps this type/member through code stripping
[Preserve]
public sealed class SaveData { public int Score; }
```

For third-party assemblies you cannot annotate, add a `link.xml` at an `Assets` root:

```xml
<linker>
  <assembly fullname="Newtonsoft.Json" preserve="all"/>
</linker>
```

## Version-gated API migration

Prefer the newer API and keep the `#if` guard so the code still compiles on older editors.

```csharp
#if UNITY_2022_2_OR_NEWER
// OK: FindObjectsByType — explicit sort mode, far faster when order is irrelevant
var all = Object.FindObjectsByType<Enemy>(FindObjectsSortMode.None);
var one = Object.FindFirstObjectByType<Enemy>();
#else
// Deprecated: FindObjectOfType / FindObjectsOfType (always sorts, slow)
var all = Object.FindObjectsOfType<Enemy>();
var one = Object.FindObjectOfType<Enemy>();
#endif
```

```csharp
#if UNITY_2021_1_OR_NEWER
using UnityEngine.Pool;
// OK: built-in ObjectPool<T> instead of a hand-rolled Stack pool
readonly ObjectPool<Bullet> _pool = new(() => Instantiate(prefab));
#endif
```

```csharp
#if UNITY_2021_2_OR_NEWER
// OK: Span<T> / Index / Range (.NET Standard 2.1) — slice without allocating
Span<int> tail = buffer[^4..];
#endif
```

```csharp
#if UNITY_6000_4_OR_NEWER
// OK: EntityId replaces InstanceID (int) as the stable object identity
EntityId id = gameObject.GetEntityId();
#else
int id = gameObject.GetInstanceID();
#endif
```

```csharp
#if UNITY_2023_1_OR_NEWER
// OK: Awaitable replaces coroutines for new async code (no IEnumerator/yield)
async Awaitable BlinkAsync()
{
    await Awaitable.NextFrameAsync();
}
#else
IEnumerator Blink() { yield return null; } // legacy coroutine
#endif
```

## Hot-path allocation traps

`Update`, `FixedUpdate`, and `LateUpdate` run every frame. Allocations there cause GC spikes.

```csharp
// NG: GetComponent every frame — lookup cost + no cache
void Update() { GetComponent<Rigidbody>().AddForce(_force); }

// OK: cache in Awake
Rigidbody _rb;
void Awake() => _rb = GetComponent<Rigidbody>();
void Update() => _rb.AddForce(_force);
```

```csharp
// NG: LINQ allocates iterators/closures every frame
void Update() { var near = enemies.Where(e => e.Alive).ToList(); }

// OK: manual loop, no allocation
void Update()
{
    for (int i = 0; i < enemies.Count; i++)
        if (enemies[i].Alive) { /* ... */ }
}
```

```csharp
// NG: string concatenation in a loop allocates a new string each iteration
void Update() { _label.text = "Score: " + score + " / " + max; }

// OK: build once, reuse a StringBuilder, or update only when the value changes
readonly StringBuilder _sb = new(32);
void SetLabel()
{
    _sb.Clear();
    _sb.Append("Score: ").Append(score).Append(" / ").Append(max);
    _label.SetText(_sb);
}
```

```csharp
// NG: lambda capturing a local allocates a closure every call
void Update() { Schedule(() => Handle(currentTarget)); }

// OK: pass state explicitly / use a cached static delegate so nothing is captured
```

Iterating a plain `List<T>` with `foreach` is fine (its enumerator is a struct). On older Unity (pre-2020) `foreach` over interface-typed or non-`List` collections boxed the enumerator — prefer a `for` loop there.

## Event function rules

Execution order within one object is guaranteed; order across objects is not.

- All `Awake()` run before any `Start()`. Do cross-component wiring in `Start`, not `Awake`, if it depends on another object's `Awake` having finished.
- Physics goes in `FixedUpdate` (fixed timestep); input and per-frame logic go in `Update`.
- Camera-follow and anything reading a transform moved this frame goes in `LateUpdate`.
- Never assume `Enemy.Awake` runs before `Spawner.Awake` — set explicit references or use Script Execution Order.

```csharp
// NG: an empty OnGUI still costs per frame (forces the legacy IMGUI pass)
void OnGUI() { }

// OK: delete it, or guard editor-only debug UI so it never ships
#if UNITY_EDITOR
void OnGUI() { GUILayout.Label(_debugInfo); }
#endif
```

## Naming and file structure

- One public class per file; the file name must match the class name exactly (`Turret.cs` → `class Turret`). MonoBehaviours require this or the component won't bind.
- Namespace mirrors the directory path under `Assets` / the assembly root.
- Abstract base: no prefix/suffix (`Weapon`); concrete types are suffixed with the base name (`MeleeWeapon`, `RangedWeapon`).
- Enum: singular PascalCase (`enum WeaponKind`). `[Flags]` enum: plural (`enum DamageTypes`), values as powers of two.

## "Why not" comment pattern

When you tried a standard approach and rejected it for a Unity-specific reason, record *why not* so the next agent doesn't rediscover the dead end. Keep it to the mechanical reason.

```csharp
// Why not GetComponent in Update: profiled 0.3ms/frame at 200 enemies; cached in Awake instead.
Rigidbody _rb;

// Why not async void here: exceptions from Start were being swallowed; switched to async Awaitable.
async Awaitable Start() { ... }
```

Only add these where the standard choice looks correct but fails — not on ordinary code.
