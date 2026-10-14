#!/usr/bin/env bash
#
# Install / uninstall the OpenCode issue-fix extension.
#
# The extension is pure Markdown (agents + skills + command), so installation is
# a file copy. Nothing is executed from the target config directory, and no
# tracked file in the target repository is touched.
#
# Usage:
#   scripts/install-issue-fix.sh [--dest DIR] [--link] [--force] [--dry-run]
#   scripts/install-issue-fix.sh --uninstall [--dest DIR] [--dry-run]
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SRC_OPENCODE="$REPO_ROOT/.opencode"
MANIFEST_NAME="issue-fix-extension.manifest"

DEST="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
MODE="copy"
DRY_RUN=0
FORCE=0
UNINSTALL=0

usage() {
	cat <<'USAGE'
Install the OpenCode issue-fix extension (agents, skills, command) into an OpenCode config dir.

  --dest DIR     target config dir (default: $OPENCODE_CONFIG_DIR or ~/.config/opencode)
  --link         symlink instead of copy (for development; reflects edits immediately)
  --force        overwrite files that exist and differ
  --dry-run      print what would happen, change nothing
  --uninstall    remove files listed in the install manifest
  -h, --help     this text
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
	--dest)
		DEST="${2:?--dest needs a path}"
		shift 2
		;;
	--link)
		MODE="link"
		shift
		;;
	--force)
		FORCE=1
		shift
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--uninstall)
		UNINSTALL=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '  would run: %s\n' "$*"
	else
		"$@"
	fi
}

# Files shipped by the extension, as paths relative to .opencode/
collect_files() {
	local f
	printf '%s\n' \
		"agents/issue-fix.md" \
		"agents/issue-fix-verifier.md" \
		"commands/issue-fix.md"
	for f in "$SRC_OPENCODE"/skills/issue-fix-*; do
		[ -e "$f" ] || continue
		find "$f" -type f -print
	done
	if [ -f "$SRC_OPENCODE/plugins/issue-fix-guard.ts" ]; then
		printf '%s\n' "plugins/issue-fix-guard.ts"
	fi
}

# Remove directories that became empty, deepest first.
prune_dirs() {
	local dir="${1%/}"
	while [ -n "$dir" ] && [ "$dir" != "/" ] && [ -d "$dir" ]; do
		rmdir "$dir" 2>/dev/null || break
		dir="$(dirname "$dir")"
	done
}

if [ "$UNINSTALL" -eq 1 ]; then
	manifest="$DEST/$MANIFEST_NAME"
	legacy="$DEST/bugfix-extension.manifest"
	manifests="$manifest"
	if [ ! -f "$manifest" ] && [ ! -f "$legacy" ]; then
		echo "no manifest at $manifest — nothing installed by this script"
		exit 0
	fi
	echo "uninstalling from $DEST"
	if [ -f "$legacy" ]; then
		# Files installed by the pre-rename version of this script, under the old
		# `bugfix-*` names. Swept here so an upgrade is never stuck with orphans.
		echo "  also cleaning files from the pre-rename install (bugfix-extension.manifest)"
		manifests="$legacy $manifest"
	fi
	for manifest in $manifests; do
		[ -f "$manifest" ] || continue
		while IFS= read -r rel; do
			[ -n "$rel" ] || continue
			target="$DEST/$rel"
			if [ -e "$target" ] || [ -L "$target" ]; then
				run rm -f "$target"
				echo "  removed $rel"
				prune_dirs "$DEST/$(dirname "$rel")"
			else
				echo "  missing, skipped: $rel"
			fi
		done <"$manifest"
		run rm -f "$manifest"
	done
	if [ "$DRY_RUN" -eq 0 ] && [ -d "$DEST" ] && [ -z "$(ls -A "$DEST" 2>/dev/null)" ]; then
		rmdir "$DEST"
		echo "  removed empty $DEST"
	fi
	echo "done"
	exit 0
fi

if [ ! -d "$SRC_OPENCODE" ]; then
	echo "source not found: $SRC_OPENCODE" >&2
	exit 1
fi

FILES=()
while IFS= read -r line; do
	[ -n "$line" ] && FILES+=("$line")
done < <(collect_files | sed "s|^$SRC_OPENCODE/||" | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
	echo "no extension files found under $SRC_OPENCODE" >&2
	exit 1
fi

echo "source: $SRC_OPENCODE"
echo "dest:   $DEST ($MODE)"

# Conflict detection: a destination file that exists with different content.
conflicts=()
for rel in "${FILES[@]}"; do
	target="$DEST/$rel"
	if [ -e "$target" ] && ! cmp -s "$SRC_OPENCODE/$rel" "$target"; then
		conflicts+=("$rel")
	fi
done

if [ "${#conflicts[@]}" -gt 0 ] && [ "$FORCE" -ne 1 ]; then
	echo
	echo "refusing to overwrite files that differ:"
	printf '  %s\n' "${conflicts[@]}"
	echo
	echo "review them, then re-run with --force to replace."
	exit 3
fi

installed=()
for rel in "${FILES[@]}"; do
	target="$DEST/$rel"
	case "$MODE" in
	link) action=(ln -sfn "$SRC_OPENCODE/$rel" "$target") ;;
	*) action=(cp "$SRC_OPENCODE/$rel" "$target") ;;
	esac
	run mkdir -p "$(dirname "$target")"
	run "${action[@]}"
	installed+=("$rel")
	echo "  ${MODE} $rel"
done

# Record what we own, so --uninstall never touches anything else.
if [ "$DRY_RUN" -eq 0 ]; then
	printf '%s\n' "${installed[@]}" >"$DEST/$MANIFEST_NAME"
	echo "manifest: $DEST/$MANIFEST_NAME"
fi

if [ -f "$SRC_OPENCODE/plugins/issue-fix-guard.ts" ]; then
	echo
	echo "note: a plugin was installed. Make sure the target config dir has a recent"
	echo "      @opencode-ai/plugin dependency, or tool() imports will fail."
	echo "      e.g. in $DEST/package.json: {\"dependencies\":{\"@opencode-ai/plugin\":\"1.19.0\"}}"
fi

cat <<DONE

done. ${#installed[@]} file(s).

next:
  cd <the repository you want to fix>
  opencode                     # then either:
    Tab -> issue-fix, then paste the ticket
    or:  /issue-fix <paste the ticket>

verify what landed:
  opencode agent list | grep issue-fix
  opencode debug agent issue-fix
DONE