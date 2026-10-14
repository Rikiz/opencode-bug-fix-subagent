# Python

## Where the repro goes
Follow the existing layout: `tests/test_<module>.py`, `tests/<module>/test_<name>.py`, or next to the source if the project puts them there. Name it after the requirement, not after the method: `test_empty_list_returns_empty_result`.

## Run one test
```bash
pytest -q tests/test_parser.py::test_empty_list_returns_empty_result
python -m pytest -q tests/test_parser.py -k empty_list
unittest -v tests.test_parser.ParserTest.test_empty_list
```
Show more on failure: `pytest -q -x --tb=short`.

## Repeat-run traps
- Fix the seed and disable hash randomization for anything random: `pytest -p no:randomly` if `pytest-randomly` is installed.
- Freeze time explicitly (`freezegun`, or inject the clock) rather than sleeping.
- `pytest-xdist` parallel runs share state — run the repro serially with `-p no:xdist` when results look unstable.
- A test that passes in the full suite but fails alone (or the reverse) usually means shared fixture state or ordering dependence. That is a finding about the suite, not about your fix; record it.

## Conventions
- Match the assertion style already present (`assert`, `pytest.raises`, `unittest.TestCase`).
- Fixtures over setup code: reuse the project's conftest fixtures so the repro inherits the same environment as its neighbours.
- Monkeypatch the seam the bug is in, not the caller's internals — unless the bug *is* in the caller.
- Async code: reproduce with the project's own async test style (`pytest.mark.asyncio`, `anyio`) so the event loop semantics match production.

## Non-reproducible failures here
Wall-clock, timezone, locale, and hash-ordering. If you cannot pin one of these, say so instead of adding a retry.
