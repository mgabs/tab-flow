import XCTest

final class ProFeatureTests: XCTestCase {
    func testAllProFeaturesAreAvailableAndAttemptUseReturnsTrue() {
        let features: [ProFeature] = [
            .appIconsAndTitlesStyle,
            .autoSize,
            .searchOnReleaseShortcut,
            .extraShortcut(index: 1),
            .searchInSwitcher,
        ]
        for feature in features {
            XCTAssertTrue(feature.isAvailable, "Feature \(feature) should be available")
            XCTAssertFalse(feature.isLocked, "Feature \(feature) should not be locked")
            XCTAssertTrue(feature.attemptUse(), "feature.attemptUse() should return true for \(feature)")
        }
    }
}
