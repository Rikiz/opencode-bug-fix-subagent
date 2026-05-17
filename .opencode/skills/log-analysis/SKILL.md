---
name: log-analysis
description: "Systematic approach to analyzing application logs — locate, filter, parse, and correlate log entries to find bug root causes"
---

# Log Analysis Methodology

When analyzing logs as part of bug diagnosis, follow this systematic approach.

## 1. Locate Logs

Search common log locations:

- Application logs: `./logs/`, `./log/`, `./var/log/`
- Framework defaults: check framework config for log output paths
- Runtime logs: `~/.pm2/logs/`, `/var/log/`, Docker container logs
- Use `glob` with patterns like `**/*.log`, `**/logs/**`, `**/*.log.*`
- Use `bash` to find logs: `find . -name "*.log" -type f`, `docker compose logs`

If log location is unknown, ask the user.

## 2. Identify Log Format

Determine the format before parsing:

- **JSON structured logs**: Each line is a JSON object with fields like `level`, `message`, `timestamp`, `stack`
  - Parse with: `jq`, or `grep` + manual inspection
  - Example: `cat app.log | jq 'select(.level=="error")'`
- **Standard text logs**: Timestamp + level + message
  - Patterns: `2024-01-15 10:30:00 [ERROR] message` or `ERROR 2024-01-15 message`
  - Parse with: `grep`, `awk`, `sed`
- **Unstructured logs**: Free-form text
  - Search for keywords: error, exception, fail, crash, timeout, panic, fatal
  - Use: `grep -i -E "error|exception|fail|crash|fatal|panic"`

## 3. Filter & Extract

### By log level

```bash
# Errors only
grep -i "error\|fatal\|critical\|panic" app.log

# Errors and warnings
grep -i "error\|warn\|fatal\|critical" app.log

# JSON logs: filter by level field
cat app.log | jq 'select(.level == "error" or .level == "fatal")'
```

### By time range

```bash
# Logs between specific times
awk '/2024-01-15 10:3/,/2024-01-15 10:4/' app.log

# Last N lines
tail -n 1000 app.log
```

### By pattern with context

```bash
# Search for specific error
grep "NullPointerException" app.log

# Show 5 lines before and after
grep -B5 -A5 "NullPointerException" app.log

# Count occurrences
grep -c "NullPointerException" app.log
```

## 4. Analyze Stack Traces

Stack traces are the most valuable log entries for bug diagnosis:

1. Find the **first** error in the chain — later errors may be cascading symptoms
2. Extract file paths and line numbers from the trace
3. The **top frame** (closest to the throw point) is usually the root cause location
4. Read the source files referenced in the trace using `read`
5. Trace the call chain backwards from the failure point

Common stack trace patterns by language:

| Language | Pattern |
|----------|---------|
| Java/Scala | `at com.example.ClassName.methodName(ClassName.java:42)` |
| Python | `File "path/to/file.py", line 42, in method_name` |
| Node.js | `at ClassName.methodName (/path/to/file.js:42:15)` |
| Go | `path/to/file.go:42 +0xabc` |
| Rust | `at src/file.rs:42` |
| C# | `at Namespace.ClassName.MethodName() in C:\path\file.cs:line 42` |

## 5. Correlate Logs with Source Code

1. Extract file paths and line numbers from log entries
2. Read those source locations to understand the context
3. Use `grep` to find where the failing function is defined and called
4. Use `lsp` to trace references and call chains
5. Map log messages back to the code that produces them (search for the log message string in source)

## 6. Reconstruct the Error Timeline

1. Sort log entries by timestamp
2. Identify the **first anomaly** — the earliest error or deviation from normal behavior
3. Track the **causal chain**: Error A triggered Error B which caused Error C
4. Focus on the **root cause** (Error A), not the symptoms (Error C)
5. Look for patterns: does the error happen at specific times, under load, or after deployments?

## 7. Common Error Categories

- **Memory issues**: OOM, heap exhausted, GC overhead, stack overflow
- **Timeout errors**: connection timeout, read timeout, write timeout, deadline exceeded
- **Permission errors**: EACCES, permission denied, 403, unauthorized
- **Concurrency bugs**: race conditions, deadlocks, inconsistent state, double-free
- **Configuration errors**: not found, missing env var, invalid config, parse error
- **Network errors**: connection refused, reset, DNS resolution, SSL/TLS
- **Data errors**: null pointer, undefined, index out of bounds, type mismatch

## Tips

- Always start with the **first** error, not the last — the first error is closest to the root cause
- Use `grep -v` to filter out noise (health checks, heartbeats, known benign warnings)
- Check whether the error is new — compare with older logs or git history if available
- Errors often cluster around the same timestamp — look for temporal correlation
- When logs are large, use `tail` + `grep` to narrow scope before reading full entries
- For JSON logs, `jq` is your best tool — learn patterns like `jq 'select()', `jq 'unique_by()`, `jq 'sort_by(.timestamp)'`
- For distributed systems, correlate request IDs or trace IDs across services
