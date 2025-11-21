Feature: Google Search

  Scenario: Search for a term in Google
    Given I am on the Google homepage
    When I search for "Cucumber Java"
    Then the results page should contain "Cucumber"
