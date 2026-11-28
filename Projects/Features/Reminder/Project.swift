import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.feature(.reminder, clients: [.dDayStore, .localNotification], shared: [.core])
