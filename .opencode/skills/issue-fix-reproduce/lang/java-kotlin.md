# Java / Kotlin

## Where the repro goes
`src/test/java/<same package path as the code under test>/<Class>ReproTest.java`, or `src/test/kotlin/...` for Kotlin. Mirror the production package exactly — a different package cannot see package-private code and will misreport the failure.

## Run one test
```bash
mvn -q -Dtest=ParserReproTest#testEmptyList test      # Maven / Surefire
./gradlew test --tests 'com.example.ParserReproTest.testEmptyList'
./mvnw -q -Dtest=ParserReproTest test                # wrapper (may download on first run)
```
Build only: `mvn -q -DskipTests compile` / `./gradlew compileJava`.

## Repeat-run traps
- **Gradle skips tests that are up to date.** `test --tests ...` can print success without executing anything. Use `./gradlew test --tests '...' --rerun-tasks`, or run `./gradlew cleanTest test --tests '...'`.
- Maven Surefire does not cache across separate `mvn` invocations, but a reactor build can skip a module already built. Add `-DskipTests=false` and re-run from the module directory if the count looks wrong.
- If the test is green but reported "0 tests", the filter did not match. Check the method signature — a wrong filter looks exactly like a pass.

## Conventions
- JUnit 4 (`org.junit.Test`, `assertEquals`) vs JUnit 5 (`org.junit.jupiter.api.Test`, `assertThrows`). Match whatever the neighbouring test uses; a mixed import fails to compile or silently does nothing.
- Use the assertion that expresses the contract: `assertThrows(IllegalArgumentException.class, ...)` rather than catching and asserting on a message.
- Kotlin: prefer the same assertion library as neighbours (`kotlin.test`, AssertJ, JUnit).
- Kotlin coroutine or Spring code: mirror the test harness the project already uses (`runTest`, `@SpringBootTest`, Testcontainers). Do not invent a new one.

## Non-reproducible failures here
Async timing and Spring context startup. If the repro passes once, it is not a repro yet — add a bound or a determinism fixture before counting it.
