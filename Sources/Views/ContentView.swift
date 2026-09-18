import SwiftUI

/// Root view — a 3-tab shell (Menu / Game / Settings). Swap this for whatever navigation
/// shape your real game needs; a TabView is just the fastest thing to test on a real device.
struct ContentView: View {
    var body: some View {
        TabView {
            MenuView()
                .tabItem { Label("Меню", systemImage: "house.fill") }

            GameView()
                .tabItem { Label("Игра", systemImage: "gamecontroller.fill") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameState())
}
