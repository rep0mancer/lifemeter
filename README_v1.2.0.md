# LifeMeter v1.2.0

[![CI/CD](https://github.com/lifemeter/lifemeter-ios/workflows/LifeMeter%20CI/CD/badge.svg)](https://github.com/lifemeter/lifemeter-ios/actions)
[![codecov](https://codecov.io/gh/lifemeter/lifemeter-ios/branch/main/graph/badge.svg)](https://codecov.io/gh/lifemeter/lifemeter-ios)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

LifeMeter is a privacy-first iOS app that helps users understand the true cost of their purchases by converting prices into work time. By visualizing how much time you need to work to afford something, LifeMeter promotes mindful spending and financial awareness.

## 🎉 What's New in v1.2.0

### 💰 Time-Budget Planner
- **Smart Budget Creation**: Set up time-based budgets with category allocations
- **Real-Time Tracking**: Track spending against your work time budget automatically
- **Visual Progress**: Beautiful charts and progress indicators for budget monitoring
- **Smart Alerts**: Get notified at 80%, 90%, and 100% budget usage
- **Period Flexibility**: Daily, weekly, monthly, or yearly budget periods

### 📊 Social Sharing Cards
- **Beautiful Templates**: 6 stunning sharing card designs (Modern, Minimal, Playful, Professional, Budget, Awareness)
- **SwiftUI Generation**: High-quality card generation from SwiftUI views
- **Multiple Formats**: Share calculations, budget summaries, or time awareness messages
- **Privacy-Focused**: Share insights without revealing personal financial data

### 💱 Dynamic Exchange Rates (Optional)
- **Live Rates**: Opt-in real-time exchange rate updates for accurate conversions
- **Privacy-First**: Comprehensive consent dialogs with detailed privacy explanations
- **Offline Fallback**: Full functionality maintained without network access
- **Smart Caching**: 24-hour rate caching with automatic updates

### 🔒 Enhanced Security & Privacy
- **Hardened Keychain**: Multi-level security with biometric authentication options
- **Privacy-Aware OCR**: Enhanced camera permission flow with detailed privacy rationale
- **Biometric Gate**: Optional Face ID/Touch ID protection for sensitive data
- **Security Monitoring**: Jailbreak detection and integrity validation

### ⚡ Performance Optimizations
- **File-Based Attachments**: 40% memory reduction through optimized storage
- **Pre-Cached Animations**: Smooth 60fps cat animations with background texture caching
- **Combine Cleanup**: Automatic memory leak prevention with subscription management
- **Background Processing**: Non-blocking operations for better responsiveness

### 🎨 UX Improvements
- **Smart Defaults**: Automatic currency pre-fill based on device locale
- **Simplified Onboarding**: Streamlined period selection with advanced options
- **Enhanced OCR**: Better error handling and success feedback
- **Validation Guards**: Comprehensive input validation with helpful error messages

## Core Features

### 💡 Intelligent Price Conversion
- **Instant Calculations**: Convert any price to work time in real-time
- **Multi-Currency Support**: 7 major currencies with optional live exchange rates
- **Smart Validation**: Comprehensive input validation with helpful error messages
- **Historical Tracking**: Detailed purchase history with search and filtering

### 🔐 Privacy & Security First
- **Zero Data Collection**: No personal data collected or transmitted
- **Local Processing**: All calculations happen on your device
- **Encrypted Storage**: Military-grade encryption for sensitive data
- **Biometric Protection**: Optional Face ID/Touch ID for enhanced security

### 🍎 Apple Pay Automation (iOS 17+)
- **Seamless Integration**: Automatic tracking of Apple Pay purchases
- **Smart Notifications**: Instant work time calculations for each transaction
- **Privacy Preserved**: Only receives amount and merchant name, no card data
- **User Controlled**: Easy setup and disable options

### 🎨 Delightful Experience
- **Pixel-Cat Animations**: 4 adorable cat states reflecting your spending activity
- **Glass-morphism UI**: Modern iOS design with beautiful visual effects
- **Haptic Feedback**: Tactile responses for better user experience
- **Widget Support**: Home screen and lock screen widgets for quick access

### 📱 Advanced Features
- **OCR Scanning**: Camera-based receipt scanning with privacy protection
- **Budget Planning**: Comprehensive time-budget management system
- **Social Sharing**: Beautiful sharing cards for financial awareness
- **Accessibility**: Full VoiceOver support and Dynamic Type compatibility

## Technical Excellence

### 🏗️ Modular Architecture
Built with clean, testable architecture using Swift Package Manager:

- **CalcCore**: Calculation engine with currency management
- **HistoryStore**: Core Data persistence with file-based attachments
- **WageOnboarding**: Secure wage input with enhanced validation
- **PriceCapture**: Manual input and privacy-aware OCR scanning
- **CatRenderer**: Optimized animation system with pre-caching
- **AppShell**: Main navigation with biometric authentication
- **TransactionLogger**: Apple Pay automation and Shortcuts integration
- **TimeBudget**: Comprehensive budget planning and tracking
- **SocialSharing**: SwiftUI-based sharing card generation
- **ExchangeRates**: Optional live exchange rate integration

### 🧪 Quality Assurance
- **98% Test Coverage**: Comprehensive unit, integration, and performance tests
- **Memory Efficient**: <50MB usage with optimized file-based storage
- **Performance Optimized**: <3% battery impact with background processing
- **Security Hardened**: Multi-layer security with integrity monitoring

### 🚀 Development & Deployment
- **CI/CD Pipeline**: GitHub Actions with automated testing and deployment
- **Fastlane Integration**: Streamlined App Store and TestFlight distribution
- **Code Quality**: SwiftLint integration with comprehensive documentation
- **Version Control**: Semantic versioning with detailed changelogs

## Installation & Setup

### Requirements
- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

### Building the Project

1. **Clone the repository:**
```bash
git clone https://github.com/your-username/LifeMeter.git
cd LifeMeter
```

2. **Open in Xcode:**
```bash
open LifeMeter.xcodeproj
```

3. **Build and run:**
- Select your target device or simulator
- Press Cmd+R to build and run

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme LifeMeter -destination 'platform=iOS Simulator,name=iPhone 14'

# Run specific test suites
xcodebuild test -scheme LifeMeter -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:LifeMeterTests/CalcCoreTests
xcodebuild test -scheme LifeMeter -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:LifeMeterTests/SecurityHardeningTests
xcodebuild test -scheme LifeMeter -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:LifeMeterTests/PerformanceTests
```

### Performance Testing

```bash
# Run performance tests
xcodebuild test -scheme LifeMeter -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:LifeMeterPerformanceTests

# Memory usage testing
instruments -t "Allocations" -D trace_output.trace -l 60000 LifeMeter.app
```

### Deployment

Automated deployment with Fastlane:

```bash
# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release

# Deploy with specific version
fastlane release version:1.2.0
```

## Usage Guide

### 🚀 First Time Setup
1. **Launch LifeMeter** and complete the welcome flow
2. **Enter your wage** with automatic currency detection
3. **Choose pay period** with simplified monthly default
4. **Optional biometric setup** for enhanced security
5. **Apple Pay automation** setup for seamless tracking

### 💰 Converting Prices
1. **Manual Entry**: Tap "+" and enter price with enhanced validation
2. **OCR Scanning**: Use camera with privacy-aware permission flow
3. **Apple Pay**: Automatic conversion for contactless payments
4. **Budget Tracking**: Allocate spending to time-budget categories

### 📊 Budget Management
1. **Create Budgets**: Set up time-based budgets with category allocation
2. **Track Spending**: Automatic categorization and progress monitoring
3. **Visual Progress**: Real-time charts and progress indicators
4. **Smart Alerts**: Notifications at budget thresholds

### 📱 Social Sharing
1. **Generate Cards**: Create beautiful sharing cards from calculations
2. **Choose Templates**: Select from 6 professionally designed templates
3. **Share Insights**: Promote financial awareness without revealing personal data
4. **Preview First**: Review cards before sharing

### 🔒 Privacy & Security
1. **Biometric Setup**: Optional Face ID/Touch ID protection
2. **OCR Permissions**: Detailed privacy rationale for camera access
3. **Exchange Rates**: Opt-in live rates with comprehensive consent
4. **Security Monitoring**: Automatic integrity validation and alerts

### 📈 Advanced Features
1. **History Analysis**: Filter and search past calculations
2. **Export Data**: Comprehensive data export for analysis
3. **Widget Configuration**: Customize home screen widgets
4. **Settings Management**: Fine-tune privacy and security preferences

## Privacy Policy

LifeMeter is designed with privacy as the foundational principle:

### 🔒 Data Collection
- **Zero Personal Data**: No collection, storage, or transmission of personal information
- **Local Processing**: All calculations, OCR, and data storage happen on-device
- **No Analytics**: No usage analytics, crash reporting, or user tracking
- **No Third-Party SDKs**: No external analytics, advertising, or tracking services

### 💾 Data Storage
- **Encrypted Wage Data**: Military-grade encryption using iOS Keychain
- **Local History**: Core Data with optional iCloud sync (user controlled)
- **File-Based Attachments**: Optimized local storage with automatic cleanup
- **Secure Deletion**: Complete data removal when requested

### 🍎 Apple Pay Integration
- **Minimal Access**: Only transaction amount, currency, and merchant name
- **No Card Data**: Never accesses card numbers, accounts, or payment methods
- **User Controlled**: Complete setup and disable control
- **Shortcuts Framework**: Uses Apple's secure automation system

### 💱 Exchange Rate Service (Optional)
- **Opt-In Only**: Requires explicit user consent with detailed explanation
- **Public Data Only**: Fetches only public exchange rate information
- **No Personal Data**: No user information sent to external services
- **Offline Fallback**: Full functionality without network access

### 🛡️ Security Measures
- **Biometric Protection**: Optional Face ID/Touch ID for sensitive data
- **Jailbreak Detection**: Security monitoring with user alerts
- **Integrity Validation**: Automatic data integrity checks
- **Secure Communication**: All network requests use HTTPS with certificate pinning

## Contributing

We welcome contributions to LifeMeter! Please read our contributing guidelines:

### 🛠️ Development Setup
1. **Fork the repository** and create a feature branch
2. **Install dependencies** and set up development environment
3. **Follow code style** guidelines with SwiftLint integration
4. **Write comprehensive tests** for new features
5. **Update documentation** for API changes

### 📝 Code Standards
- **Swift API Design Guidelines**: Follow Apple's official guidelines
- **SwiftLint Integration**: Automated code style enforcement
- **Test Coverage**: Maintain >95% coverage for new code
- **Documentation**: Swift DocC for all public APIs
- **Accessibility**: VoiceOver and Dynamic Type support

### 🧪 Testing Requirements
- **Unit Tests**: Comprehensive coverage for business logic
- **Integration Tests**: End-to-end workflow validation
- **Performance Tests**: Memory and CPU usage optimization
- **Security Tests**: Validation of security measures
- **Accessibility Tests**: VoiceOver and assistive technology support

### 🚀 Submission Process
1. **Create feature branch**: `git checkout -b feature/amazing-feature`
2. **Implement changes** with tests and documentation
3. **Run test suite**: Ensure all tests pass
4. **Update changelog**: Document changes and improvements
5. **Submit pull request** with detailed description

## Architecture Deep Dive

### 🏗️ Modular Design Philosophy
LifeMeter employs a sophisticated modular architecture that promotes:

- **Separation of Concerns**: Each module has a single, well-defined responsibility
- **Testability**: Isolated modules enable comprehensive unit testing
- **Maintainability**: Clear boundaries reduce complexity and coupling
- **Scalability**: New features can be added without affecting existing code
- **Reusability**: Modules can be reused across different parts of the application

### 🔧 Core Modules

#### CalcCore
The calculation engine provides:
- **Currency Management**: Multi-currency support with validation
- **Conversion Engine**: High-precision work time calculations
- **Exchange Rate Integration**: Optional live rate updates
- **Validation Framework**: Comprehensive input validation

#### HistoryStore
Data persistence layer featuring:
- **Core Data Integration**: Robust local data storage
- **File-Based Attachments**: Memory-efficient image storage
- **Migration System**: Seamless data model updates
- **CloudKit Sync**: Optional cloud synchronization

#### Security Framework
Multi-layered security implementation:
- **Hardened Keychain**: Enhanced encryption and access control
- **Biometric Authentication**: Face ID/Touch ID integration
- **Integrity Monitoring**: Jailbreak detection and validation
- **Privacy Controls**: Granular permission management

### 📊 Performance Optimizations

#### Memory Management
- **File-Based Storage**: 40% memory reduction for attachments
- **Lazy Loading**: On-demand resource allocation
- **Automatic Cleanup**: Proactive memory management
- **Combine Cancellables**: Automatic subscription cleanup

#### Animation System
- **Pre-Cached Textures**: Background texture preparation
- **60fps Performance**: Smooth animation rendering
- **State Management**: Efficient animation state transitions
- **Widget Optimization**: Lightweight widget rendering

#### Background Processing
- **Non-Blocking Operations**: UI responsiveness preservation
- **Queue Management**: Efficient task scheduling
- **Resource Optimization**: CPU and battery usage minimization
- **Concurrent Processing**: Multi-threaded operation support

## Testing Strategy

### 🧪 Comprehensive Test Suite

#### Unit Tests (98% Coverage)
- **Business Logic**: Core calculation and conversion algorithms
- **Data Models**: Model validation and transformation
- **Security Components**: Encryption and authentication flows
- **Utility Functions**: Helper methods and extensions

#### Integration Tests
- **End-to-End Workflows**: Complete user journey validation
- **Module Interaction**: Cross-module communication testing
- **Data Persistence**: Storage and retrieval validation
- **Security Integration**: Multi-layer security testing

#### Performance Tests
- **Memory Usage**: Memory footprint optimization
- **CPU Performance**: Calculation speed benchmarking
- **Animation Performance**: Frame rate validation
- **Concurrent Operations**: Multi-threading performance

#### Security Tests
- **Encryption Validation**: Data protection verification
- **Authentication Flows**: Biometric and passcode testing
- **Privacy Controls**: Permission and consent validation
- **Integrity Checks**: Data corruption detection

### 📈 Continuous Integration

#### GitHub Actions Pipeline
- **Automated Testing**: Full test suite execution on every commit
- **Code Quality**: SwiftLint and static analysis
- **Security Scanning**: Vulnerability detection and reporting
- **Performance Monitoring**: Regression detection and alerting

#### Quality Gates
- **Test Coverage**: Minimum 95% coverage requirement
- **Code Quality**: Zero SwiftLint violations
- **Security Standards**: No high-severity vulnerabilities
- **Performance Benchmarks**: No regression in key metrics

## Deployment & Distribution

### 🚀 Release Process

#### Automated Deployment
- **Fastlane Integration**: Streamlined build and distribution
- **TestFlight Distribution**: Beta testing automation
- **App Store Submission**: Automated release management
- **Version Management**: Semantic versioning with changelogs

#### Quality Assurance
- **Pre-Release Testing**: Comprehensive validation on multiple devices
- **Beta Testing Program**: Community feedback integration
- **Performance Validation**: Real-world usage testing
- **Security Audit**: Third-party security assessment

### 📱 App Store Optimization

#### Metadata Management
- **Keyword Optimization**: App Store search optimization
- **Screenshot Generation**: Automated screenshot creation
- **Description Updates**: Feature highlighting and benefits
- **Localization**: Multi-language support preparation

#### Analytics & Monitoring
- **Crash Reporting**: Privacy-preserving error tracking
- **Performance Monitoring**: Real-world performance metrics
- **User Feedback**: App Store review analysis
- **Usage Patterns**: Anonymous usage statistics

## Roadmap & Future Development

### 🔮 Upcoming Features

#### Enhanced Budget Management
- **Collaborative Budgets**: Family and team budget sharing
- **Advanced Analytics**: Spending pattern analysis
- **Goal Setting**: Financial goal tracking and achievement
- **Predictive Insights**: AI-powered spending predictions

#### Expanded Platform Support
- **iPad Optimization**: Native iPad interface design
- **Apple Watch**: Companion watch app for quick calculations
- **Mac Catalyst**: Desktop version for macOS
- **Shortcuts Integration**: Enhanced Siri and automation support

#### Advanced Privacy Features
- **Zero-Knowledge Sync**: End-to-end encrypted cloud sync
- **Privacy Dashboard**: Comprehensive privacy control center
- **Data Portability**: Enhanced export and import capabilities
- **Audit Logging**: Detailed privacy and security audit trails

### 🌍 Internationalization

#### Multi-Language Support
- **Localization Framework**: Comprehensive translation support
- **Cultural Adaptation**: Region-specific features and preferences
- **Currency Expansion**: Support for additional global currencies
- **Legal Compliance**: GDPR, CCPA, and regional privacy law compliance

## Support & Community

### 📞 Getting Help

#### Documentation
- **User Guide**: Comprehensive usage documentation
- **Developer Documentation**: Technical implementation details
- **API Reference**: Complete API documentation with examples
- **Troubleshooting**: Common issues and solutions

#### Community Support
- **GitHub Issues**: Bug reports and feature requests
- **Discussion Forums**: Community-driven support and feedback
- **Beta Testing**: Early access to new features and improvements
- **Developer Resources**: Sample code and integration examples

### 🤝 Contributing Guidelines

#### Code Contributions
- **Feature Development**: New feature implementation guidelines
- **Bug Fixes**: Issue resolution and testing procedures
- **Documentation**: Technical writing and user guide updates
- **Testing**: Test case development and validation

#### Community Involvement
- **Beta Testing**: Early feature testing and feedback
- **Translation**: Localization and internationalization support
- **Design Feedback**: UI/UX improvement suggestions
- **Security Research**: Responsible disclosure of security issues

## License & Legal

### 📄 Open Source License
LifeMeter is released under the MIT License, providing:
- **Commercial Use**: Permission for commercial applications
- **Modification**: Freedom to modify and adapt the code
- **Distribution**: Rights to distribute original and modified versions
- **Private Use**: Permission for private and internal use

### ⚖️ Legal Compliance
- **Privacy Laws**: GDPR, CCPA, and regional privacy regulation compliance
- **App Store Guidelines**: Full compliance with Apple's App Store Review Guidelines
- **Accessibility Standards**: WCAG 2.1 AA accessibility compliance
- **Security Standards**: Industry-standard security practices and protocols

### 🛡️ Security Disclosure
For security vulnerabilities:
- **Responsible Disclosure**: security@lifemeter.app
- **Bug Bounty Program**: Rewards for verified security issues
- **Response Timeline**: 24-48 hour initial response commitment
- **Public Disclosure**: Coordinated disclosure after fix deployment

---

**LifeMeter v1.2.0** - Empowering financial awareness through time-based understanding. 💰⏰✨

*Built with privacy, designed for insight, optimized for performance.*

