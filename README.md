# Memory Scroll

An iOS app that generates randomised photo strips from your library and exports them as a single composited image.

## Features

- **Random scroll generation** — picks photos from your library and stitches them into a vertical or horizontal strip
- **Time frame filter** — restrict picks to the last week, month, year, 5 years, all time, or a custom date range
- **Even time distribution** — optionally spread photos evenly across the selected window so no single period dominates
- **Category filter** — filter by People, Scenery, Food, Architecture, or Animals using on-device Vision classification
- **Location filter** — filter by city/country derived from photo GPS data; paginated geocoding respects Apple's rate limit
- **Crop adjustment** — drag per-photo top/bottom handles to trim each slot; crops are applied non-destructively at composite time
- **Ban list** — exclude specific photos from all future generations; manage the list from the Banned tab
- **History** — generated strips are saved to disk and browsable across restarts; supports share, re-crop, save, and delete
- **Share & save** — share the composite image or save it to a dedicated "Memory Scroll" Photos album (saved strips are excluded from future picks)
- **Localization** — English and Simplified Chinese (zh-Hans)

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- A physical device or simulator with photo library access

## How to Run

1. Clone the repository and open `MemoryScroll.xcodeproj` in Xcode.
2. Select your target device or simulator in the scheme picker.
3. Press **⌘R** to build and run.

On first launch the app will request **Photos** access. Full access is recommended; limited access restricts the pool of available photos.

### Chinese localisation

The zh-Hans translation is included. To verify it in the simulator:

1. In Xcode go to **Product → Scheme → Edit Scheme**.
2. Under **Run → Options**, set **App Language** to **Chinese (Simplified)**.
3. Re-run the app.
