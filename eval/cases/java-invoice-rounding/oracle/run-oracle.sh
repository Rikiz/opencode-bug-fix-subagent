#!/usr/bin/env bash
set -euo pipefail
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
javac -d "$out" $(find src/main/java -name '*.java') InvoiceOracle.java
java -cp "$out" InvoiceOracle
