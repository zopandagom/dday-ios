import Core
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

  @Test("폴더 색 배경(미분류는 기본 배경) 에셋이 Feature 번들에 있다 (3:2)", arguments: [nil] + FolderColor.allCases.map(Optional.some))
  func cardBackgroundIsInBundle(color: FolderColor?) throws {
    let image = try #require(UIImage(
      named: HomeAsset.cardBackground(for: color),
      in: HomeFeatureResources.bundle,
      with: nil
    ))
    #expect(image.size.width > 0)
    #expect(image.size.width == image.size.height * 1.5)
  }

  @Test("미분류는 기본 배경 이름이고 폴더 색 배경 이름 5개는 서로 다르다")
  func cardBackgroundNames() {
    #expect(HomeAsset.cardBackground(for: nil) == HomeAsset.defaultCardBackground)
    let names = FolderColor.allCases.map { HomeAsset.cardBackground(for: $0) }
    #expect(Set(names).count == FolderColor.allCases.count)
    #expect(!names.contains(HomeAsset.defaultCardBackground))
  }
}
