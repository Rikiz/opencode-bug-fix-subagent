# Rust / C / C++

## Rust

Repro location: a `#[cfg(test)] mod repro` inside the source file, or `tests/<name>.rs` for a black-box test of the public API.

```bash
cargo test repro_empty_list -- --exact --nocapture
cargo build
```

Traps: compilation dominates the runtime — a three-run confirmation may take minutes, so start early. `--nocapture` is required to see `println!`/`dbg!` output from a passing test. Cargo caches builds, so an unchanged crate may appear to "run" instantly; check that the binary was actually relinked after an edit. Edition and MSRV come from `Cargo.toml`; do not change them.

## C / C++

Repro location: mirror the project's existing suite — `test/` or `tests/` with CTest, gtest, or Catch2.

```bash
ctest -R repro_empty_list --output-on-failure
ctest --repeat until-pass:0 -R repro_empty_list      # repeat 10x, stop on first failure
```

Traps: the build system is the hard part, not the test. Discover it first (`CMakeLists.txt`, `meson.build`, `Makefile`, `conan.txt`, `vcpkg.json`) and build once before writing anything. CTest only runs registered tests — an unregistered file is silently ignored, which looks exactly like a pass. Confirm the test count in the output.

## Conventions

- Match the project's assertion macro (`ASSERT_*` vs `TEST_F` vs Catch2 `REQUIRE`).
- Ownership and lifetime rules are the usual root cause: check for double free, use-after-free, missing move, or an unchecked `Result`.
- Build and test flags must match the project's CI invocation. A local-only `-O0` run can hide UB that CI's `-O2` exposes; say which you used.
- Sanitizers (`-fsanitize=address,undefined`, ASan/UBSan) are worth one run when memory behaviour is involved, if the project already supports them.

## Non-reproducible failures here
Uninitialised memory, UB, and thread races — all of which can look deterministic in one run and vanish in another. If the repro is not stable after three runs, report it as flaky-suspect rather than forcing it.
