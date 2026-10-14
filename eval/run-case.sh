#!/usr/bin/env bash
#
# Validate or evaluate an issue-fix case.
#
#   eval/run-case.sh --validate                 # every case: fixture self-check
#   eval/run-case.sh --validate <case-id>       # one case
#   eval/run-case.sh --eval <case-id> [--model provider/id] [--repeats N]
#
# --validate proves the fixture itself is sound: the seeded defect fails the
# hidden oracle, and the reference patch makes it pass. A case that fails
# validation is a broken case, not a failed agent.
#
# --eval runs the issue-fix agent against the case in a throwaway copy and scores
# it with the hidden oracle. It needs a real provider (see eval/README.md).
#
set -euo pipefail

EVAL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CASES_DIR="$EVAL_DIR/cases"
RESULTS_DIR="$EVAL_DIR/results"
EXTENSION_DIR="$(cd -- "$EVAL_DIR/.." && pwd)/.opencode"

MODE=""
CASE_ID=""
MODEL=""
REPEATS=1

usage() {
	cat <<'USAGE'
usage: eval/run-case.sh [--validate | --eval] [case-id] [--model provider/id] [--repeats N]

  --validate   fixture self-check (seeded defect must fail, reference patch must fix)
  --eval       run the issue-fix agent and score it with the hidden oracle
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
	--validate)
		MODE="validate"
		shift
		;;
	--eval)
		MODE="eval"
		shift
		;;
	--model)
		MODEL="${2:?--model needs a value}"
		shift 2
		;;
	--repeats)
		REPEATS="${2:?--repeats needs a number}"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		CASE_ID="$1"
		shift
		;;
	esac
done

if [ -z "$MODE" ]; then
	usage >&2
	exit 2
fi

# Read case.json without assuming jq is installed.
read_case() {
	node -e '
    const c = require(process.argv[1]);
    const q = (s) => "'"'"'" + String(s).replace(/'"'"'/g, "'"'"'\\'"'"''"'"'") + "'"'"'";
    const out = [
      ["C_ID", c.id], ["C_LANG", c.language], ["C_TYPE", c.type],
      ["C_CLARITY", c.issue_clarity], ["C_COVERAGE", c.test_coverage],
      ["C_TICKET", c.ticket], ["C_REPO", c.repo],
      ["C_ORACLE", (c.oracle || []).join(" ")],
      ["C_TEST_CMD", c.test_cmd], ["C_PATCH", c.reference_patch],
      ["C_TOOLCHAIN", c.toolchain]
    ];
    for (const [k, v] of out) console.log(k + "=" + q(v));
  ' "$1"
}

setup_workspace() {
	local case_dir="$1"
	WS="$(mktemp -d)"
	cp -R "$case_dir/repo/." "$WS/"

	# The temp workspace needs its own copy of the extension: OpenCode resolves
	# agents/commands/skills from the project directory, not from this repo.
	# It goes in before the base commit so it never shows up as an agent change.
	local rel_src
	mkdir -p "$WS/.opencode"
	for rel_src in agents/issue-fix.md agents/issue-fix-verifier.md commands/issue-fix.md; do
		mkdir -p "$WS/.opencode/$(dirname "$rel_src")"
		cp "$EXTENSION_DIR/$rel_src" "$WS/.opencode/$rel_src"
	done
	mkdir -p "$WS/.opencode/skills"
	cp -R "$EXTENSION_DIR/skills/issue-fix-"* "$WS/.opencode/skills/"

	(
		cd "$WS"
		git init -q
		git config user.email "eval@example.invalid"
		git config user.name "issue-fix eval"
		git add -A
		git commit -qm "base"
	)
}

# The oracle must NOT be present while the agent works: in a sealed evaluation,
# agents still go looking for hidden grading material in roughly four runs out of
# five, and any oracle left in the tree can be adopted as the agent's own repro.
# Install it only for scoring.
install_oracle() {
	local case_dir="$1"
	local entry dst src
	for entry in $C_ORACLE; do
		if [ "${entry#*=}" != "$entry" ]; then
			dst="${entry%%=*}"
			src="${entry#*=}"
		else
			dst="$entry"
			src="$entry"
		fi
		mkdir -p "$WS/$(dirname "$dst")"
		cp "$case_dir/oracle/$src" "$WS/$dst"
	done
}

# Did the run touch or mention a hidden oracle file? Generic names such as
# __init__.py or run-*.sh are ignored: they match anything, not evidence of a leak.
oracle_leak() {
	local log="$1" entry src base
	for entry in $C_ORACLE; do
		src="$entry"
		[ "${entry#*=}" != "$entry" ] && src="${entry#*=}"
		base="$(basename "$src")"
		case "$base" in
		__init__.py | conftest.py | run-*.sh | setup.py | Makefile) continue ;;
		esac
		if grep -qiF "$base" "$log" 2>/dev/null; then
			echo "true:$base"
			return
		fi
	done
	echo "false"
}

# Infrastructure failures are not agent failures. Record them separately so a
# provider outage never gets scored as a wrong patch.
abort_reason() {
	local log="$1"
	if grep -aqE 'Bad Request: \{"model"' "$log" 2>/dev/null; then echo "provider_bad_request"; return; fi
	if grep -aqi 'free tier can only be used' "$log" 2>/dev/null; then echo "provider_free_tier_subagent"; return; fi
	if grep -aq 'Unexpected server error' "$log" 2>/dev/null; then echo "provider_server_error"; return; fi
	if grep -aq 'Command not found' "$log" 2>/dev/null; then echo "command_not_found"; return; fi
	echo ""
}

STATES_RE='FIXED|PARTIALLY_FIXED|NOT_REPRODUCIBLE|NEEDS_INFO|NOT_A_BUG|OUT_OF_SCOPE|BUDGET_EXHAUSTED'

# The report template lists every state name, so a bare grep is ambiguous.
# Require either a heading carrying the state, or an explicit "Terminal state" line.
extract_state() {
	local log="$1"
	local report found
	report="$(ls -1 "$WS"/.issue-fix/runs/*/report.md 2>/dev/null | head -1)"
	if [ -n "$report" ]; then
		found="$(grep -m1 -oE "^# .*(—|-) *\`?($STATES_RE)" "$report" 2>/dev/null | grep -oE "($STATES_RE)" || true)"
		[ -n "$found" ] || found="$(grep -m1 -oiE "terminal state:? *\`?($STATES_RE)" "$report" 2>/dev/null | grep -oE "($STATES_RE)" || true)"
		[ -n "$found" ] || found="$(grep -m1 -oE "^#+ *($STATES_RE)" "$report" 2>/dev/null | grep -oE "($STATES_RE)" || true)"
		if [ -n "$found" ]; then
			echo "$found"
			return
		fi
	fi
	found="$(grep -m1 -oiE "terminal state:? *\`?($STATES_RE)" "$log" 2>/dev/null | grep -oE "($STATES_RE)" || true)"
	echo "${found:-UNKNOWN}"
}

run_tests() {
	local dir="$1"
	(cd "$dir" && eval "$C_TEST_CMD") 2>&1
}

validate_case() {
	local case_dir="$1"
	eval "$(read_case "$case_dir/case.json")"
	if ! command -v "$C_TOOLCHAIN" >/dev/null 2>&1; then
		echo "SKIP  $C_ID (toolchain '$C_TOOLCHAIN' not installed)"
		return 0
	fi
	setup_workspace "$case_dir"
	install_oracle "$case_dir"

	local before before_rc after after_rc
	before="$(run_tests "$WS")" && before_rc=0 || before_rc=$?
	if [ "$before_rc" -eq 0 ]; then
		echo "FAIL  $C_ID — the seeded defect did not fail the oracle (fixture is broken)"
		printf '%s\n' "$before" | tail -20
		rm -rf "$WS"
		return 1
	fi
	echo "ok    $C_ID — seeded defect fails the oracle"

	if ! patch -p1 -d "$WS" --silent <"$case_dir/$C_PATCH"; then
		echo "FAIL  $C_ID — reference patch did not apply (fixture is broken)"
		rm -rf "$WS"
		return 1
	fi
	after="$(run_tests "$WS")" && after_rc=0 || after_rc=$?
	if [ "$after_rc" -ne 0 ]; then
		echo "FAIL  $C_ID — oracle still fails after the reference patch (fixture is broken)"
		printf '%s\n' "$after" | tail -20
		rm -rf "$WS"
		return 1
	fi
	echo "ok    $C_ID — reference patch satisfies the oracle"
	rm -rf "$WS"
	return 0
}

eval_case() {
	local case_dir="$1"
	eval "$(read_case "$case_dir/case.json")"
	if ! command -v "$C_TOOLCHAIN" >/dev/null 2>&1; then
		echo "SKIP  $C_ID (toolchain '$C_TOOLCHAIN' not installed)"
		return 0
	fi
	mkdir -p "$RESULTS_DIR"
	local n
	for n in $(seq 1 "$REPEATS"); do
		setup_workspace "$case_dir"
		local log="$RESULTS_DIR/$C_ID.run$n.log"
		local agent_args=(--command issue-fix --agent issue-fix --auto --dir "$WS")
		[ -n "$MODEL" ] && agent_args+=(--model "$MODEL")
		echo "run   $C_ID #$n -> $log"
		(
			cd "$WS"
			opencode run "${agent_args[@]}" "$(cat "$case_dir/$C_TICKET")"
		) >"$log" 2>&1 || echo "warn  agent run exited non-zero (see $log)"

		install_oracle "$case_dir"

		local state resolved leak files added repro abort
		state="$(extract_state "$log")"
		abort="$(abort_reason "$log")"
		if [ -n "$abort" ] && [ "$state" = "UNKNOWN" ]; then state="ABORTED_INFRA"; fi
		if run_tests "$WS" >/dev/null 2>&1; then resolved="true"; else resolved="false"; fi
		leak="$(oracle_leak "$log")"
		files="$(cd "$WS" && git status --porcelain=v1 -uall | cut -c4- | tr '\n' ' ')"
		# Files the agent added, excluding the oracle we just installed.
		added="$(cd "$WS" && git status --porcelain=v1 -uall | cut -c4- | tr '\n' ' ')"
		local oracle_names="" entry
		for entry in $C_ORACLE; do
			oracle_names="$oracle_names ${entry%%=*}"
		done
		local f kept=""
		for f in $added; do
			case " $oracle_names " in *" $f "*) ;; *) kept="$kept $f" ;; esac
		done
		repro="$(printf '%s' "$kept" | grep -qiE 'test|spec|repro' && echo true || echo false)"
		printf '{"case":"%s","run":%s,"language":"%s","terminal_state":"%s","oracle_passed":%s,"repro_test_added":%s,"oracle_leak":%s,"abort_reason":"%s","changed_files":"%s"}\n' \
			"$C_ID" "$n" "$C_LANG" "$state" "$resolved" "$repro" "$leak" "$abort" "$files" >>"$RESULTS_DIR/$C_ID.jsonl"
		echo "      terminal_state=$state oracle_passed=$resolved repro_test=$repro oracle_leak=$leak abort=$abort changed=[$files]"
		rm -rf "$WS"
	done
}

if [ -n "$CASE_ID" ]; then
	case_dir="$CASES_DIR/$CASE_ID"
	if [ ! -d "$case_dir" ]; then
		echo "no such case: $case_dir" >&2
		exit 1
	fi
	if [ "$MODE" = "validate" ]; then validate_case "$case_dir"; else eval_case "$case_dir"; fi
	exit $?
fi

failed=0
for case_dir in "$CASES_DIR"/*; do
	[ -d "$case_dir" ] || continue
	if [ "$MODE" = "validate" ]; then
		validate_case "$case_dir" || failed=1
	else
		eval_case "$case_dir"
	fi
done
exit "$failed"