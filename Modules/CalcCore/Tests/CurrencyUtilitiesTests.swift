@testable import CalcCore
import XCTest

// MARK: - Currency Utilities Tests

@available(iOS 15.0, *)
final class CurrencyUtilitiesTests: XCTestCase {
    // MARK: - Symbol Tests

    func testSymbolForCurrency_SupportedCurrencies_ReturnsCorrectSymbol() {
        XCTAssertEqual(CurrencyUtilities.symbol(for: "EUR"), "€")
        XCTAssertEqual(CurrencyUtilities.symbol(for: "USD"), "$")
        XCTAssertEqual(CurrencyUtilities.symbol(for: "GBP"), "£")
        XCTAssertEqual(CurrencyUtilities.symbol(for: "JPY"), "¥")
        XCTAssertEqual(CurrencyUtilities.symbol(for: "CHF"), "CHF")
        XCTAssertEqual(CurrencyUtilities.symbol(for: "CAD"), "C$")
        XCTAssertEqual(CurrencyUtilities.symbol(for: "AUD"), "A$")
    }

    func testSymbolForCurrency_UnsupportedCurrency_ReturnsIdentifier() {
        let unsupportedCurrency = "XYZ"
        let result = CurrencyUtilities.symbol(for: unsupportedCurrency)
        XCTAssertEqual(result, unsupportedCurrency)
    }

    // MARK: - Price Formatting Tests

    func testFormatPrice_EUR_ReturnsCorrectFormat() {
        let price = 12.99
        let currency = "EUR"
        let result = CurrencyUtilities.formatPrice(price, currency: currency)

        // Should contain the price and currency symbol
        XCTAssertTrue(result.contains("12.99") || result.contains("12,99"))
        XCTAssertTrue(result.contains("€"))
    }

    func testFormatPrice_USD_ReturnsCorrectFormat() {
        let price = 25.50
        let currency = "USD"
        let result = CurrencyUtilities.formatPrice(price, currency: currency)

        XCTAssertTrue(result.contains("25.50") || result.contains("25,50"))
        XCTAssertTrue(result.contains("$"))
    }

    func testFormatPrice_ZeroPrice_HandlesCorrectly() {
        let price = 0.0
        let currency = "EUR"
        let result = CurrencyUtilities.formatPrice(price, currency: currency)

        XCTAssertTrue(result.contains("0"))
        XCTAssertTrue(result.contains("€"))
    }

    // MARK: - Price Parsing Tests

    func testParsePrice_EuroSymbolBefore_ReturnsCorrectValues() {
        let text = "€12.99"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 12.99, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "EUR")
    }

    func testParsePrice_DollarSymbolBefore_ReturnsCorrectValues() {
        let text = "$25.50"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 25.50, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "USD")
    }

    func testParsePrice_PoundSymbolBefore_ReturnsCorrectValues() {
        let text = "£15.75"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 15.75, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "GBP")
    }

    func testParsePrice_YenSymbolBefore_ReturnsCorrectValues() {
        let text = "¥1500"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 1500.0, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "JPY")
    }

    func testParsePrice_CurrencyCodeAfter_ReturnsCorrectValues() {
        let text = "12.99 EUR"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 12.99, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "EUR")
    }

    func testParsePrice_USDCodeAfter_ReturnsCorrectValues() {
        let text = "25.50 USD"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 25.50, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "USD")
    }

    func testParsePrice_WithSpaces_HandlesCorrectly() {
        let text = "€ 12.99"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 12.99, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "EUR")
    }

    func testParsePrice_WithCommaDecimalSeparator_HandlesCorrectly() {
        let text = "€12,99"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 12.99, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "EUR")
    }

    func testParsePrice_WithThousandsSeparator_HandlesCorrectly() {
        let text = "$1,234.56"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 1234.56, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "USD")
    }

    func testParsePrice_NoPrice_ReturnsNil() {
        let text = "No price here"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNil(result)
    }

    func testParsePrice_EmptyString_ReturnsNil() {
        let text = ""
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNil(result)
    }

    func testParsePrice_OnlySymbol_ReturnsNil() {
        let text = "€"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNil(result)
    }

    func testParsePrice_OnlyCurrencyCode_ReturnsNil() {
        let text = "EUR"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNil(result)
    }

    // MARK: - Complex Text Parsing Tests

    func testParsePrice_ReceiptText_FindsFirstPrice() {
        let receiptText = """
        Store Name
        Item 1          €5.99
        Item 2          €12.50
        Total           €18.49
        """

        let result = CurrencyUtilities.parsePrice(from: receiptText)

        XCTAssertNotNil(result)
        // Should find the first price
        XCTAssertEqual(result?.price, 5.99, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "EUR")
    }

    func testParsePrice_MixedCurrencies_FindsFirst() {
        let text = "Price: $25.00 or €22.50"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 25.00, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "USD")
    }

    func testParsePrice_WithNoise_FindsPrice() {
        let text = "The total amount is €45.67 including tax"
        let result = CurrencyUtilities.parsePrice(from: text)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.price, 45.67, accuracy: 0.01)
        XCTAssertEqual(result?.currency, "EUR")
    }

    // MARK: - Supported Currencies Tests

    func testSupportedCurrencies_ContainsExpectedCurrencies() {
        let supportedCurrencies = CurrencyUtilities.supportedCurrencies

        XCTAssertTrue(supportedCurrencies.keys.contains("EUR"))
        XCTAssertTrue(supportedCurrencies.keys.contains("USD"))
        XCTAssertTrue(supportedCurrencies.keys.contains("GBP"))
        XCTAssertTrue(supportedCurrencies.keys.contains("JPY"))
        XCTAssertTrue(supportedCurrencies.keys.contains("CHF"))
        XCTAssertTrue(supportedCurrencies.keys.contains("CAD"))
        XCTAssertTrue(supportedCurrencies.keys.contains("AUD"))
    }

    func testSupportedCurrencies_HasCorrectSymbols() {
        let supportedCurrencies = CurrencyUtilities.supportedCurrencies

        XCTAssertEqual(supportedCurrencies["EUR"], "€")
        XCTAssertEqual(supportedCurrencies["USD"], "$")
        XCTAssertEqual(supportedCurrencies["GBP"], "£")
        XCTAssertEqual(supportedCurrencies["JPY"], "¥")
        XCTAssertEqual(supportedCurrencies["CHF"], "CHF")
        XCTAssertEqual(supportedCurrencies["CAD"], "C$")
        XCTAssertEqual(supportedCurrencies["AUD"], "A$")
    }
}
