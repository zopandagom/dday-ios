import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
  infoPlist: [
    "CFBundleDisplayName": "디데이",
  ],
  dependencies: [
    .feature(.home),
    .feature(.dDayEditor),
    .feature(.folderManager),
    .feature(.reminder),
    .client(interface: .dDayStore),
    .client(impl: .dDayStore),
    .client(interface: .photo),
    .client(impl: .photo),
    .client(interface: .localNotification),
    .client(impl: .localNotification),
    .shared(.core),
  ]
)
