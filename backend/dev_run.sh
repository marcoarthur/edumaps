#!/usr/bin/env bash
# Run all dev services (Perl Minion worker, Morbo server, and Svelte build watcher)
# with unified logs and clean shutdown.
# Prevents multiple concurrent runs via a lockfile.

set -euo pipefail

LOCKFILE="/tmp/dev_map_app.lock"
PIDS=()

cleanup() {
  echo -e "\n🔴 Stopping all services..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  rm -f "$LOCKFILE"

  # Restore terminal state in case entr/morbo left it raw
  stty sane 2>/dev/null || true
  tput cnorm 2>/dev/null || true # show cursor again

  echo "✅ All stopped."
  exit 0
}

# Ensure cleanup happens on SIGINT/SIGTERM/EXIT
trap cleanup SIGINT SIGTERM EXIT

# --- LOCKFILE CHECK ---
if [[ -f "$LOCKFILE" ]]; then
  oldpid=$(cat "$LOCKFILE")
  if ps -p "$oldpid" &>/dev/null; then
    echo "⚠️  Another dev.sh instance is already running (PID: $oldpid)"
    echo "   If that's incorrect, delete $LOCKFILE manually."
    exit 1
  else
    echo "🧹 Removing stale lockfile (PID $oldpid not running)"
    rm -f "$LOCKFILE"
  fi
fi

# Create a new lockfile with our PID
echo $$ > "$LOCKFILE"

# --- FUNCTION TO START SERVICES ---
run() {
  local name="$1"
  shift
  echo "▶️  Starting $name: $*"
  {
    "$@" 2>&1 | awk -v n="[$name]" '{ print n, $0 }'
  } &
  PIDS+=("$!")
}

# --- SERVICES ---

run "minion-worker" bash -c "find . -name '*.pl' -o -name '*.pm' | entr -r ./edu_maps.pl minion worker"
run "morbo-server" bash -c "morbo ./edu_maps.pl"
run "svelte-build" bash -c "cd ../frontend/map_app && npm run dev"

# --- WAIT for Ctrl+C ---
echo "✅ All services running (PID $$). Press Ctrl+C to stop."
wait
