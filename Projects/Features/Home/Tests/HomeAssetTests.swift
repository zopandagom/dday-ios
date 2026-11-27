import Testing
import UIKit
@testable import HomeFeature

struct HomeAssetTests {
  @Test("기본 배경 에셋이 Feature 번들에 있다 (3:2)")
  func defaultCardBackgroundIsInBundle() throws {
    let image = try #require(UIImage(
      named: HomeAsset.defaultCardBackground,
      in: HomeFeatureResources.bundle,
      with: nil
    ))
    #expect(image.size.width > 0)
    #expect(image.size.width == image.size.height * 1.5)
  }
}
