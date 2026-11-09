# Team app: the venue map (branch night/team-map)

> For: conductor.B@ios.PrompTugal.dinis. From conductor-map@web-summit.indi, a helper of conductor@web-summit.indi, at Indi's word (9 November 2026). Issue WS-181. The design: option B of https://github.com/SGit-AI/SGit-AI__Website__Web-Summit/blob/dev/people/indi/wayfinding/05-venue-map.md

## What it is

A map of the Web Summit venue in the Where tab: Apple Maps with our own simple drawing of the buildings on top. No new package, account or token.

## What changed

- `Apps/Team/Sources/Map/venue.geojson`: our drawing. Buildings from OpenStreetMap (credit "© OpenStreetMap contributors", ODbL, shown under the map). Points: both registration points with their hours, the North Entrance, Centre Stage (MEO Arena), the Startup Lounge, our stand (booth A1-30, Pavilion 1, Thursday 12 November). Pins marked approximate say so. Nothing from Web Summit's own map, and no person's place or hotel.
- `Apps/Team/Sources/Map/VenueMap.swift`: `VenueMapView`. Shapes decoded with `MKGeoJSONDecoder`, coloured by kind and labelled; points as annotations; a sheet per point with a **Directions in Apple Maps** button (walking); **Open Web Summit's app** (https://websummit.com/app/).
- "You" on the map only after the person taps **Show me** and allows location while in use. The position is drawn on the phone and sent nowhere. New purpose string `NSLocationWhenInUseUsageDescription` (Team.xcconfig); `InfoPlistTests` knows it.
- The Where tab has a "Venue map" row under the place card.
- `Apps/Team/Tests/VenueMapTests.swift`: the file is bundled and decodes; all named buildings; both registration points with hours and source; coordinates in Parque das Nações (airport west); a broken file is refused.

## Source of the file

`people/indi/helpers/map/build-venue.mjs` on the team site rebuilds it from Angelo's outlines. The public copy, for the web and Android: https://web-summit.sgit.ai/people/indi/helpers/map/venue.geojson. If the team site's copy changes, copy it here.

## Not done

- Stages 2 to 14, Masterclasses and Meetups: no building is published for them, so they are left off rather than guessed. Pavilion 5 (Night Summit, Info Point) is not in OpenStreetMap's outlines yet.
- The airport pin is approximate (OpenStreetMap could not be read from the building session).
