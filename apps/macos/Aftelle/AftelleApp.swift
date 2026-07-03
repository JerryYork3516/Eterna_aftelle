import SwiftUI

@main
struct AftelleApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup("Aftelle") {
            ContentView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}
