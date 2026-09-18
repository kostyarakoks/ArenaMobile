import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("О заготовке") {
                    LabeledContent("Версия", value: "1.0.0")
                    LabeledContent("Xcode-проект", value: "генерируется XcodeGen (project.yml)")
                    LabeledContent("Минимальная iOS", value: "16.0")
                }

                Section("Дальше можно") {
                    Text("Подключить SpriteKit/RealityKit вместо Canvas в GameView")
                    Text("Дёрнуть API вашего Laravel-бэкенда (URLSession / async-await)")
                    Text("Добавить сохранение прогресса (SwiftData или UserDefaults)")
                    Text("Настроить push-уведомления о завершении построек/атак")
                }
            }
            .navigationTitle("Настройки")
        }
    }
}

#Preview {
    SettingsView()
}
