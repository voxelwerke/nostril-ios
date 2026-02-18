import SwiftUI

private struct DatastoreKey: EnvironmentKey {
    static let defaultValue: Datastore? = nil
}

extension EnvironmentValues {
    var datastore: Datastore? {
        get { self[DatastoreKey.self] }
        set { self[DatastoreKey.self] = newValue }
    }
}
