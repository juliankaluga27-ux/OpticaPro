import SwiftUI

@main
struct OpticaProApp: App {
    @StateObject private var camera = CameraController()

    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .environmentObject(camera)
                .preferredColorScheme(.dark)
        }
    }
}
