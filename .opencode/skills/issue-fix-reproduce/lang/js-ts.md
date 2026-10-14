# JavaScript / TypeScript

## Where the repro goes
Mirror the project: `src/foo.test.ts` beside the source, or `test/`, or `__tests__/`. Match the file naming pattern of the nearest existing test — that is what the runner's glob will pick up.

## Run one test
```bash
vitest run src/parser.test.ts -t 'returns empty for empty list'
npx --no-install jest src/parser.test.ts -t 'returns empty'   # no-install so nothing is fetched
node --test test/parser.test.js
npm test -- src/parser.test.ts
```
Type check: `npx --no-install tsc --noEmit`.

## Repeat-run traps
- **Always pass `run`.** Bare `vitest` or `jest` starts watch mode in an interactive terminal and hangs; in a non-TTY it usually exits immediately, which looks like a silent pass.
- `npx <pkg>` may download the package. Use `npx --no-install` or the local binary (`./node_modules/.bin/vitest`) so nothing is fetched.
- Vitest caches transforms; a stale cache after editing config can produce stale results. If results look impossible, re-run once before believing them.
- Watch mode + `--run` mixed flags conflict; pick one.
- Parallel workers can hide ordering dependence — re-run the repro alone with a single worker to confirm.

## Conventions
- Match the assertion library in use (`vitest` `expect`, `@testing-library/jest-dom`, `node:assert`).
- Async: `await` the call under test; assert on the resolved value, never on a promise.
- Avoid real network, real clock, and real filesystem. Freeze time (`vi.useFakeTimestamps`, `jest.useFakeTimers`) and use temp dirs.
- For a bug that needs the real module graph (not a mock), assert through the public entry point; a heavily mocked test cannot reproduce an integration bug.
