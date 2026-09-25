import SwiftUI

/// Global resources header — pinned to the top of EVERY main screen (wired up in MainTabView via
/// `.safeAreaInset(edge: .top)`, same slot bottomDock already uses at the bottom), mirroring
/// GameLayout.vue's own always-present header on the web app (resources/js/Layouts/
/// GameLayout.vue) rather than only showing on the village map like this used to.
///
/// Два варианта фона — `style` ниже:
///   • `.solid` — плотный непрозрачный градиент + тонкая золотая линия снизу. Это тот самый
///     "как было раньше" верхний навбар обычных экранов (профиль, герой, рынок, ...) —
///     на них под хедером нет ничего, что стоило бы показывать сквозь него, так что
///     прозрачность там только мешает читаемости цифр.
///   • `.transparent` — карта/фон видны сквозь нижнюю часть градиента. Специально оставлен
///     как есть для VillageMapView (только там), где хедер стоит поверх карты деревни на
///     весь экран и должен читаться как часть сцены, а не как отдельная плашка сверху.
struct GameHeaderBar: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    enum Style {
        case solid
        case transparent
    }

    // Lets the crystal pill jump to the Shop, same as MapOverlayControls' own crystalBadge used
    // to (see its removal note below) — passed down from MainTabView the same way selectItem
    // reaches every other screen (see MainTabView.body's own doc comment).
    var selectItem: (NavItem) -> Void = { _ in }
    var style: Style = .solid

    var body: some View {
        VStack(spacing: 4) {
            // "иконки на карте сделать как было раньше" — назад к компактным круглым
            // бейджам (иконка-в-кружке + число рядом), как на референс-скрине рынка,
            // вместо широких прямоугольных плашек bg_res на всю ширину.
            HStack(spacing: 6) {
                AvatarBadge(user: session.currentUser, size: 38)

                // Always laid out, even before villageSession.detail has loaded — used to be gated
                // behind `if let info = villageSession.detail?.village`, which meant the header was
                // JUST the avatar until the first village fetch completed, then suddenly widened to
                // avatar+4 badges filling the row. Now the same 4-badge layout is reserved from the
                // first frame, showing 0 in each until real data arrives.
                let info = villageSession.detail?.village
                resourceBadge(image: "icon_wood", info?.wood ?? 0)
                Spacer(minLength: 0)
                resourceBadge(image: "icon_clay", info?.clay ?? 0)
                Spacer(minLength: 0)
                resourceBadge(image: "icon_iron", info?.iron ?? 0)
                Spacer(minLength: 0)
                resourceBadge(image: "icon_crop", info?.crop ?? 0)
            }

            // Crystals + population — slim second row, right-aligned, always visible.
            HStack(spacing: 8) {
                Spacer()
                crystalPill
                populationPill
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, style == .transparent ? 14 : 8) // прозрачному нужен запас, чтобы градиент успел «раствориться» до контента
        .background(backgroundLayer)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch style {
        case .solid:
            LinearGradient(colors: [GameTheme.panelTop, GameTheme.background], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GameTheme.amber.opacity(0.35)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .top)
        case .transparent:
            LinearGradient(colors: [Color.black.opacity(1.0), Color.black.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        }
    }

    private var crystalPill: some View {
        Button {
            selectItem(NavItem(id: "shop", icon: "💎", label: "Магазин"))
        } label: {
            HStack(spacing: 3) {
                Image("icon_gem").resizable().aspectRatio(contentMode: .fit).frame(width: 14, height: 14)
                Text(fmtCompact(session.currentUser?.gold ?? 0))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // "кол-во людей в городе добавить" — Village::population() is already round-tripped end to
    // end (VillageController::show()'s `'population' => $village->population`, decoded into
    // VillageDetail.VillageInfo.population — see VillageModels.swift).
    private var populationPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 11))
                .foregroundStyle(GameTheme.amberLight)
            Text("\(villageSession.detail?.village.population ?? 0)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }

    // "Как было раньше" — компактный круглый бейдж: иконка в кружке с золотой
    // окантовкой + жирное число рядом, без плашки на всю ширину. Тот самый стиль,
    // что виден на референс-скрине рынка (круглые G/дерево/камень/пшеница бейджи
    // в ряд), которым в прошлый раз заменили на широкие прямоугольные bg_res-плашки —
    // пользователь попросил вернуть как было.
    private func resourceBadge(image: String, _ value: Int) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [GameTheme.panelTop, GameTheme.panelBottom], startPoint: .top, endPoint: .bottom)
                )
                Circle().stroke(GameTheme.amberLight, lineWidth: 1.5)
                Image(image).resizable().aspectRatio(contentMode: .fit).frame(width: 16, height: 16)
            }
            .frame(width: 26, height: 26)
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)

            Text(fmtCompact(value))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Native counterpart of PlayerAvatar.vue's three-way fallback (uploaded image / emoji-on-colour
/// preset / plain initial letter) — reads the flattened avatar_kind/avatar_url/avatar_emoji/
/// avatar_color/avatar_initial fields Api\AuthController::avatarPayload() now sends, so this
/// view never needs its own copy of config('avatars.presets') or storage-URL building logic.
struct AvatarBadge: View {
    let user: GameUser?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            switch user?.avatarKind {
            case "upload":
                if let urlString = user?.avatarUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            initialFace
                        }
                    }
                } else {
                    initialFace
                }
            case "preset":
                ZStack {
                    Circle().fill(Color(hex: user?.avatarColor ?? ""))
                    Text(user?.avatarEmoji ?? "?").font(.system(size: size * 0.46))
                }
            default:
                initialFace
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(
                LinearGradient(colors: [GameTheme.amberLight, GameTheme.btnBottom], startPoint: .top, endPoint: .bottom),
                lineWidth: 3
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    private var initialFace: some View {
        ZStack {
            GameTheme.panelBottom
            Text(user?.avatarInitial ?? "?")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    GameHeaderBar()
        .environmentObject(AuthSession())
        .environmentObject(VillageSession())
}