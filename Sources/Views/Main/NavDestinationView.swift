import PhotosUI
import SwiftUI
import UIKit

struct NavDestinationView: View {
    let item: NavItem
    var selectItem: ((NavItem) -> Void)? = nil

    var body: some View {
        Group {
            switch item.id {
            case "profile":
                ProfileScreen()
            // case "village" УБРАН: MainTabView при `selected.id == "village"`
            // рендерит VillageMapView() напрямую, минуя NavDestinationView.
            case "map":
                WorldMapView(onOwnVillageSelected: { selectItem?(.village) }, selectItem: { selectItem?($0) })
            case "fields":
                FieldsMapView(selectItem: { selectItem?($0) })
            case "hero":
                HeroView()
            case "market":
                MarketView()
            case "alliance":
                AllianceView()
            case "shop":
                ShopView()
            case "rally_point":
                RallyPointView()
            case "commanders":
                CommandersView()
            case "arena":
                ArenaView()
            case "backpack":
                BackpackView()
            case "reports":
                ReportsView()
            case "messages":
                MessagesView()
            case "research":
                ResearchView()
            case "tech_tree":
                TechTreeView()
            case "statistics":
                StatisticsView()
            case "quests":
                QuestsView()
            case "help":
                HelpView()
            default:
                PlaceholderScreen(item: item)
            }
        }
        .gameNavBarHidden()
    }
}

private struct PlaceholderScreen: View {
    let item: NavItem

    var body: some View {
        VStack(spacing: 16) {
            Text(item.icon).font(.system(size: 56))
            Text(item.label).font(.title2.bold()).foregroundStyle(GameTheme.amber)
            Text("Экран «\(item.label)» ещё не подключён к данным игры — здесь появится то же самое, что вы видите на этой вкладке в веб-версии.")
                .font(.subheadline)
                .foregroundStyle(GameTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gameScreenBackground()
        .withScreenTitle { ScreenTitleBar(item.label) }
    }
}

/// "профиль игрока сделать в соответствие со всем приложением, загрузку аватар" — перестроен с
/// голого `List`+`LabeledContent` на те же карточки-`gamePanel`, что и Герой/Рынок, плюс реальная
/// смена аватара (заготовка из галереи или своя фотография), которой раньше в приложении не было
/// вовсе — только веб (UpdateAvatarForm.vue) мог менять avatar_type/avatar_value.
private struct ProfileScreen: View {
    @EnvironmentObject private var session: AuthSession

    @State private var presets: [AvatarPreset] = []
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let user = session.currentUser {
                    avatarSection(user)
                    infoSection(user)
                    resourcesSection(user)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .gamePanel(padding: 12)
                }

                Button(role: .destructive) {
                    Task { await session.logout() }
                } label: {
                    Text("Выйти").frame(maxWidth: .infinity)
                }
                .buttonStyle(.gameSecondary)
            }
            .padding(16)
        }
        .disabled(isBusy)
        .gameScreenBackground()
        .withScreenTitle { ScreenTitleBar("Профиль") }
        .task { await loadPresets() }
        .onChange(of: photoItem) { _, newItem in
            Task { await handlePickedPhoto(newItem) }
        }
    }

    private func avatarSection(_ user: GameUser) -> some View {
        VStack(spacing: 14) {
            AvatarBadge(user: user, size: 88)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Загрузить своё фото", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.gamePrimary)
            .disabled(isBusy)

            if !presets.isEmpty {
                Text("Или выберите значок").font(.footnote).foregroundStyle(GameTheme.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(presets) { preset in
                        let isSelected = user.avatarKind == "preset" && user.avatarEmoji == preset.emoji && user.avatarColor == preset.color
                        Button {
                            Task { await choosePreset(preset.key) }
                        } label: {
                            ZStack {
                                Circle().fill(Color(hex: preset.color))
                                Text(preset.emoji).font(.system(size: 18))
                            }
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(isSelected ? GameTheme.amber : Color.clear, lineWidth: 2))
                        }
                        .disabled(isBusy)
                    }
                }
            }
        }
        .gamePanel(padding: 16)
    }

    private func infoSection(_ user: GameUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Игрок").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
            labeledRow("Имя", user.name)
            labeledRow("Email", user.email)
            if let tribe = user.tribe { labeledRow("Племя", tribe) }
        }
        .gamePanel(padding: 16)
    }

    private func resourcesSection(_ user: GameUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ресурсы").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
            labeledRow("Кристаллы", "\(user.gold)")
            labeledRow("Очки арены", "\(user.arenaPoints)")
        }
        .gamePanel(padding: 16)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(GameTheme.textSecondary)
            Spacer()
            Text(value).font(.footnote.bold()).foregroundStyle(GameTheme.textPrimary)
        }
    }

    private func loadPresets() async {
        guard presets.isEmpty, let token = session.bearerToken else { return }
        presets = (try? await APIClient.shared.fetchAvatarPresets(token: token)) ?? []
    }

    private func choosePreset(_ key: String) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let user = try await APIClient.shared.setAvatarPreset(key, token: token)
            session.applyUpdatedUser(user)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let token = session.bearerToken else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false; photoItem = nil }
        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else { return }
            // Перекодируем в JPEG вне зависимости от исходного формата (например, HEIC с
            // iPhone) — серверное правило валидации `image` не знает HEIC, а так гарантированно
            // получаем формат, который Laravel примет.
            guard let uiImage = UIImage(data: rawData), let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                errorMessage = "Не удалось обработать изображение."
                return
            }
            let user = try await APIClient.shared.uploadAvatar(imageData: jpegData, filename: "avatar.jpg", mimeType: "image/jpeg", token: token)
            session.applyUpdatedUser(user)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось загрузить фото."
        }
    }
}

#Preview {
    NavigationStack {
        NavDestinationView(item: NavItem.mainItems[0])
    }
    .environmentObject(AuthSession())
    .environmentObject(VillageSession())
}