import SwiftUI

/// What each nav item (see NavItem.swift) opens. Everything except "Профиль" is still a plain
/// placeholder — real content lands here screen by screen as routes/api.php grows past auth.
/// "Профиль" is wired to the real logged-in user already, as a working end-to-end example of
/// the pattern: GameUser from AuthSession, no extra network call needed since MainTabView
/// already has it.
struct NavDestinationView: View {
    let item: NavItem

    var body: some View {
        if item.id == "profile" {
            ProfileScreen()
        } else {
            PlaceholderScreen(item: item)
        }
    }
}

private struct PlaceholderScreen: View {
    let item: NavItem

    var body: some View {
        VStack(spacing: 16) {
            Text(item.icon).font(.system(size: 56))
            Text(item.label).font(.title2.bold())
            Text("Экран «\(item.label)» ещё не подключён к данным игры — здесь появится то же самое, что вы видите на этой вкладке в веб-версии.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(item.label)
    }
}

private struct ProfileScreen: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        List {
            if let user = session.currentUser {
                Section("Игрок") {
                    LabeledContent("Имя", value: user.name)
                    LabeledContent("Email", value: user.email)
                    if let tribe = user.tribe { LabeledContent("Племя", value: tribe) }
                }
                Section("Ресурсы") {
                    LabeledContent("Золото", value: "\(user.gold)")
                    LabeledContent("Серебро", value: "\(user.silver)")
                    LabeledContent("Очки арены", value: "\(user.arenaPoints)")
                }
            }

            Section {
                Button(role: .destructive) {
                    session.logout()
                } label: {
                    Text("Выйти")
                }
            }
        }
        .navigationTitle("Профиль")
    }
}

#Preview {
    NavigationStack {
        NavDestinationView(item: NavItem.mainItems[0])
    }
}
