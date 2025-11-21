package steps;

import io.cucumber.java.After;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.remote.RemoteWebDriver;
import io.github.bonigarcia.wdm.WebDriverManager;

import static org.junit.Assert.assertTrue;

public class GoogleSearchSteps {
    private WebDriver driver;

    @Given("I am on the Google homepage")
    public void i_am_on_the_google_homepage() {
        WebDriverManager.chromedriver().setup();
        org.openqa.selenium.chrome.ChromeOptions options = new org.openqa.selenium.chrome.ChromeOptions();
        // Run in headless mode and add CI-friendly flags
        // Detect Chrome/Chromium binary: prefer CHROME_BINARY env var, fall back to common paths
        String chromeBinary = System.getenv("CHROME_BINARY");
        if (chromeBinary == null || chromeBinary.isBlank()) {
            String[] candidates = new String[]{
                    "/usr/bin/google-chrome-stable",
                    "/usr/bin/google-chrome",
                    "/usr/bin/chrome",
                    "/usr/bin/chromium-browser",
                    "/usr/bin/chromium"
            };
            for (String c : candidates) {
                java.io.File f = new java.io.File(c);
                if (f.exists() && f.canExecute()) {
                    chromeBinary = c;
                    break;
                }
            }
        }
        if (chromeBinary != null && !chromeBinary.isBlank()) {
            try {
                options.setBinary(chromeBinary);
                System.out.println("Using Chrome binary: " + chromeBinary);
            } catch (Exception e) {
                System.out.println("Failed to set Chrome binary: " + e.getMessage());
            }
        } else {
            System.out.println("No Chrome binary found in common paths; relying on driver-managed binary.");
        }
        // Respect HEADLESS env var; default to headless=true if not set
        String headlessEnv = System.getenv("HEADLESS");
        boolean headless = true;
        if (headlessEnv != null && (headlessEnv.equalsIgnoreCase("false") || headlessEnv.equals("0"))) {
            headless = false;
        }
        if (headless) {
            options.addArguments("--headless=new");
        }
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");
        options.addArguments("--disable-gpu");
        options.addArguments("--disable-software-rasterizer");
        options.addArguments("--window-size=1920,1080");
        options.addArguments("--remote-allow-origins=*");
        // If SELENIUM_REMOTE_URL is provided, use RemoteWebDriver (useful with Selenium Docker images)
        String remote = System.getenv("SELENIUM_REMOTE_URL");
        if (remote != null && !remote.isBlank()) {
            try {
                System.out.println("Using remote Selenium URL: " + remote);
                java.net.URL remoteUrl = new java.net.URL(remote);
                driver = new RemoteWebDriver(remoteUrl, options);
            } catch (Exception e) {
                System.out.println("Failed to connect to remote Selenium at " + remote + ": " + e.getMessage());
                driver = new ChromeDriver(options);
            }
        } else {
            driver = new ChromeDriver(options);
        }
        driver.get("https://www.google.com");
    }

    @When("I search for {string}")
    public void i_search_for(String query) {
        WebElement searchBox = driver.findElement(By.name("q"));
        // Support slow typing for observation using SLOW_MS env var (milliseconds per char)
        String slowMsEnv = System.getenv("SLOW_MS");
        int slowMs = 0;
        if (slowMsEnv != null) {
            try {
                slowMs = Integer.parseInt(slowMsEnv);
            } catch (NumberFormatException ignored) {
            }
        }
        if (slowMs > 0) {
            for (char c : query.toCharArray()) {
                searchBox.sendKeys(String.valueOf(c));
                try {
                    Thread.sleep(slowMs);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        } else {
            searchBox.sendKeys(query);
        }
        searchBox.submit();
    }

    @Then("the results page should contain {string}")
    public void the_results_page_should_contain(String expected) {
        // Wait briefly for results to load - simple approach
        try {
            Thread.sleep(1500);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        String pageSource = driver.getPageSource();
        assertTrue("Expected page to contain: " + expected, pageSource.contains(expected));
    }

    @After
    public void tearDown() {
        if (driver != null) {
            driver.quit();
        }
    }
}
