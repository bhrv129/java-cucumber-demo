## java-cucumber-demo

A minimal demo that runs a Cucumber (Gherkin) scenario using Java, Maven, and Selenium.

## Test case and Gherkin → Java mapping

### What the test does
- The single feature in this repo is `src/test/resources/features/search_google.feature`.
- Scenario: "Search for a term in Google" — it opens Google, types a query (`Cucumber Java`), submits the search, and verifies the results page contains the expected text (`Cucumber`).

Feature snippet (from `search_google.feature`):

```gherkin
Feature: Google Search

	Scenario: Search for a term in Google
		Given I am on the Google homepage
		When I search for "Cucumber Java"
		Then the results page should contain "Cucumber"
```

### How Gherkin maps to Java here
- Runner: `src/test/java/runner/RunCucumberTest.java` boots Cucumber for JUnit and points Cucumber at the `features` folder and the `steps` package (`glue = {"steps"}`).
- Step definitions: `src/test/java/steps/GoogleSearchSteps.java` contains the Java methods annotated with `@Given`, `@When`, and `@Then` that implement the Gherkin steps.

Mapping examples
- The Gherkin step `Given I am on the Google homepage` maps to the Java method:

```java
@Given("I am on the Google homepage")
public void i_am_on_the_google_homepage() { ... }
```

- The Gherkin step `When I search for "Cucumber Java"` maps to:

```java
@When("I search for {string}")
public void i_search_for(String query) { ... }
```

- The Gherkin step `Then the results page should contain "Cucumber"` maps to:

```java
@Then("the results page should contain {string}")
public void the_results_page_should_contain(String expected) { ... }
```

### How the Java step code works (summary)
- `i_am_on_the_google_homepage()`
	- Uses `WebDriverManager.chromedriver().setup()` to ensure a matching ChromeDriver is available.
	- Builds `ChromeOptions` and respects the `HEADLESS` env var and an optional `CHROME_BINARY` path.
	- If `SELENIUM_REMOTE_URL` is set it creates a `RemoteWebDriver` pointing at that URL (used with the Selenium Docker image); otherwise it starts a local `ChromeDriver`.
	- Navigates to `https://www.google.com`.

- `i_search_for(String query)`
	- Locates the search box (`By.name("q")`), types the query and submits it.
	- Supports a demo-friendly typing delay via `SLOW_MS` env var (milliseconds per character).

- `the_results_page_should_contain(String expected)`
	- Uses a simple wait (brief `Thread.sleep`) then asserts the page source contains the expected text. (We recommend replacing this with explicit waits for robustness.)

- `@After tearDown()` closes `driver.quit()`.

### Files to inspect
- Feature: `src/test/resources/features/search_google.feature`
- Steps: `src/test/java/steps/GoogleSearchSteps.java`
- Runner: `src/test/java/runner/RunCucumberTest.java`


## How run tests
Project status
- Compiles with Java 21 (project updated to target Java 21).
- Tests use Cucumber + Selenium and `WebDriverManager` to obtain a matching ChromeDriver.

Prerequisites
- Java 21 and Maven installed locally to build the project (or use the dev container).
- Docker and Docker Compose (for running the Selenium Standalone Chrome service).

Recommended (single) workflow

This repository provides a single, supported helper script: `./scripts/run-tests.sh`.
It manages a Selenium container (via `docker-compose.yml`) and runs `mvn test` against it.

Basic usage

Make the script executable and run tests (headless by default):

```bash
chmod +x ./scripts/run-tests.sh
./scripts/run-tests.sh run
```

Watch tests in a visible browser

To run with a visible browser and leave the Selenium container running for inspection:

```bash
HEADLESS=false SLOW_MS=200 ./scripts/run-tests.sh watch
# Open noVNC at http://localhost:7900 or connect VNC to localhost:5900
```

Start/stop the Selenium service manually

```bash
./scripts/run-tests.sh up    # start Selenium via docker-compose
./scripts/run-tests.sh down  # stop Selenium
```

Record a test run (best-effort)

The script can attempt to record the browser session and copy the file to `./test_record.mp4`. Recording is best-effort and may fail depending on the container image and environment.

```bash
RECORD=true HEADLESS=false SLOW_MS=200 ./scripts/run-tests.sh run
```
