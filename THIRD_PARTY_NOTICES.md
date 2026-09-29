# Third-party notices

## Free Exercise DB

Tamrino release builds may bundle a reduced metadata-only derivative of:

- Project: `yuhonas/free-exercise-db`
- Source: https://github.com/yuhonas/free-exercise-db
- Pinned commit: `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`
- Source data blob SHA-1: `37beaac6031b34f7a7322b3150d201182c49a71b`
- License: Unlicense / Public Domain

Tamrino's bundled derivative intentionally keeps only exercise identifiers, names, primary muscle, equipment, category and basic tracking-type metadata. It does **not** bundle the upstream exercise instructions or image files.

The library is optional: it is not inserted into the user's personal SQLite database unless the user explicitly imports it from inside the app.
