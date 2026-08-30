# One Mile

One Mile is a native iPhone prototype that answers: “I’m here. I have a little time. What interesting things can I see on foot?” It creates a compact, mostly loop-shaped walk with four to seven curated stops.

## Run it

1. Open `OneMile.xcodeproj` in Xcode 26 or later.
2. Select the `OneMile` scheme and an iPhone simulator running iOS 17 or later.
3. Run. Allow location access, search for another start, or tap the map to drop a pin.

The repository has no third-party dependencies, API keys, or owned backend. Downtown Chicago has a bundled editorial sample. Outside that area, the iPhone directly requests nearby, geotagged Wikipedia articles and supplements sparse results with Apple Maps. Wikipedia responses are batched, filtered on device, visibly attributed, and retained in a bounded local cache.

## What is built

- Current-location start, Apple Maps autocomplete search, and map pin placement
- 30, 60, and 90 minute choices producing 4, 5, or 7 stops
- Angular stop ordering to favor loops and MapKit walking directions for real street geometry
- Map route, ordered stop list, concise “why walk there?” copy, and detail sheets
- Direct Wikipedia geosearch, article summaries, source links, and CC BY-SA labeling
- Thirty-day cache capped at 30 geographic search cells; no global POI database
- Walking mode with user position, next stop, live distance, remaining stops, automatic 45-meter arrival detection, and a manual simulator-friendly arrival control
- Completion summary and local JSON persistence of the last 50 completed walks
- Loading, search failure, missing-location, and insufficient-content states
- Dynamic Type-friendly native controls, VoiceOver labels on map markers, high-contrast route styling, and large primary actions

## Architecture

`AppModel` owns the small application state machine: planning → preview → walking → completed. Views do not retrieve POIs, calculate walking paths, or persist data.

- `InterestingPlaceProviding` isolates discovery/content sources.
- `WikipediaPlaceProvider` performs one batched nearby query and filters relevance locally.
- `WikipediaPlaceCache` bounds on-device storage by both age and geographic cell count.
- `RouteGenerator` selects a geographically balanced stop sequence.
- `WalkingRouteBuilding` isolates MapKit directions and has a straight-line fallback when routing is unavailable.
- `LocationManager` contains Core Location authorization and updates.
- `WalkHistoryStore` contains bounded local Codable persistence.

The protocols are intentionally narrower than a generic travel platform. A future “History” or “Architecture” preference can become a provider/query input without changing the main flow.

## POI and data-source assessment

### Wikipedia / Wikimedia — primary content source

**Strengths:** the Geosearch Action API returns nearby article names, coordinates, and distances. A single batched query also returns introductory extracts, categories, and canonical article URLs, giving the app both discovery and the explanation of why a place matters. No scraping or server-side ingestion is required.

**Implementation:** query up to 50 pages within the walk radius, require place-related category/text signals, reject biographies/lists/disambiguation pages, score locally, and keep the introductory extract. Requests identify the application and use HTTP caching. Each displayed extract links back to its article and is labeled CC BY-SA. Coverage and prose quality still vary by region.

### Apple Maps / MapKit — native location and route layer

**Strengths:** native maps, start-location autocomplete, broad POI coverage, and current walking directions. `MKLocalSearch` can find candidates but rarely explains cultural significance well.

**Implementation:** use MapKit for display, search, current position, and route geometry. When Wikipedia returns fewer than seven promising places, Apple searches for landmarks, museums, historic sites, public art, and parks. Wikipedia wins duplicate resolution because it has sourced narrative content.

### Local storage

The app does not store a world dataset. It caches at most 30 geographic cells, rounded to roughly 1-kilometer areas, for 30 days in the system caches directory. Each entry contains only the filtered places returned for that area. iOS may purge cache files when space is constrained. Completed-walk history remains a separate, bounded local document.

### Deliberately excluded

- No owned server, hosted database, accounts, or deployment pipeline
- No Wikipedia scraping, bulk dump, Wikidata SPARQL dependency, or OpenStreetMap ingestion
- No attempt to download global POI content or tiles

### Request flow

1. Round the user-selected coordinate to a cache cell and check the 30-day local cache.
2. On a miss, send the coordinate and radius directly to English-language Wikipedia.
3. Decode, filter, rank, and cache the batched response entirely on device.
4. Supplement with live Apple POIs only if Wikipedia coverage is thin.
5. Select a loop-like 4–7 stop sequence and ask MapKit for walking geometry.

Licensing and attribution should receive counsel review before App Store release. Primary references reviewed August 14, 2026:

- [Apple `MKLocalSearch`](https://developer.apple.com/documentation/mapkit/mklocalsearch)
- [Wikimedia Geosearch](https://www.mediawiki.org/wiki/API:Geosearch), [API access policy](https://www.mediawiki.org/wiki/Wikimedia_APIs/Access_policy), [licensing](https://www.mediawiki.org/wiki/API:Licensing), and [etiquette](https://www.mediawiki.org/wiki/API:Etiquette)

## Known prototype limits

- Deep, hand-edited content is intentionally limited to the Chicago sample area; elsewhere, quality follows Wikipedia coverage.
- A first Wikipedia sentence is often informative but not always an ideal sidewalk story.
- The current relevance vocabulary and source wiki are English-only; localization needs language-specific ranking rules.
- Apple fallback searches can identify relevance categories, but their generated copy is factual-light by design.
- A new uncached area requires connectivity to Wikipedia and Apple Maps.
- MapKit may produce a route longer or shorter than the chosen duration; production needs iterative stop substitution against the routed distance.
- Arrival is radial and does not yet model the entrance or the correct side of a large site.
- Completed walks are persisted but a history browser is not exposed in this smallest core flow.
- There is no background location mode or turn-by-turn navigation; both are deliberately outside the product promise.
- A production app needs a complete App Icon set, localization, analytics/privacy disclosures, and field testing.

## Production v1 priorities

1. Improve on-device ranking and summary selection using field results, without adding infrastructure.
2. Iterative route optimization against time, pedestrian access, opening hours, and backtracking.
3. Field-tested progress behavior for GPS drift, large POIs, battery usage, and weak connectivity.
4. Saved/offline route packet, safe rerouting, closed-place handling, and clear accessibility auditing.
5. Content quality feedback focused on skips and “worth the walk,” not generic ratings or business listings.
