# Lake Michigan Data Provider Checklist

Use this while you hunt for sources. For each provider, capture the details below so the app can eventually ingest, normalize, and score the data reliably.

## Provider basics

- Provider name
- Website URL
- Coverage area
- Species covered
- Historical depth of archive
- Update frequency
- Free or paid
- Contact or documentation link

## Access details

- Public API, private API, downloadable file, HTML page, PDF, or social/report feed
- Authentication method
- Rate limits
- Required query parameters
- Response format: JSON, CSV, XML, HTML, PDF, image
- Whether the source allows commercial or app use

## What the source actually gives us

- Port or geographic area
- Latitude/longitude or only text descriptions
- Date and time of observation
- Surface water temperature
- Temperature at depth
- Thermocline depth
- Current speed/direction at depth
- Wind speed/direction
- Wave height
- Bait concentration or bait species
- Catch counts by species
- Depth of presentation
- Depth of water
- Lure or presentation notes
- Trolling direction or heading
- Report confidence or captain/source credibility

## Historical usefulness

- How many years back does it go
- Can we query by date
- Can we query by area or port
- Can we query by species
- Is the data structured enough to compare year-over-year patterns

## Integration notes I will need from you

- A sample URL
- A sample response or screenshot
- The exact fields visible in the response
- Whether the numbers are measured, estimated, or opinion/report-based
- Whether timestamps are local time, UTC, or unclear
- Any obvious missing values or inconsistencies

## Priority source categories

1. Weather and marine forecast data
2. Surface and subsurface temperature data
3. Current-at-depth data
4. Baitfish concentration or forage indicators
5. Current fishing reports
6. Archived fishing reports
7. Catch and survey datasets from agencies

## Best format to send me each source

Paste each source in this format:

```text
Provider:
URL:
Type:
Coverage:
Years available:
Update frequency:
Fields available:
Access method:
Sample link or sample payload:
Notes:
```

That will let me wire the data layer much faster once you start collecting providers.
