# Go

## Where the repro goes
Same package as the code under test: `pkg/parser/parser_repro_test.go`. An external test package (`package parser_test`) is fine when the code is exported, and cannot see unexported identifiers.

## Run one test
```bash
go test ./pkg/parser/ -run '^TestReproEmptyList$' -count=1 -v
go test ./pkg/parser/ -run '^TestReproEmptyList$' -count=3    # the three-run rule
go build ./...
```
With a race detector for concurrency bugs: add `-race`.

## Repeat-run traps
- **`-count=1` is mandatory.** Go caches successful test results by package and arguments. Without it the second and third runs return cached success and your repro appears to pass.
- `-v` is needed to see output; by default passing tests print nothing.
- A test in `t.Parallel()` that touches shared state will misbehave under repetition. For the repro, drop `t.Parallel()`.
- Package-level fixtures in `TestMain` may hide ordering effects.

## Conventions
- Table-driven tests when the project uses them: `cases := []struct{name string; in []int; want []int}{...}`.
- Assert with `t.Errorf`/`t.Fatalf`; use `t.Helper()` in helpers.
- Return errors rather than panicking in library code; a repro that expects a panic should say so explicitly.
- No third-party assertion libraries unless the project already uses them — `go.mod` cannot be changed.

## Non-reproducible failures here
Goroutine scheduling and map iteration order. A concurrency repro needs `-race` plus repetition; a data race can stay invisible for hundreds of runs. Record how many runs you actually did.
