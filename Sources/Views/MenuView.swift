import SwiftUI

struct MenuView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Arena Mobile")
                    .font(.largeTitle.bold())

                Text("""
                Голая заготовка iOS-приложения — вкладка «Игра» уже содержит рабочий \
                демо-геймлуп на SwiftUI Canvas. Отсюда можно расти в любую сторону: \
                подключить SpriteKit/RealityKit вместо Canvas, добавить свой рендер, \
                или дёргать API вашего Laravel-бэкенда.
                """)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    MenuView()
}
