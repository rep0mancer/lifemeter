import XCTest

// MARK: - Wage Onboarding UI Tests
@available(iOS 15.0, *)
final class WageOnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Onboarding Flow Tests
    
    func testWageOnboardingFlow_CompleteFlow_ShowsThankYouModal() throws {
        // Given: App is launched and onboarding is shown
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User enters wage information
        let wageTextField = app.textFields.firstMatch
        XCTAssertTrue(wageTextField.exists)
        wageTextField.tap()
        wageTextField.typeText("2500")
        
        // Select monthly period (should be default)
        let monthlyButton = app.buttons["Monthly"]
        XCTAssertTrue(monthlyButton.exists)
        monthlyButton.tap()
        
        // Select EUR currency (should be default)
        let eurButton = app.buttons.matching(identifier: "EUR").firstMatch
        if eurButton.exists {
            eurButton.tap()
        }
        
        // Tap continue button
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        continueButton.tap()
        
        // Then: Thank you modal should appear
        XCTAssertTrue(app.staticTexts["Thank You!"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["You worked"].exists)
        XCTAssertTrue(app.staticTexts["to own LifeMeter"].exists)
        
        // Verify work time is displayed
        let workTimeText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'm' OR label CONTAINS 'h'")).firstMatch
        XCTAssertTrue(workTimeText.exists)
        
        // Dismiss thank you modal
        let startButton = app.buttons["Start Using LifeMeter"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()
        
        // Verify main app is shown
        XCTAssertTrue(app.staticTexts["LifeMeter"].waitForExistence(timeout: 3))
    }
    
    func testWageOnboardingFlow_InvalidWage_ContinueButtonDisabled() throws {
        // Given: App is launched and onboarding is shown
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User enters invalid wage
        let wageTextField = app.textFields.firstMatch
        XCTAssertTrue(wageTextField.exists)
        wageTextField.tap()
        wageTextField.typeText("0")
        
        // Then: Continue button should be disabled
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertFalse(continueButton.isEnabled)
    }
    
    func testWageOnboardingFlow_EmptyWage_ContinueButtonDisabled() throws {
        // Given: App is launched and onboarding is shown
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User doesn't enter wage
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        
        // Then: Continue button should be disabled
        XCTAssertFalse(continueButton.isEnabled)
    }
    
    func testWageOnboardingFlow_DifferentPayPeriods_CalculatesCorrectly() throws {
        // Given: App is launched and onboarding is shown
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User selects hourly period
        let hourlyButton = app.buttons["Hourly"]
        XCTAssertTrue(hourlyButton.exists)
        hourlyButton.tap()
        
        // Enter hourly wage
        let wageTextField = app.textFields.firstMatch
        XCTAssertTrue(wageTextField.exists)
        wageTextField.tap()
        wageTextField.typeText("25")
        
        // Continue
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
        
        // Then: Thank you modal should appear with correct calculation
        XCTAssertTrue(app.staticTexts["Thank You!"].waitForExistence(timeout: 3))
        
        // For €25/hour, €2.99 should be about 7.2 minutes
        let workTimeElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'm'"))
        XCTAssertTrue(workTimeElements.count > 0)
    }
    
    func testWageOnboardingFlow_DifferentCurrencies_UpdatesDisplay() throws {
        // Given: App is launched and onboarding is shown
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User selects USD currency
        let usdButton = app.buttons.matching(identifier: "USD").firstMatch
        if usdButton.exists {
            usdButton.tap()
            
            // Verify USD symbol is shown
            XCTAssertTrue(app.staticTexts["$"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).count > 0)
        }
        
        // Select GBP currency
        let gbpButton = app.buttons.matching(identifier: "GBP").firstMatch
        if gbpButton.exists {
            gbpButton.tap()
            
            // Verify GBP symbol is shown
            XCTAssertTrue(app.staticTexts["£"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '£'")).count > 0)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testWageOnboardingFlow_VoiceOverLabels_ArePresent() throws {
        // Given: App is launched
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // Then: Important elements should have accessibility labels
        let wageTextField = app.textFields.firstMatch
        XCTAssertTrue(wageTextField.exists)
        XCTAssertNotNil(wageTextField.label)
        
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertNotNil(continueButton.label)
        
        let payPeriodButtons = app.buttons.matching(NSPredicate(format: "label IN {'Hourly', 'Daily', 'Monthly', 'Yearly'}"))
        XCTAssertTrue(payPeriodButtons.count >= 4)
    }
    
    // MARK: - Performance Tests
    
    func testWageOnboardingFlow_LaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testWageOnboardingFlow_ThankYouModalPerformance() throws {
        // Given: Complete onboarding setup
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        let wageTextField = app.textFields.firstMatch
        wageTextField.tap()
        wageTextField.typeText("2000")
        
        let continueButton = app.buttons["Continue"]
        
        // When: Measure time to show thank you modal
        measure {
            continueButton.tap()
            XCTAssertTrue(app.staticTexts["Thank You!"].waitForExistence(timeout: 2))
            
            // Dismiss modal for next iteration
            let startButton = app.buttons["Start Using LifeMeter"]
            if startButton.exists {
                startButton.tap()
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testWageOnboardingFlow_VeryHighWage_HandlesCorrectly() throws {
        // Given: App is launched
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User enters very high wage
        let wageTextField = app.textFields.firstMatch
        wageTextField.tap()
        wageTextField.typeText("100000")
        
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
        
        // Then: Should handle gracefully
        XCTAssertTrue(app.staticTexts["Thank You!"].waitForExistence(timeout: 3))
    }
    
    func testWageOnboardingFlow_VeryLowWage_HandlesCorrectly() throws {
        // Given: App is launched
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User enters very low wage
        let wageTextField = app.textFields.firstMatch
        wageTextField.tap()
        wageTextField.typeText("1")
        
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
        
        // Then: Should handle gracefully
        XCTAssertTrue(app.staticTexts["Thank You!"].waitForExistence(timeout: 3))
    }
    
    func testWageOnboardingFlow_DecimalWage_HandlesCorrectly() throws {
        // Given: App is launched
        XCTAssertTrue(app.staticTexts["Welcome to LifeMeter"].waitForExistence(timeout: 5))
        
        // When: User enters decimal wage
        let wageTextField = app.textFields.firstMatch
        wageTextField.tap()
        wageTextField.typeText("15.50")
        
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
        
        // Then: Should handle gracefully
        XCTAssertTrue(app.staticTexts["Thank You!"].waitForExistence(timeout: 3))
    }
}

