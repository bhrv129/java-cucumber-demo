#!/usr/bin/env bash
set -euo pipefail

# Start Selenium (if needed), run tests with visible browser, and KEEP the container running
# Usage: ./scripts/run-tests-watch.sh [start|run|stop]
#  start - start selenium only
#  run   - start selenium (if needed), wait, run tests (HEADLESS=false by default), leave container running
#  stop  - stop the selenium container

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

NAME=selenium-chrome
IMAGE=selenium/standalone-chrome:latest
SELENIUM_URL=${SELENIUM_REMOTE_URL:-http://localhost:4444}
HEADLESS=${HEADLESS:-false}
SLOW_MS=${SLOW_MS:-200}

cmd=${1:-run}

function start_container() {
  if docker ps --filter "name=^/${NAME}$" --format '{{.Names}}' | grep -q "${NAME}"; then
    echo "Container ${NAME} already running"
  else
    echo "Starting ${NAME}..."
    docker run -d --rm --name ${NAME} -p 4444:4444 -p 7900:7900 -p 5900:5900 --shm-size=2g ${IMAGE}
  fi
}

function wait_ready() {
  echo "Waiting for Selenium at ${SELENIUM_URL}..."
  for i in {1..60}; do
    if curl -sSf "${SELENIUM_URL}/status" >/dev/null 2>&1; then
      echo "Selenium is ready"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for Selenium"
  return 1
}

case "$cmd" in
  start)
    start_container
    ;;

  run)
    start_container
    wait_ready
    echo "Running tests with SELENIUM_REMOTE_URL=${SELENIUM_URL} HEADLESS=${HEADLESS} SLOW_MS=${SLOW_MS}"
    export SELENIUM_REMOTE_URL=${SELENIUM_URL}
    export HEADLESS
    export SLOW_MS
    mvn test
    echo "Tests finished. Selenium container left running as '${NAME}'."
    echo "Open noVNC at http://localhost:7900 or connect a VNC client to localhost:5900 to watch the browser." 
    ;;

  stop)
    echo "Stopping ${NAME}..."
    docker rm -f ${NAME} || true
    ;;

  *)
    echo "Usage: $0 [start|run|stop]"
    exit 2
    ;;
esac
