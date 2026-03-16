# Observable and Geometry in Modern SwiftUI

SwiftUI has moved in two important directions:

1. **Observation** replaces the older `ObservableObject` + `@Published` style with the `@Observable` macro.
2. **Geometry change observation** often replaces using `GeometryReader` as a measurement tool, via `onGeometryChange`.

These changes make SwiftUI code simpler, more precise, and usually more efficient.

---

## 1. Why `@Observable` replaces `ObservableObject`

Apple’s Observation system is the modern SwiftUI model-observation system. Starting with **iOS 17, iPadOS 17, macOS 14, tvOS 17, and watchOS 10**, SwiftUI supports Observation and recommends migrating from `ObservableObject` to `@Observable` for supported deployments.

With the old approach, you typically wrote:

```swift
import SwiftUI

final class CounterModel: ObservableObject {
    @Published var count = 0
}
```

Then views used wrappers like `@StateObject`, `@ObservedObject`, and `@EnvironmentObject`.

With the modern approach, you usually write:

```swift
import Observation
import SwiftUI

@Observable
final class CounterModel {
    var count = 0
}
```

That removes both:

- the `ObservableObject` protocol
- the `@Published` wrapper on tracked properties

### What improves

Observation is better than `ObservableObject` in several ways:

- **Less boilerplate**: no `@Published` on each property
- **More precise tracking**: SwiftUI updates a view when a property the view actually reads changes
- **Better support for optionals and collections**
- **Cleaner SwiftUI data flow** using `@State` and `@Environment` instead of object-specific wrappers in many cases

That precision is a major change. With `ObservableObject`, a view could refresh when *any* published property changed, even one the view didn’t read. With Observation, SwiftUI tracks what the view body reads and invalidates more narrowly.

---

## 2. Old pattern vs modern pattern

### Old `ObservableObject` pattern

```swift
import SwiftUI

final class Library: ObservableObject {
    @Published var books: [Book] = []
}

struct LibraryView: View {
    @StateObject private var library = Library()

    var body: some View {
        List(library.books, id: \.self) { book in
            Text(book)
        }
    }
}
```

### Modern `@Observable` pattern

```swift
import Observation
import SwiftUI

@Observable
final class Library {
    var books: [String] = []
}

struct LibraryView: View {
    @State private var library = Library()

    var body: some View {
        List(library.books, id: \.self) { book in
            Text(book)
        }
    }
}
```

The important change is that the model is still a reference type here, but SwiftUI no longer needs `@StateObject` just to observe it. For an `@Observable` model that a view owns, `@State` is often the right wrapper.

---

## 3. Mapping the old wrappers to the new ones

A useful migration guide looks like this.

### `@StateObject` → usually `@State`

Old:

```swift
@StateObject private var store = Store()
```

New:

```swift
@State private var store = Store()
```

Use this when the view owns the lifetime of the observable reference.

### `@ObservedObject` → plain stored property, or `@Bindable` when bindings are needed

Old:

```swift
struct DetailView: View {
    @ObservedObject var book: Book

    var body: some View {
        Text(book.title)
    }
}
```

New:

```swift
struct DetailView: View {
    var book: Book

    var body: some View {
        Text(book.title)
    }
}
```

If the child view needs bindings into the observable model, use `@Bindable`:

```swift
struct EditBookView: View {
    @Bindable var book: Book

    var body: some View {
        TextField("Title", text: $book.title)
    }
}
```

### `@EnvironmentObject` → `@Environment(Type.self)`

Old:

```swift
@EnvironmentObject private var library: Library
```

New:

```swift
@Environment(Library.self) private var library
```

And injection changes from:

```swift
.environmentObject(library)
```

to:

```swift
.environment(library)
```

---

## 4. Complete migration example

### Before

```swift
import SwiftUI

final class SettingsStore: ObservableObject {
    @Published var username = "Taylor"
    @Published var prefersReducedMotion = false
}

@main
struct DemoApp: App {
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack {
            Text(settings.username)
            Toggle("Reduced Motion", isOn: $settings.prefersReducedMotion)
        }
        .padding()
    }
}
```

### After

```swift
import Observation
import SwiftUI

@Observable
final class SettingsStore {
    var username = "Taylor"
    var prefersReducedMotion = false
}

@main
struct DemoApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}

struct ContentView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack {
            Text(settings.username)
            Toggle("Reduced Motion", isOn: $settings.prefersReducedMotion)
        }
        .padding()
    }
}
```

This is the style Apple’s migration guidance points toward.

---

## 5. What to do with properties you do **not** want observed

If a property should not participate in observation, mark it ignored.

```swift
import Observation

@Observable
final class SearchModel {
    var query = ""

    @ObservationIgnored
    let cache = NSCache<NSString, NSString>()
}
```

Use this for derived helpers, caches, or implementation details that should not trigger view invalidation.

---

## 6. When `ObservableObject` still appears in real projects

`ObservableObject` is not “wrong”; it is just the older observation system.

You may still keep it when:

- you support OS versions earlier than iOS 17 / macOS 14
- an API or existing architecture still depends on it
- you are migrating incrementally

Apple explicitly supports **incremental migration**, so a project can temporarily mix `ObservableObject` and `@Observable` types.

---

## 7. Why `onGeometryChange` often replaces `GeometryReader`

A lot of older SwiftUI code used `GeometryReader` for jobs that were really about **measuring** a view, not **laying out** a view.

That often led to code like this:

```swift
struct WidthProbe: View {
    @State private var width: CGFloat = 0

    var body: some View {
        Text("Hello")
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            width = proxy.size.width
                        }
                }
            }
    }
}
```

This works, but it is awkward:

- `GeometryReader` is a layout container, not just a measurement callback
- it can affect layout behavior in surprising ways
- it often encourages hacks with preferences, overlays, or background readers

Modern SwiftUI gives you `onGeometryChange`, which is usually a better fit when your real goal is **observe geometry changes**.

---

## 8. `onGeometryChange` example

```swift
import SwiftUI

struct WidthProbe: View {
    @State private var width: CGFloat = 0

    var body: some View {
        Text("Hello")
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
    }
}
```

This reads much more clearly:

- transform the `GeometryProxy` into the value you care about
- react when that value changes

It is usually the right choice when you want things like:

- a child view’s size
- a view’s frame in a coordinate space
- position changes while scrolling
- layout-driven state updates

---

## 9. The key difference: observation vs layout

This is the most important GeometryReader rule now:

### Use `onGeometryChange` when you want to **observe geometry**

Examples:

- track width or height
- track whether a view is on screen
- track a frame in `.global`, `.local`, or a named coordinate space
- update some state when the geometry value changes

### Use `GeometryReader` when you want to **build layout from container geometry**

Examples:

- place or size child content based on the available container size
- draw custom paths based on the parent container’s dimensions
- create a responsive layout where the content itself depends on the container geometry

So `onGeometryChange` does **not** eliminate `GeometryReader` entirely. It replaces the common misuse of `GeometryReader` as a measurement hook.

---

## 10. Before and after for geometry measurement

### Older style using `GeometryReader`

```swift
import SwiftUI

struct ResponsiveHeader: View {
    @State private var isCompact = false

    var body: some View {
        Text(isCompact ? "Compact" : "Regular")
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .task(id: proxy.size.width) {
                            isCompact = proxy.size.width < 300
                        }
                }
            }
    }
}
```

### Modern style using `onGeometryChange`

```swift
import SwiftUI

struct ResponsiveHeader: View {
    @State private var isCompact = false

    var body: some View {
        Text(isCompact ? "Compact" : "Regular")
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.width < 300
            } action: { isCompact in
                self.isCompact = isCompact
            }
    }
}
```

The modern version communicates intent much more directly.

---

## 11. Example: tracking a frame in global coordinates

```swift
import SwiftUI

struct GlobalFrameExample: View {
    @State private var frame: CGRect = .zero

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.blue)
            .frame(width: 120, height: 80)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                frame = newFrame
            }
    }
}
```

That is much cleaner than adding a background `GeometryReader` just to capture a frame.

---

## 12. Practical migration advice

### For observation

1. Replace `ObservableObject` with `@Observable`.
2. Remove `@Published` from observed properties.
3. Convert `@StateObject` to `@State` where the view owns the model.
4. Convert `@EnvironmentObject` to `@Environment(Type.self)`.
5. Remove `@ObservedObject` in read-only child views.
6. Use `@Bindable` when a child needs bindings into the model.

### For geometry

1. Look for `GeometryReader` used in `.background` or `.overlay` purely to read size or frame.
2. Replace those with `onGeometryChange`.
3. Keep `GeometryReader` where layout actually depends on container geometry.

---

## 13. Availability and deployment guidance

Observation with `@Observable` requires the modern Observation/SwiftUI system introduced alongside **iOS 17, iPadOS 17, macOS 14, tvOS 17, and watchOS 10**.

That means:

- for new apps targeting those OS versions and later, prefer `@Observable`
- for mixed deployment targets, you may need to keep some `ObservableObject` code
- for incremental migration, it is fine to mix both systems temporarily

For geometry, `onGeometryChange` is the modern API to prefer when it is available in your deployment target. If you support older OS versions that don’t provide it, `GeometryReader`-based measurement remains the fallback.

---

## 14. Bottom line

### `@Observable` vs `ObservableObject`

Use `@Observable` for modern SwiftUI code because it:

- removes `@Published` boilerplate
- integrates better with `@State`, `@Environment`, and `@Bindable`
- tracks exactly what a view reads
- better matches SwiftUI’s current observation model

### `onGeometryChange` vs `GeometryReader`

Use `onGeometryChange` when you need to **observe geometry values**.

Keep `GeometryReader` when you need to **construct layout from geometry**.

That is the cleanest way to think about the shift:

- **Observation replaces object-publisher observation**
- **Geometry change observation replaces measurement hacks**

---

## Sources

- Apple Developer Documentation: *Migrating from the Observable Object protocol to the Observable macro*  
  https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro

- Apple Developer Documentation: *Observation*  
  https://developer.apple.com/documentation/observation

- Apple Developer Documentation: *Managing model data in your app*  
  https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app

- Apple Developer Documentation: *onGeometryChange(for:of:action:)*  
  https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)

- Apple Developer Documentation: *GeometryReader*  
  https://developer.apple.com/documentation/swiftui/geometryreader
