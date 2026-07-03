import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.05, blue: 0.06)
                .ignoresSafeArea()

            ParticleCoreMetalView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            controller.start()
        }
    }
}

#Preview {
    ContentView(controller: AppController())
}
