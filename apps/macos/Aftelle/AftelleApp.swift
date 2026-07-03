import SwiftUI

@main
struct AftelleApp: App {
    @StateObject private var controller = AppController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("Aftelle") {
            ContentView(controller: controller)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(String(localized: "Quit Aftelle")) {
                    controller.persistForNormalTerminationIfPossible()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                controller.markSessionUncleanIfPossible()
            } else if phase == .inactive || phase == .background {
                controller.markSessionUncleanIfPossible()
            }
        }
    }
}
