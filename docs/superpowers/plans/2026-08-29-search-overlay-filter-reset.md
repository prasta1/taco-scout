# Search Overlay Filter Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a filter-reset control directly inside the search overlay so users can clear active filters without closing the search view.

**Architecture:** `SearchOverlayView` currently ignores filters (it searches all tacos, not filtered ones) but doesn't give users a way to clear filters while in the overlay. The fix is to pass `activeFilterCount` and an `onResetFilters` callback into `SearchOverlayView`, then render a visible pill when filters are active. The reset logic mirrors what already exists in `PersistentBottomSheet` and `syncFiltersFromSettings`.

**Tech Stack:** SwiftUI, iOS 17+

---

## File Map

| File | Change |
|---|---|
| `TacoScout/TacoScout/ContentView.swift` | Modify `SearchOverlayView` struct (add params + UI) and update its call site in `ContentView.body` |

---

### Task 1: Add filter-reset UI to `SearchOverlayView` and wire up the call site

**Files:**
- Modify: `TacoScout/TacoScout/ContentView.swift:698-827` (SearchOverlayView definition)
- Modify: `TacoScout/TacoScout/ContentView.swift:121-138` (SearchOverlayView call site)

---

- [ ] **Step 1: Add `activeFilterCount` and `onResetFilters` parameters to `SearchOverlayView`**

Find the `SearchOverlayView` struct definition at line 698. The current parameter list ends at line 704. Add two new `let` properties after `onDismiss`:

```swift
struct SearchOverlayView: View {
    let tacos: [TacoLocation]
    let userLocation: CLLocationCoordinate2D
    let distanceUnit: DistanceUnit
    let searchRadiusLabel: String
    let activeFilterCount: Int
    let onSelect: (TacoLocation) -> Void
    let onDismiss: () -> Void
    let onResetFilters: () -> Void
```

---

- [ ] **Step 2: Add the filter-reset pill to the view body**

In `SearchOverlayView.body`, the search bar `HStack` ends at line ~763 (after the `.padding(.top, Layout.topControlsHeight)` modifier). Immediately after that padding line, add the conditional filter-reset row so it appears below the search bar in all states (prompt, no-results, and results):

```swift
// Filter reset pill — shown whenever filters are active
if activeFilterCount > 0 {
    HStack(spacing: 6) {
        Image(systemName: "line.3.horizontal.decrease.circle.fill")
            .font(.subheadline)
            .foregroundStyle(Color.tacoOrange)
        Text("\(activeFilterCount) filter\(activeFilterCount == 1 ? "" : "s") active")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Spacer()
        Button("Reset") {
            onResetFilters()
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(Color.tacoOrange)
        .buttonStyle(.plain)
        .accessibilityLabel("Reset filters")
    }
    .padding(.horizontal, Layout.paddingContent + 4)
    .padding(.vertical, 6)
}
```

---

- [ ] **Step 3: Update the call site in `ContentView.body`**

Find the `SearchOverlayView(...)` call at line ~121. It currently passes 6 arguments. Add `activeFilterCount` (before `onSelect`) and `onResetFilters` (after `onDismiss`):

```swift
SearchOverlayView(
    tacos: tacos,
    userLocation: effectiveUserLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
    distanceUnit: settingsManager.distanceUnit,
    searchRadiusLabel: settingsManager.searchRadius.label(unit: settingsManager.distanceUnit),
    activeFilterCount: activeFilterCount,
    onSelect: { taco in
        showSearchOverlay = false
        HapticManager.selection()
        selectedTaco = taco
        mapZoomController.centerOnCoordinate(taco.coordinate)
    },
    onDismiss: {
        showSearchOverlay = false
    },
    onResetFilters: {
        withAnimation {
            filter = settingsManager.defaultFilter()
        }
    }
)
```

---

- [ ] **Step 4: Verify the file compiles cleanly**

Use `XcodeRefreshCodeIssuesInFile` on `TacoScout/TacoScout/ContentView.swift`. Expected: no errors. Common mistakes to check:
- `onResetFilters` is declared `let` (not `var`) — it's a closure, needs no `@escaping` in a struct
- The `withAnimation` wrapper in the call site is optional but consistent with how `PersistentBottomSheet` does the same reset

---

- [ ] **Step 5: Commit**

```bash
git add TacoScout/TacoScout/ContentView.swift
git commit -m "Add filter-reset pill to search overlay

Active filters can now be cleared directly from the search view,
matching the existing reset control in the bottom sheet."
```

---

## Self-Review

**Spec coverage:**
- ✅ Filter reset accessible from the search overlay — Task 1, Step 2
- ✅ Shows how many filters are active — `activeFilterCount` passed from ContentView (same value already shown on the gear badge)
- ✅ Reset logic matches existing code — `filter = settingsManager.defaultFilter()`, same as `syncFiltersFromSettings()`

**Placeholder scan:** No TBDs, all code is complete.

**Type consistency:** `activeFilterCount: Int`, `onResetFilters: () -> Void` — consistent across definition (Step 1) and call site (Step 3).
