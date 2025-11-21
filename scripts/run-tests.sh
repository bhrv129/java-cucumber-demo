#!/usr/bin/env bash
set -euo pipefail

# Simple helper to start the Selenium container and run tests.
# Usage:
#  ./scripts/run-tests.sh run   - bring up selenium (if needed), wait, run mvn test, keep container running
#  ./scripts/run-tests.sh up    - start selenium only
#  ./scripts/run-tests.sh down  - stop selenium
# Environment variables:
#  SELENIUM_REMOTE_URL - URL of remote Selenium (default: http://localhost:4444)
#  HEADLESS            - true/false (default: true)
#  SLOW_MS             - ms per character when typing (default: 0)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

HEADLESS=${HEADLESS:-true}
SLOW_MS=${SLOW_MS:-0}
SELENIUM_REMOTE_URL=${SELENIUM_REMOTE_URL:-http://localhost:4444}

ACTION=${1:-run}

case "$ACTION" in
  up)
    docker-compose up -d
    ;;

  down)
    docker-compose down
    ;;

  run)
    docker-compose up -d
    echo "Waiting for Selenium to be ready at $SELENIUM_REMOTE_URL..."
    # wait for /status endpoint
    for i in {1..60}; do
      if curl -sSf "$SELENIUM_REMOTE_URL/status" >/dev/null 2>&1; then
        echo "Selenium is ready"
        break
      fi
      sleep 1
    done

    echo "Running tests (SELENIUM_REMOTE_URL=$SELENIUM_REMOTE_URL, HEADLESS=$HEADLESS, SLOW_MS=$SLOW_MS)"
    export SELENIUM_REMOTE_URL
    export HEADLESS
    export SLOW_MS
    mvn test
    ;;

  *)
    echo "Usage: $0 [run|up|down]"
    exit 2
    ;;
esac
