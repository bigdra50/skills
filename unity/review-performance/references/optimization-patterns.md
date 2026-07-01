# C# Optimization Patterns Reference

12カテゴリの最適化パターンと、コードベースでの検出ルール。

## Table of Contents

1. [Zero Allocation](#1-zero-allocation)
2. [Span / Memory](#2-span--memory)
3. [Source Generator](#3-source-generator)
4. [Struct Design](#4-struct-design)
5. [SIMD](#5-simd)
6. [Native Memory](#6-native-memory)
7. [Async Optimization](#7-async-optimization)
8. [Buffer Management](#8-buffer-management)
9. [UTF-8 Native](#9-utf-8-native)
10. [Data Layout](#10-data-layout)
11. [Serialization](#11-serialization)
12. [Language Features](#12-language-features)

---

## 1. Zero Allocation

### Detect: grep patterns
```
string\.Format\(
\.ToString\(\)    # in hot paths
new MemoryStream
\.ToArray\(\)
\.ToList\(\)      # in hot paths
yield return      # LINQ chain
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| String formatting | `string.Format()`, `$"{x}"` | `ZString`, `Utf8StringInterpolation`, `string.Create()` |
| Intermediate collections | `.ToArray()`, `.ToList()` | `Span<T>`, `CollectionsMarshal.AsSpan()` |
| LINQ on hot path | `.Where().Select().Sum()` | struct enumerator (ZLinq pattern), manual loop |
| MemoryStream | `new MemoryStream()` | `IBufferWriter<byte>`, `ArrayBufferWriter<byte>` |
| Closure capture | `list.Where(x => x > threshold)` | static lambda, `TState` parameter pattern |

### Key technique: struct enumerator
Replace `IEnumerable<T>` with generic struct implementing enumerator interface. Each operator is a struct with type parameter for previous operator. JIT inlines the entire chain.

## 2. Span / Memory

### Detect: grep patterns
```
\.Substring\(
Encoding\.\w+\.GetBytes
Encoding\.\w+\.GetString
Array\.Copy
Buffer\.BlockCopy
new byte\[
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Substring | `str.Substring(i, len)` | `str.AsSpan(i, len)` (.NET 6+) |
| Encoding | `Encoding.UTF8.GetBytes(str)` | `Encoding.UTF8.GetBytes(str, span)` |
| Array copy | `Array.Copy(src, dst, len)` | `src.AsSpan().CopyTo(dst)` |
| List internals | `list[i]` in tight loop | `CollectionsMarshal.AsSpan(list)` |
| Small temp buffer | `new byte[N]` (N small) | `stackalloc byte[N]` + `Span<byte>` |
| Large temp buffer | `new byte[N]` (N large) | `ArrayPool<byte>.Shared.Rent(N)` |

### Key APIs
- `Span<T>` / `ReadOnlySpan<T>` — stack-only view, no copy
- `Memory<T>` / `ReadOnlyMemory<T>` — heap-safe, usable in async
- `CollectionsMarshal.AsSpan(List<T>)` — direct access to List backing array
- `MemoryMarshal.GetReference(span)` — bypass bounds check

## 3. Source Generator

### Detect: grep patterns
```
typeof\(         # reflection
\.GetType\(\)
GetMethod\(
GetProperties\(
Activator\.CreateInstance
Invoke\(
Expression\.
Emit\(           # IL.Emit
DynamicMethod
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Reflection serialization | `typeof(T).GetProperties()` | `[GenerateSerializer]` + Source Generator |
| Dynamic instantiation | `Activator.CreateInstance<T>()` | Source Generator factory |
| IL.Emit | `DynamicMethod` | Incremental Source Generator |
| Runtime code gen | `Expression.Lambda` | Source Generator |

### Benefits
- Zero runtime cost (all code generated at compile time)
- AOT/trimming safe
- Debuggable (generated source is visible)

## 4. Struct Design

### Detect: grep patterns
```
class\s+\w+\s*:.*IEnumerator  # class enumerator
class\s+\w+\s*{               # small data-only class
new\s+\w+\(                   # frequent instantiation in loops
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Small data class | `class Point { int X, Y; }` | `struct Point`, `readonly record struct` |
| Enumerator | `class Enumerator : IEnumerator<T>` | `struct Enumerator : IEnumerator<T>` |
| Builder/Writer | `class Writer { Span field; }` | `ref struct Writer { ref byte field; }` |
| Operator chain | class-based chain | struct with generic type param for source |

### Guidelines
- struct if: <16 bytes, short-lived, immutable, hot path
- class if: large, needs inheritance, nullable semantics
- ref struct if: holds Span/ref field, temporary scope only
- `[StructLayout(LayoutKind.Auto)]` for optimal field layout

## 5. SIMD

### Detect: grep patterns
```
for\s*\(.*\.Length     # numeric array loop
\.Sum\(\)
\.Min\(\)
\.Max\(\)
\.Average\(\)
\.Contains\(           # on large arrays
\.SequenceEqual\(
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Array sum | `for` loop / LINQ `.Sum()` | `Vector<T>` SIMD loop |
| Min/Max | LINQ `.Min()` / `.Max()` | `Vector.Min/Max` + horizontal reduce |
| Contains | `Array.Contains(x)` | `Vector.Equals` + `MoveMask` |
| Bulk operation | per-element loop | `Vector128/256.LoadUnsafe` + batch process |

### Prerequisites
- Data in contiguous memory (`Span<T>`, array)
- Numeric primitive types (byte, int, float, double)
- Same operation repeated across elements

## 6. Native Memory

### Detect: grep patterns
```
new\s+\w+\[.*\]       # very large arrays (>85KB = LOH)
GC\.Collect
GC\.GetTotalMemory
OutOfMemoryException
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Large array | `new byte[1_000_000]` | `NativeMemory.Alloc` / `NativeMemoryArray<T>` |
| >2GB data | multiple arrays | `NativeMemoryArray<T>` (long length) |
| GC pressure | frequent large alloc | `NativeMemory` + `IDisposable` |

### Key APIs
- `NativeMemory.Alloc(size)` / `NativeMemory.AllocZeroed(size)`
- `NativeMemory.Free(ptr)` — manual lifetime management
- `where T : unmanaged` constraint for safe native memory usage
- `GC.AddMemoryPressure` to inform GC of native allocations

## 7. Async Optimization

### Detect: grep patterns
```
async\s+Task<        # on hot paths
async\s+Task\s        # void-returning async
\.Result\b            # sync-over-async
\.Wait\(\)            # sync-over-async
await\s+Task\.Run     # unnecessary offload
new\s+Task            # manual task creation
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Sync-complete async | `async Task<T>` | `ValueTask<T>` |
| Hot path async | `async Task<T>` | `[AsyncMethodBuilder(typeof(PoolingAsyncValueTaskMethodBuilder<>))]` |
| Unity async | `StartCoroutine` | `UniTask` |
| Task.Run abuse | `await Task.Run(() => cpuWork)` | direct call if already on thread pool |

### Key technique: ValueTask
Use `ValueTask<T>` when synchronous completion is common. Zero heap allocation on sync path.

## 8. Buffer Management

### Detect: grep patterns
```
new\s+MemoryStream
\.Write\(.*byte\[\]
\.Read\(.*byte\[\]
new\s+byte\[
\.GetBytes\(
\.Flush\(\)
BinaryWriter
BinaryReader
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Serialization target | `MemoryStream` | `IBufferWriter<byte>` |
| Temp buffer | `new byte[N]` | `ArrayPool<byte>.Shared.Rent(N)` |
| Growing buffer | `List<byte>` / `MemoryStream` | Linked chunk buffer (no resize copy) |
| Non-contiguous read | merge + copy | `ReadOnlySequence<byte>` |

### Key APIs
- `IBufferWriter<byte>`: GetSpan/Advance pattern
- `ArrayPool<T>.Shared`: Rent/Return
- `ReadOnlySequence<T>`: non-contiguous buffer reading
- `System.IO.Pipelines`: async read/write pipeline

## 9. UTF-8 Native

### Detect: grep patterns
```
Encoding\.UTF8\.GetString
Encoding\.UTF8\.GetBytes
StreamReader
StreamWriter
string\.Format.*log     # logging with string format
JsonSerializer\.Serialize.*string
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| String to bytes | `Encoding.UTF8.GetBytes(str)` | UTF-8 literals `"..."u8` (C# 11) |
| Stream reading | `StreamReader.ReadLine()` → string | `Utf8StreamReader` → `ReadOnlyMemory<byte>` |
| String building for I/O | `StringBuilder` → `ToString()` → encode | `Utf8StringInterpolation` → `IBufferWriter<byte>` |
| Logging | `$"User {id} logged in"` → string | `ZLogger` `InterpolatedStringHandler` → UTF-8 direct |

### Key principle
If the final output is bytes (network, file, log), avoid UTF-16 `string` entirely. Process as UTF-8 bytes throughout.

## 10. Data Layout

### Detect: grep patterns
```
struct\s+\w+\s*\{.*\}.*\[\]   # struct array (AoS)
for.*\.\w+\s*[+\-*/]          # field-only loop on struct array
```

### Optimize
| Pattern | Before | After |
|---|---|---|
| Field-only bulk ops | `foreach (var p in particles) sum += p.X;` | SoA: `particles.X.Sum()` |
| SIMD on struct array | iterate + extract field | SoA: `Span<float>` per field → SIMD direct |

### When to use SoA
- Processing single fields across many elements
- SIMD aggregation (Sum, Min, Max)
- Cache efficiency matters (tight inner loops)

### When to keep AoS
- Random access with all fields
- Small arrays
- Readability priority

## 11. Serialization

### Detect: grep patterns
```
JsonSerializer       # System.Text.Json
Newtonsoft
BinaryFormatter      # deprecated, security risk
XmlSerializer
\[Serializable\]
```

### Optimize (by priority)
1. `MemoryPack` — zero-encoding for unmanaged types, Source Generator
2. `MessagePack` — compact binary, Source Generator (v3)
3. `System.Text.Json` — with Source Generator (`JsonSerializerContext`)
4. Avoid: `BinaryFormatter`, `Newtonsoft.Json` on hot paths

## 12. Language Features

### Modern C# features to adopt

| Feature | Min Version | Optimization |
|---|---|---|
| `Span<T>` | C# 7.2 | Zero-copy memory access |
| `static local function` | C# 8 | Avoid closure allocation |
| Source Generator | C# 9 | Compile-time code gen |
| `InterpolatedStringHandler` | C# 10 | Custom string interpolation |
| `ref field` | C# 11 | ref struct holding references |
| `static abstract members` | C# 11 | Zero-overhead dispatch |
| `"..."u8` | C# 11 | UTF-8 constant spans |
| `InlineArray` | C# 12 | Stack-allocated fixed buffer |
| `allows ref struct` | C# 13 | ref struct in generics |
