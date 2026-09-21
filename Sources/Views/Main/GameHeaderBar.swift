import SwiftUI

/// Global resources header — pinned to the top of EVERY main screen (wired up in MainTabView via
/// `.safeAreaInset(edge: .top)`, same slot bottomDock already uses at the bottom), mirroring
/// GameLayout.vue's own always-present header on the web app (resources/js/Layouts/
/// GameLayout.vue) rather than only showing on the village map like this used to.
///
/// Pared down to exactly two things per an explicit request: the player's own avatar, and the
/// four base resources. Everything else that used to live here — silver/gold currency, the
/// manual refresh button, and (from an earlier round) the village nameplate/switcher and
/// profile/messages/quests action icons — now lives elsewhere (MapOverlayControls for the
/// latter) or nowhere on this screen at all, on purpose: this header's only job now is "who am I
/// and what do I have", the same minimal always-visible strip the reference art shows.
struct GameHeaderBar: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    // Lets the crystal pill jump to the Shop, same as MapOverlayControls' own crystalBadge used
    // to (see its removal note below) — passed down from MainTabView the same way selectItem
    // reaches every other screen (see MainTabView.body's own doc comment).
    var selectItem: (NavItem) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 4) {
            // No longer a horizontal ScrollView: avatar + 4 resource badges are laid out with
            // `.frame(maxWidth: .infinity)` per badge so the row always fills exactly the screen
            // width instead of overflowing and needing a scroll to see the last resource
            // (reported: "надо коректировать размер шрифта, что бы все ресурсы влазили без
            // прокрутки"). Compact K/M numbers (fmtCompact) plus smaller icon/font sizes and a
            // `.minimumScaleFactor` safety margin are what actually make that fit on narrow phones.
            HStack(spacing: 6) {
                AvatarBadge(user: session.currentUser, size: 38)

                // Always laid out, even before villageSession.detail has loaded — used to be gated
                // behind `if let info = villageSession.detail?.village`, which meant the header was
                // JUST the avatar (one 38pt circle, hugging the left edge) until the first village
                // fetch completed, then suddenly widened to avatar+4 badges filling the row. That's
                // the reported "место под ресурсы при загрузки должно быть выстовлено сразу" — the
                // fix is to reserve the same 4-badge layout from the very first frame (including
                // during SplashView's loading state) and just show 0 in each until real data
                // arrives, instead of the row's own shape changing out from under the player.
                let info = villageSession.detail?.village
                resourceBadge(image: "icon_wood", info?.wood ?? 0)
                resourceBadge(image: "icon_clay", info?.clay ?? 0)
                resourceBadge(image: "icon_iron", info?.iron ?? 0)
                resourceBadge(image: "icon_crop", info?.crop ?? 0)
            }

            // "кристаллы разместить под хедером с правой стороны, дальше кол-во населения" —
            // moved out of MapOverlayControls' floating map-only button stack (which meant
            // crystals were invisible on every screen except the two maps) into a slim second row
            // attached right under the resource row, right-aligned, visible everywhere the header
            // is — same "always visible" treatment the four base resources already get. Population
            // ("кол-во людей в городе") sits right next to it, both reading straight off
            // VillageDetail.VillageInfo (see VillageModels.swift) with no new network call needed.
            HStack(spacing: 8) {
                Spacer()
                crystalPill
                populationPill
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [GameTheme.panelTop, GameTheme.background], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GameTheme.amber.opacity(0.35)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .top)
        )
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
    // VillageDetail.VillageInfo.population — see VillageModels.swift), it just wasn't shown
    // anywhere on the map screens; this is the one always-visible spot for it, next to crystals.
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

    // Wide plate — icon left, big bold number right, no name label — mirroring the reference art
    // the user supplied (and GameLayout.vue's matching redesign on the web this same round).
    // Real navy `bg_res` art (Assets.xcassets/GameAssets/UI/bg_res.imageset) instead of the
    // flat-drawn CutCornerShape/GameOctagonBadgeModifier every other badge in this header still
    // uses: that shape's plain navy fill nearly disappeared into this header's own navy
    // background, which is why the resource row went bright amber for a round — this bespoke art
    // has its own baked-in gold border + bevel shading, so navy reads clearly again without the
    // loud recolor (same fix applied on web — see app.css's `.resource-plate`). White text
    // instead of the amber-plate ink colour, to match.
    // `.frame(maxWidth: .infinity)` lets the 4 badges share the row evenly instead of each
    // sizing to its own content and overflowing.
    private func resourceBadge(image: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Image(image).resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18)
            Text(fmtCompact(value))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .frame(height: 34)
        .background(Image("bg_res").resizable(resizingMode: .stretch))
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
                    AsyncImage(url: url) { phase in
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
