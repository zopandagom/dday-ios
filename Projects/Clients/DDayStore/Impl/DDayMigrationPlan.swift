import SwiftData

/// 저장 형식 버전 목록과 버전 사이 마이그레이션 단계. 새 버전을 추가할 때 `schemas` 끝에 붙이고 단계를 더한다 (PRODUCT §3).
enum DDayMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [DDaySchemaV1.self] }
  static var stages: [MigrationStage] { [] }
}
