import Foundation
import SwiftData

/// One model container per process.
///
/// App Intents can wake the app without its interface — a brain dump from Siri
/// runs with no scene at all — and two containers on the same store file in one
/// process is a reliable way to lose writes. Both the app and the intents open
/// the store through this, so there is only ever one.
enum SharedStore {
    static let container: Result<ModelContainer, any Error> = Result {
        try KoolSkoolSchema.makeContainer()
    }
}
