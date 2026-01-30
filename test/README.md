# Mobile Nebula Test Suite

This directory contains automated tests for the Mobile Nebula application, with a focus on testing the UI modernization changes introduced in PR #323.

## Test Structure

```
test/
├── components/          # Widget tests for UI components
│   └── site_item_test.dart
├── screens/            # Screen-level widget tests
│   └── settings_screen_test.dart
├── services/           # Service and utility tests
│   ├── theme_test.dart
│   └── utils_test.dart
├── models/             # Model tests (reserved for future use)
├── test_helpers.dart   # Shared test utilities and mocks
└── README.md          # This file
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/components/site_item_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### View Coverage Report
```bash
# Install lcov if not already installed
brew install lcov  # macOS
# or
sudo apt-get install lcov  # Linux

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
# or
xdg-open coverage/html/index.html  # Linux
```

## Test Categories

### Component Tests (`test/components/`)

#### `site_item_test.dart`
Tests for the modernized SiteItem widget introduced in PR #323:
- ✅ Site name display
- ✅ Managed badge rendering and theming
- ✅ Connection status display
- ✅ Error state display with warning icon
- ✅ Switch state and enable/disable logic
- ✅ Details button interaction
- ✅ Typography and styling consistency

**Coverage:** SiteItem widget with all state combinations

### Screen Tests (`test/screens/`)

#### `settings_screen_test.dart`
Tests for SettingsScreen, particularly the debug functionality moved from MainScreen:
- ✅ All settings sections render correctly
- ✅ Dark mode toggle visibility based on system colors setting
- ✅ Debug buttons present in debug mode
- ✅ Debug site constants validation
- ✅ Switch interactions
- ✅ Navigation buttons

**Coverage:** SettingsScreen UI and debug functionality

### Service Tests (`test/services/`)

#### `utils_test.dart`
Tests for utility functions, especially the refactored `popError` method:
- ✅ `popError` dialog display
- ✅ Error message and title rendering
- ✅ Stack trace inclusion
- ✅ Dialog dismissal
- ✅ Multiple error dialogs
- ✅ `textSize` calculation
- ✅ `itemCountFormat` string formatting

**Coverage:** Utils class static methods

#### `theme_test.dart`
Tests for the new Material theme implementation:
- ✅ Light and dark theme generation
- ✅ Badge theme configuration (new in PR #323)
- ✅ Custom color application
- ✅ Medium and high contrast variants
- ✅ Text theme integration
- ✅ Theme consistency across variants

**Coverage:** MaterialTheme class and all theme variants

## Test Helpers

### `test_helpers.dart`

Provides shared utilities for writing tests:

#### `createTestApp(child: Widget)`
Creates a MaterialApp wrapper with proper theming for widget tests.

```dart
await tester.pumpWidget(
  createTestApp(
    child: SiteItem(site: site),
  ),
);
```

#### `createMockSite(...)`
Creates a mock Site instance for testing without platform channel setup.

```dart
final site = createMockSite(
  name: 'Test Site',
  connected: true,
  errors: [],
);
```

#### `MockSite` class
A Site subclass that doesn't initialize EventChannels, suitable for testing.

```dart
final site = createMockSite(name: 'Test');
site.simulateChange();  // Trigger onChange stream
site.simulateError('Test error');  // Trigger error
```

## Testing Best Practices

### 1. Widget Testing Pattern
```dart
testWidgets('description of what is being tested', (WidgetTester tester) async {
  // Arrange: Set up the widget
  await tester.pumpWidget(createTestApp(child: MyWidget()));
  
  // Act: Interact with the widget
  await tester.tap(find.text('Button'));
  await tester.pumpAndSettle();
  
  // Assert: Verify the outcome
  expect(find.text('Result'), findsOneWidget);
});
```

### 2. Using MockSite
```dart
testWidgets('handles site errors', (WidgetTester tester) async {
  final site = createMockSite(
    name: 'Error Site',
    errors: ['Certificate expired'],
  );
  
  await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));
  
  expect(find.text('Resolve errors'), findsOneWidget);
  expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
});
```

### 3. Testing Theme Integration
```dart
testWidgets('uses theme colors', (WidgetTester tester) async {
  await tester.pumpWidget(createTestApp(child: MyWidget()));
  
  final theme = Theme.of(tester.element(find.byType(MyWidget)));
  expect(theme.badgeTheme.backgroundColor, isNotNull);
});
```

## Known Limitations

### Platform Channel Mocking
Tests involving platform channels (e.g., site start/stop, file picker) are limited because:
- EventChannel setup is skipped in MockSite
- MethodChannel calls would need extensive mocking
- Integration tests would require a test harness

**Workaround:** We use MockSite to avoid EventChannel initialization and focus on UI behavior.

### Navigation Testing
Complex navigation flows are not fully tested because:
- Would require full app navigation stack
- Better suited for integration/E2E tests

**Current Coverage:** We verify navigation buttons exist and can be tapped.

### URL Launcher Testing
`Utils.launchUrl` tests are limited because:
- Requires mocking the url_launcher plugin
- Actual URL launching can't be tested in unit tests

**Current Coverage:** We verify the function exists and handles errors gracefully.

## Adding New Tests

### For New Components
1. Create test file in `test/components/[component_name]_test.dart`
2. Import `test_helpers.dart`
3. Use `createTestApp()` for widget wrapping
4. Use `createMockSite()` for Site dependencies

### For New Screens
1. Create test file in `test/screens/[screen_name]_test.dart`
2. Test all major UI sections render
3. Test interactive elements (buttons, switches)
4. Test navigation if applicable

### For New Services
1. Create test file in `test/services/[service_name]_test.dart`
2. Focus on business logic and edge cases
3. Mock external dependencies
4. Test error handling

## CI/CD Integration

These tests are designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: flutter test

- name: Generate coverage
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    files: coverage/lcov.info
```

## Future Improvements

### High Priority
- [ ] Add integration tests for site start/stop with platform channel mocking
- [ ] Add golden tests for visual regression testing
- [ ] Add tests for Site model state updates via EventChannel

### Medium Priority
- [ ] Add performance benchmarks for theme switching
- [ ] Add accessibility tests (contrast, screen readers)
- [ ] Add tests for form validation in SiteConfigScreen

### Low Priority
- [ ] Add E2E tests using integration_test package
- [ ] Add tests for certificate parsing and validation
- [ ] Add tests for static host map configuration

## Contributing

When adding new features or fixing bugs:

1. **Write tests first** (TDD approach preferred)
2. **Maintain >80% coverage** for new code
3. **Update this README** if adding new test categories
4. **Run all tests** before submitting PR: `flutter test`
5. **Check coverage** to ensure new code is tested

## Questions?

For questions about testing or to report issues with tests:
- Open an issue on GitHub
- Tag with `testing` label
- Include test file name and failure output
