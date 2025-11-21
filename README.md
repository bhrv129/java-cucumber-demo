# java-cucumber-demo

java-cucumber-demo project

This project is a minimal demo showing how to run a Cucumber (Gherkin) scenario with Java and Selenium.

Quick start

- Ensure you have Java 11+ and Maven installed.
- Tests use `WebDriverManager` to download ChromeDriver automatically. You need Google Chrome installed in the environment.

Run tests (quick options)

- Run against a local Chrome installation (fastest if you have Chrome on the host):

```bash
# (optional) point to your chrome binary if it's not on PATH
export CHROME_BINARY=/usr/bin/google-chrome-stable
mvn test
```

- Run against a Selenium Chrome Docker container (recommended for reproducible CI/containers):

```bash
# start the Selenium standalone Chrome container (includes a matching browser + driver)
docker run -d --rm --name selenium-chrome -p 4444:4444 --shm-size=2g selenium/standalone-chrome:latest

# point tests at the remote Selenium server and run (the test code detects SELENIUM_REMOTE_URL)
export SELENIUM_REMOTE_URL=http://localhost:4444
mvn test

# when finished, stop the container
docker rm -f selenium-chrome
```

Tips for observing the browser interactively

- Run the Selenium container with noVNC/VNC ports to view the browser UI in a web VNC client:

```bash
docker run -d --rm --name selenium-chrome -p 4444:4444 -p 7900:7900 -p 5900:5900 --shm-size=2g selenium/standalone-chrome:latest

# then run tests pointing to the remote server and disable headless and slow down typing for observation
export SELENIUM_REMOTE_URL=http://localhost:4444
export HEADLESS=false
export SLOW_MS=200
mvn test

# open http://localhost:7900 in your browser (or connect with a VNC client to port 5900)
```

Quick Docker commands (cleaned)

One-liner (quick):

```bash
docker run -d --rm --name selenium-chrome -p 4444:4444 --shm-size=2g selenium/standalone-chrome:latest && \
( for i in {1..60}; do curl -sSf http://localhost:4444/status >/dev/null 2>&1 && break || sleep 1; done ) && \
SELENIUM_REMOTE_URL=http://localhost:4444 HEADLESS=false SLOW_MS=200 mvn test; \
docker rm -f selenium-chrome || true
```

Readable sequence (recommended):

```bash
# stop any previous container
docker rm -f selenium-chrome || true

# start selenium (background)
docker run -d --rm --name selenium-chrome -p 4444:4444 --shm-size=2g selenium/standalone-chrome:latest

# wait for selenium to be ready (timeout ~60s)
echo "Waiting for Selenium..."
for i in {1..60}; do
	if curl -sSf http://localhost:4444/status >/dev/null 2>&1; then
		echo "Selenium ready"
		break
	fi
	sleep 1
done

# run tests (set env vars inline or export them)
export SELENIUM_REMOTE_URL=http://localhost:4444
export HEADLESS=false
export SLOW_MS=200
mvn test

# stop selenium when done
docker rm -f selenium-chrome || true
```

Helper script

You can also use the included helper script to start Selenium and run tests:

```bash
chmod +x ./scripts/run-tests.sh
./scripts/run-tests.sh run
```

Environment variables understood by the tests

- `SELENIUM_REMOTE_URL`: if set, tests will use `RemoteWebDriver` against this URL (useful with Selenium containers).
- `CHROME_BINARY`: optional path to a Chrome/Chromium binary to use when running a local driver.
- `HEADLESS`: set to `false` to run a visible browser; default is headless mode when not set.
- `SLOW_MS`: integer milliseconds per character to simulate slow typing when entering search text (useful for demos).

Troubleshooting

- If Chrome fails to start in a minimal container (errors like `DevToolsActivePort file doesn't exist`), use the Selenium Docker image as shown above — it bundles a compatible Chrome and driver and is the most reliable option for containers.
- For CI, add `--shm-size=2g` to the container to avoid crashes caused by small shared memory.

Files created

- `pom.xml` - project dependencies (Cucumber, Selenium, WebDriverManager)
- `src/test/resources/features/search_google.feature` - Gherkin feature
- `src/test/java/steps/GoogleSearchSteps.java` - step definitions using Selenium
- `src/test/java/runner/RunCucumberTest.java` - JUnit runner to run Cucumber

Notes

- If running in a CI or container without a display, configure Chrome for headless mode by modifying `GoogleSearchSteps` to pass `--headless=new` (or relevant flag) to `ChromeOptions`.
- The code uses a simple `Thread.sleep` to wait for results; for production-grade tests replace with explicit waits (WebDriver `WebDriverWait`).
# java-cucumber-demo
java-cucumber-demo project
