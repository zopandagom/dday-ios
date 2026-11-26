import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
  infoPlist: [
    "CFBundleDisplayName": "디데이",
  ],
  dependencies: [
    .feature(.home),
    .shared(.core),
  ]
)
