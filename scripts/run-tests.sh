#!/usr/bin/env bash
set -euo pipefail

# Combined helper to manage a Selenium container and run tests.
# Supports subcommands: up | run | watch | down | help
# Environment variables used:
#  SELENIUM_REMOTE_URL - URL of remote Selenium (default: http://localhost:4444)
#  HEADLESS            - true/false (defaults vary by subcommand)
#  SLOW_MS             - ms per character when typing (default: 0)
#  RECORD              - true/false to attempt screen recording (default: false)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Defaults
SELENIUM_REMOTE_URL=${SELENIUM_REMOTE_URL:-http://localhost:4444}
HEADLESS_DEFAULT=true
SLOW_MS_DEFAULT=0

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  up       Start the Selenium service via docker-compose
  run      Start Selenium (if needed), run tests, then stop (default HEADLESS=${HEADLESS_DEFAULT})
  watch    Start Selenium (if needed), run tests with visible browser, leave container running (HEADLESS=false)
  down     Stop the Selenium service
  help     Show this message

Examples:
  # Run tests (headless by default)
  ./scripts/run-tests.sh run

  # Watch tests in a visible browser and leave Selenium running
  HEADLESS=false SLOW_MS=200 ./scripts/run-tests.sh watch

  # Record a run (best-effort)
  RECORD=true ./scripts/run-tests.sh run

EOF
}

command=${1:-run}

# Decide whether to manage a local docker-compose instance.
# If SELENIUM_REMOTE_URL points at localhost/127.0.0.1 or is the default, we assume local compose is desired.
use_compose=true
if [[ "$SELENIUM_REMOTE_URL" != *"localhost"* && "$SELENIUM_REMOTE_URL" != *"127.0.0.1"* ]]; then
  use_compose=false
fi

start_compose() {
  if [ "$use_compose" = true ]; then
    echo "Starting Selenium via docker-compose..."
    docker-compose up -d
  else
    echo "SELENIUM_REMOTE_URL=$SELENIUM_REMOTE_URL appears remote; skipping docker-compose start."
  fi
}

stop_compose() {
  if [ "$use_compose" = true ]; then
    echo "Stopping Selenium via docker-compose..."
    docker-compose down
  else
    echo "SELENIUM_REMOTE_URL=$SELENIUM_REMOTE_URL appears remote; skipping docker-compose stop."
  fi
}

wait_for_selenium() {
  local url=${1:-$SELENIUM_REMOTE_URL}
  echo "Waiting for Selenium at $url ..."
  for i in {1..60}; do
    if curl -sSf "$url/status" >/dev/null 2>&1; then
      echo "Selenium is ready"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for Selenium at $url"
  return 1
}

start_recorder_in_container() {
  echo "Attempting to start ffmpeg inside selenium container (best-effort)..."
  # Best-effort: install ffmpeg and start recording; ignore failures.
  docker-compose exec -T selenium bash -c "apt-get update && apt-get install -y ffmpeg" || echo "ffmpeg install failed or not permitted"
  DISPLAY_VAL=$(docker-compose exec -T selenium bash -lc 'printenv DISPLAY' | tr -d '\r' || true)
  if [ -z "$DISPLAY_VAL" ]; then
    DISPLAY_VAL=":99"
  fi
  docker-compose exec -d selenium bash -lc "ffmpeg -y -f x11grab -video_size 1920x1080 -i ${DISPLAY_VAL} -r 15 /tmp/test_record.mp4 >/tmp/ffmpeg.log 2>&1 || true"
}

stop_recorder_and_copy() {
  echo "Stopping ffmpeg recorder (best-effort) and copying recording to host..."
  docker-compose exec -T selenium bash -lc "pkill ffmpeg || true"
  sleep 1
  container_id=$(docker-compose ps -q selenium || true)
  if [ -n "$container_id" ]; then
    docker cp ${container_id}:/tmp/test_record.mp4 ./test_record.mp4 || echo "Failed to copy recording from container"
  else
    echo "Could not determine selenium container id; recording may not be copied."
  fi
}

run_tests() {
  local headless=${HEADLESS:-$HEADLESS_DEFAULT}
  local slow_ms=${SLOW_MS:-$SLOW_MS_DEFAULT}
  export SELENIUM_REMOTE_URL HEADLESS SLOW_MS
  echo "Running tests (SELENIUM_REMOTE_URL=$SELENIUM_REMOTE_URL, HEADLESS=${headless}, SLOW_MS=${slow_ms})"

  if [ "${RECORD:-false}" = "true" ]; then
    if [ "$use_compose" = true ]; then
      start_recorder_in_container || true
    else
      echo "Recording requested but docker-compose is not being used; recording skipped."
    fi
    set +e
    mvn test
    mv_exit=$?
    set -e
    if [ "$use_compose" = true ]; then
      stop_recorder_and_copy || true
    fi
    return $mv_exit
  else
    mvn test
  fi
}

case "$command" in
  up)
    start_compose
    ;;

  down)
    stop_compose
    ;;

  run)
    # headless default for run
    : ${HEADLESS:=$HEADLESS_DEFAULT}
    : ${SLOW_MS:=$SLOW_MS_DEFAULT}
    if [ "$use_compose" = true ]; then
      start_compose
      wait_for_selenium || true
    fi
    run_tests
    ;;

  watch)
    # visible browser, leave container running
    : ${HEADLESS:=false}
    : ${SLOW_MS:=200}
    if [ "$use_compose" = true ]; then
      start_compose
      wait_for_selenium || true
    fi
    run_tests
    echo "Tests finished. Selenium container left running for inspection."
    echo "Open noVNC at http://localhost:7900 or connect a VNC client to localhost:5900 to watch the browser."
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    echo "Unknown command: $command"
    usage
    exit 2
    ;;
esac
