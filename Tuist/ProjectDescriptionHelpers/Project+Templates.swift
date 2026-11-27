import ProjectDescription

public enum Env {
  public static let appName = "DDay"
  public static let bundleIdPrefix = "com.zopandagom.dday"
  public static let destinations: Destinations = [.iPhone]
  public static let deploymentTargets: DeploymentTargets = .iOS("18.0")
  /// 앱 타깃(App·Example) Info.plist 에 공통으로 넣는 값.
  /// `CFBundleLocalizations`: 하위 리소스 번들(Feature 문구)의 언어가 메인 앱의 지원 언어를 따르므로 ko·en 을 선언한다.
  /// 없으면 하위 번들 언어가 메인 앱 developmentRegion 하나로 고정된다.
  /// `UISupportedInterfaceOrientations`: 세로 화면만 지원한다 (PRODUCT §2 "최소 지원").
  static let appInfoPlist: [String: Plist.Value] = [
    "UILaunchScreen": [:],
    "CFBundleLocalizations": ["ko", "en"],
    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
  ]
  /// Apple Developer Program 팀 ID ("Joongwon Kim", 개인 팀). 실기기 빌드는 Xcode 자동 서명으로 프로비저닝한다.
  /// `make build`/`make test` 와 CI 는 서명 없이 빌드하므로 이 값을 쓰지 않는다.
  static let developmentTeam = "XHV4ZL5K8T"

  static let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": .string(Self.developmentTeam),
  ]

  static func bundleId(_ name: String) -> String {
    "\(self.bundleIdPrefix).\(name.lowercased())"
  }
}

public extension Project {
  /// 앱 조립 지점. Feature 와 Client Impl 을 모두 알고 있는 유일한 모듈.
  static func app(infoPlist: [String: Plist.Value], dependencies: [TargetDependency]) -> Project {
    Project(
      name: "App",
      options: .options(defaultKnownRegions: ["ko", "en"], developmentRegion: "ko"),
      settings: .settings(base: Env.baseSettings),
      targets: [
        .target(
          name: Env.appName,
          destinations: Env.destinations,
          product: .app,
          bundleId: Env.bundleIdPrefix,
          deploymentTargets: Env.deploymentTargets,
          infoPlist: .extendingDefault(with: Env.appInfoPlist.merging(infoPlist) { $1 }),
          buildableFolders: ["Sources", "Resources"],
          dependencies: dependencies
        ),
      ]
    )
  }

  /// Client 모듈: Interface(프로토콜·값 타입) / Impl(Apple 프레임워크 구현 또는 다른 Client 조합) / Testing(Fake) / Tests.
  /// - Parameters:
  ///   - clients: Impl 이 조합하는 다른 Client. Impl 에는 Interface 가, Tests 에는 Interface 와 Fake 가 든 Testing 이 연결된다.
  ///   - shared: Client 가 사용하는 Shared 모듈. 네 타깃 모두에 연결된다.
  static func client(
    _ client: Client,
    clients: [Client] = [],
    shared: [Shared] = [],
    interfaceDependencies: [TargetDependency] = [],
    implDependencies: [TargetDependency] = []
  ) -> Project {
    let shared = shared.map { TargetDependency.shared($0) }
    let otherInterfaces = clients.map { TargetDependency.client(interface: $0) }
    let otherTestings = clients.map { TargetDependency.client(testing: $0) }
    return Project(
      name: client.rawValue,
      settings: .settings(base: Env.baseSettings),
      targets: [
        .module(name: client.interface, sources: "Interface", dependencies: shared + interfaceDependencies),
        .module(
          name: client.impl,
          sources: "Impl",
          dependencies: [.target(name: client.interface)] + shared + otherInterfaces + implDependencies
        ),
        .module(
          name: client.testing,
          sources: "Testing",
          dependencies: [.target(name: client.interface)] + shared
        ),
        .tests(
          name: client.tests,
          dependencies: [.target(name: client.impl), .target(name: client.testing)] + shared + otherInterfaces
            + otherTestings
        ),
      ]
    )
  }

  /// Feature 모듈: Feature(Model + View) / Tests / Example(Fake 로 단독 실행되는 데모 앱).
  /// - Parameters:
  ///   - clients: Feature 가 사용하는 Client. Feature 에는 Interface 가, Tests·Example 에는 Testing 이 연결된다.
  ///   - shared: Feature 가 사용하는 Shared 모듈. Feature·Tests·Example 모두에 연결된다.
  static func feature(
    _ feature: Feature,
    clients: [Client] = [],
    shared: [Shared] = []
  ) -> Project {
    let testing = clients.map { TargetDependency.client(testing: $0) }
    let shared = shared.map { TargetDependency.shared($0) }
    return Project(
      name: feature.name,
      settings: .settings(base: Env.baseSettings),
      targets: [
        .module(
          name: feature.name,
          sources: "Sources",
          dependencies: clients.map { .client(interface: $0) } + shared
        ),
        .tests(name: feature.tests, dependencies: [.target(name: feature.name)] + testing + shared),
        .target(
          name: feature.example,
          destinations: Env.destinations,
          product: .app,
          bundleId: Env.bundleId(feature.example),
          deploymentTargets: Env.deploymentTargets,
          infoPlist: .extendingDefault(with: Env.appInfoPlist),
          buildableFolders: ["Example"],
          dependencies: [.target(name: feature.name)] + testing + shared
        ),
      ]
    )
  }

  /// Shared 모듈: 모듈 / Tests. Client·Feature 에 의존하지 않고, 다른 Shared 는 `shared` 로만 의존한다 (예: DesignSystem → Core).
  /// - Parameter shared: 이 모듈이 쓰는 다른 Shared 모듈. 모듈·Tests 에 연결된다.
  static func shared(_ shared: Shared, shared dependencies: [Shared] = []) -> Project {
    let dependencies = dependencies.map { TargetDependency.shared($0) }
    return Project(
      name: shared.name,
      settings: .settings(base: Env.baseSettings),
      targets: [
        .module(name: shared.name, sources: "Sources", dependencies: dependencies),
        .tests(name: shared.tests, dependencies: [.target(name: shared.name)] + dependencies),
      ]
    )
  }
}

extension Target {
  static func module(name: String, sources: String, dependencies: [TargetDependency]) -> Target {
    .target(
      name: name,
      destinations: Env.destinations,
      product: .staticFramework,
      bundleId: Env.bundleId(name),
      deploymentTargets: Env.deploymentTargets,
      buildableFolders: [.folder(.relativeToManifest(sources))],
      dependencies: dependencies
    )
  }

  static func tests(name: String, dependencies: [TargetDependency]) -> Target {
    .target(
      name: name,
      destinations: Env.destinations,
      product: .unitTests,
      bundleId: Env.bundleId(name),
      deploymentTargets: Env.deploymentTargets,
      buildableFolders: ["Tests"],
      dependencies: dependencies
    )
  }
}
