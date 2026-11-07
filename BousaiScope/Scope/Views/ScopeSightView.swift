import SwiftUI

enum ScopeSightMode: String {
    case camera
    case compass
}

/// カメラ越しの表示と、コンパス表示。v0.1.0 は登録した地点だけを重ねる。
/// スマートダッシュボード v0.9.33 の ScopeSightView から、地点・方角の補正・方角のデバッグ表示を残し、
/// 周辺・経路・電車・景色・オブジェクト・太陽と月・撮って聞くを外した。
/// 開いている間だけ、カメラ・GPS・モーションを動かす。
struct ScopeSightView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: ScopeSightMode
    /// 地点の「選んだ1つ」(nil なら表示中の地点すべて)
    @State private var selectedPlaceID: UUID?
    @State private var tracker = WaypointTracker()
    @State private var isVisible = false
    /// 方角の補正の操作を出す
    @State private var showsCorrection = false

    init(mode: ScopeSightMode, selectedPlaceID: UUID? = nil) {
        _mode = State(initialValue: mode)
        _selectedPlaceID = State(initialValue: selectedPlaceID)
    }

    var body: some View {
        @Bindable var settings = env.settings
        let camera = env.camera
        ZStack {
            // 映像を待たずに、画面(印、精度の表示)は先に出す
            if mode == .camera, camera.state != .denied, camera.state != .unavailable {
                cameraLayer
            } else {
                compassLayer(currentTargets)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if showsCorrection {
                    ScopeHeadingCorrectionPanel(azimuth: mode == .camera ? tracker.attitude?.azimuth : nil, landmarks: landmarks) {
                        showsCorrection = false
                    }
                }
                statusBar
            }
        }
        .navigationTitle(mode == .camera ? "カメラで見る" : "コンパス")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    mode = mode == .camera ? .compass : .camera
                } label: {
                    Label(mode == .camera ? "コンパス表示" : "カメラ表示", systemImage: mode == .camera ? "safari" : "camera")
                }
                Menu {
                    // 「選んだ1つ」は、非表示の地点も選べる(選んだ地点は一時的に表示する)
                    Picker("表示する地点", selection: $selectedPlaceID) {
                        Text("すべての地点(表示中)").tag(UUID?.none)
                        ForEach(env.waypoints.waypoints) { Text($0.isHidden ? "\($0.name)(非表示)" : $0.name).tag(UUID?.some($0.id)) }
                    }
                    Toggle("向いている方角を表示", isOn: $settings.waypointShowsHeading)
                    Toggle("高さを反映する", isOn: $settings.scopeUsesHeight)
                    Button {
                        showsCorrection.toggle()
                    } label: {
                        Label("方角を補正", systemImage: "location.north.line")
                    }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            isVisible = true
            tracker.onLocation = { [store = env.waypoints, elevation = env.elevation, settings = env.settings] location in
                let coordinate = location.coordinate
                // 自分の高さ: 地面の標高は、100m以上動いたときだけ取り直す
                if settings.scopeHeightSource == .groundPlusHand {
                    elevation.updateGround(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
                let gps: Double? = location.verticalAccuracy > 0 ? location.altitude : nil
                let height = elevation.observerHeight(latitude: coordinate.latitude, longitude: coordinate.longitude, gpsAltitude: gps)
                store.setOrigin(latitude: coordinate.latitude, longitude: coordinate.longitude, height: height?.meters)
            }
            startAll()
        }
        .onDisappear {
            isVisible = false
            stopAll()
        }
        .onChange(of: scenePhase) { _, phase in
            guard isVisible else { return }
            if phase == .active { startAll() } else { stopAll() }
        }
        .onChange(of: mode) { _, _ in
            if isVisible { startAll() }
        }
        .onChange(of: env.settings.headingGyroHold) { _, hold in
            tracker.holdsHeadingWithGyro = hold
        }
    }

    /// 表示する印(すべて: 表示中の地点だけ。選んだ1つ: 非表示の地点でも出す)
    private var marks: [ScopeMark] {
        guard let selectedPlaceID else { return env.waypoints.visibleWaypoints.map { ScopeMark($0) } }
        return env.waypoints.waypoints.filter { $0.id == selectedPlaceID }.map { ScopeMark($0) }
    }

    /// 自分の高さ(設定で選んだ方法。地面の標高が取れないときはGPSの高度)
    private var observer: ObserverHeight? {
        guard let coordinate = tracker.coordinate else { return nil }
        return env.elevation.observerHeight(latitude: coordinate.latitude, longitude: coordinate.longitude, gpsAltitude: tracker.gpsAltitude)
    }

    /// 印の対象(遠い順)
    private var currentTargets: [ScopeTarget] {
        guard let coordinate = tracker.coordinate, !marks.isEmpty else { return [] }
        return ScopeTarget.make(marks, latitude: coordinate.latitude, longitude: coordinate.longitude,
                                observerAltitude: observer?.meters, usesHeight: env.settings.scopeUsesHeight)
    }

    /// カメラ表示の見る位置と向き(現在地と端末の向きが分かるまでは nil)
    private func makeViewpoint(size: CGSize) -> ScopeViewpoint? {
        guard let coordinate = tracker.coordinate, let attitude = tracker.attitude else { return nil }
        let tangents = WaypointProjection.tangents(fieldOfView: env.camera.fieldOfView, videoAspect: env.camera.videoAspect, viewSize: size)
        return ScopeViewpoint(latitude: coordinate.latitude, longitude: coordinate.longitude,
                              eyeAltitude: observer?.meters, attitude: attitude, tangents: tangents)
    }

    /// 方角の補正で合わせる目印(表示している印)
    private var landmarks: [HeadingCorrection.Landmark] {
        currentTargets.map { HeadingCorrection.Landmark(name: $0.mark.name, bearing: $0.bearing) }
    }

    /// カメラ・GPS・モーションは、この画面を表示している間だけ動かす。表示中は画面を消さない。
    private func startAll() {
        let camera = env.camera
        ScreenAwake.set("scope", true)
        tracker.holdsHeadingWithGyro = env.settings.headingGyroHold
        // 位置とモーションは、カメラの準備を待たずに始める(カメラの設定と開始は専用のキューで進む)
        tracker.start(includesMotion: mode == .camera)
        if mode == .camera {
            Task {
                await camera.start()
                // 許可がない、またはこの環境で使えないときは、コンパス表示に切り替える
                if camera.state == .denied || camera.state == .unavailable { mode = .compass }
            }
        } else {
            camera.stop()
        }
    }

    private func stopAll() {
        ScreenAwake.set("scope", false)
        tracker.stop()
        env.camera.stop()
    }

    // MARK: - カメラ越しの表示

    private var cameraLayer: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Color.black
                CameraPreviewView(session: env.camera.session)
                if env.camera.state != .running {
                    VStack {
                        Spacer()
                        Text("カメラを起動中…")
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15), in: Capsule())
                            .padding(.bottom, 12)
                    }
                }
                if size.width > size.height {
                    Text("縦向きで使ってください")
                        .font(.headline)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                } else if let attitude = tracker.attitude {
                    let viewpoint = makeViewpoint(size: size)
                    let targets = viewpoint.map { $0.targets(marks, usesHeight: env.settings.scopeUsesHeight) } ?? []
                    if let viewpoint {
                        ScopeOverlay(targets: targets, viewpoint: viewpoint)
                    }
                    if showsCorrection, !env.settings.headingDebugEnabled {
                        // 方角の補正: 目印を合わせる、画面の中央の十字
                        Image(systemName: "plus")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(.yellow)
                            .shadow(color: .black, radius: 1)
                            .allowsHitTesting(false)
                    }
                    VStack(alignment: .trailing, spacing: 6) {
                        HeadingCorrectionBadge(offset: env.settings.headingOffset)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(8)
                    if env.settings.headingDebugEnabled {
                        let tangents = WaypointProjection.tangents(fieldOfView: env.camera.fieldOfView, videoAspect: env.camera.videoAspect, viewSize: size)
                        // 東西南北の印と水平線を、地点と同じ投影でそのまま描く(実際の方角と重なるかを見る)
                        ScopeCompassRoseOverlay(attitude: attitude, tangents: tangents)
                        VStack {
                            HStack {
                                ScopeHeadingDebugView(tracker: tracker, attitude: attitude, viewSize: size, targets: targets,
                                                      extraLines: debugLines(tangents: tangents, size: size))
                                Spacer(minLength: 0)
                            }
                            Spacer()
                        }
                        .padding(.top, 50)
                        .padding(.horizontal, 8)
                    }
                    if env.settings.waypointShowsHeading {
                        VStack {
                            Text("\(WaypointMath.compassPoint(attitude.azimuth)) \(Int(attitude.azimuth.rounded()))°")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                                .padding(.top, 8)
                            Spacer()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
    }

    /// 方角のデバッグ表示: 画角の内訳と縦の目盛り
    private func debugLines(tangents: (horizontal: Double, vertical: Double), size: CGSize) -> [String] {
        let camera = env.camera
        let perDegree = WaypointProjection.pointsPerDegree(tangents: tangents, viewSize: size)
        let corrected = camera.correctedFieldOfView.map { String(format: "%.1f°", $0) } ?? "なし"
        return [
            String(format: "画角: 形式 %.1f°・歪み補正後 ", camera.formatFieldOfView) + corrected
                + String(format: "・ズーム %.2f → 計算 %.1f°(長辺)", camera.zoom, camera.fieldOfView),
            String(format: "映像 %.2f:1・画面 %.0f×%.0f・1°= 横 %.1fpt / 縦 %.1fpt", camera.videoAspect, size.width, size.height,
                   perDegree.horizontal, perDegree.vertical),
        ]
    }

    // MARK: - コンパス表示

    private func compassLayer(_ targets: [ScopeTarget]) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if env.camera.state == .denied {
                    note("カメラが許可されていないため、コンパス表示にしています。設定アプリでカメラを許可すると、カメラ越しに表示できます。")
                } else if env.camera.state == .unavailable {
                    note("この環境ではカメラを使えないため、コンパス表示にしています。")
                }
                if let heading = tracker.compassHeading {
                    HeadingCorrectionBadge(offset: env.settings.headingOffset)
                    if env.settings.waypointShowsHeading {
                        Text("\(WaypointMath.compassPoint(heading)) \(Int(heading.rounded()))°")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                    }
                    ScopeCompassDial(heading: heading, targets: targets)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 360)
                        .padding(.horizontal)
                    ForEach(Array(targets.reversed().prefix(12))) { target in
                        compassRow(target, heading: heading)
                    }
                    if targets.isEmpty {
                        Text(tracker.coordinate == nil ? "現在地を取得中…" : "表示するものがありません").foregroundStyle(.secondary)
                    }
                } else {
                    Text(tracker.locationAvailability.unavailableText.map { "位置情報: \($0)" } ?? "方位を取得中…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
    }

    private func compassRow(_ target: ScopeTarget, heading: Double) -> some View {
        let turn = WaypointMath.difference(from: heading, to: target.bearing)
        return HStack(spacing: 10) {
            Circle().fill(target.mark.color).frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(target.mark.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(WaypointMath.summary(bearing: target.bearing, distance: target.distance)
                     + (target.heightDifference.map { " " + WaypointMath.heightText($0) } ?? "")
                     + (target.mark.note.isEmpty ? "" : " " + target.mark.note))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(abs(turn) < 5 ? "正面" : "\(turn > 0 ? "右" : "左")へ\(Int(abs(turn).rounded()))°")
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.horizontal)
    }

    // MARK: - 精度の表示

    /// 自分の高さと、その決め方(精度の表示の近くに小さく出す)
    private var observerText: String {
        let settings = env.settings
        guard let observer else { return tracker.coordinate == nil ? "自分の高さ: 測位中" : "自分の高さ: 取得中(地点は地平線の高さに置きます)" }
        var text = observer.text(handHeight: settings.scopeHandHeight, source: settings.scopeHeightSource)
        if observer.method == .gps, let accuracy = tracker.verticalAccuracy { text += " ±\(Int(accuracy.rounded()))m" }
        if !settings.scopeUsesHeight { text += "。高さは反映していません" }
        return text
    }

    private var statusBar: some View {
        let quality = HeadingQuality.make(accuracy: tracker.headingAccuracy)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Text(quality.text)
                Text(tracker.horizontalAccuracy.map { "位置の精度: ±\(Int($0.rounded()))m" }
                     ?? tracker.locationAvailability.unavailableText.map { "位置情報: \($0)" } ?? "位置を取得中…")
            }
            if quality.needsCalibration {
                Text(HeadingQuality.calibrationHint).foregroundStyle(.orange)
            }
            Text(observerText)
            if tracker.usesMagneticNorth, mode == .camera {
                Text("真北が使えないため、磁北を基準にしています(数度ずれます)")
            }
            if let warning = ScopeLocationCheck.warning(accuracy: tracker.horizontalAccuracy, isReduced: tracker.isReducedAccuracy,
                                                         nearest: currentTargets.last?.distance) {
                Text(warning).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }
}

/// カメラの映像(幽体離脱では立体の景色)の上に、画面内にある印を描く。1枚の Canvas にまとめ、遠いものから描く(近いものが手前)。
/// 画面の外にあるものは何も描かない。位置の計算は `ScopeViewpoint` だけを通す。
struct ScopeOverlay: View {
    let targets: [ScopeTarget]
    let viewpoint: ScopeViewpoint

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            for target in targets {
                guard let point = viewpoint.point(bearing: target.bearing, elevation: target.elevationAngle, viewSize: size) else { continue }
                Self.drawMark(&context, at: point, target: target)
            }
        }
        .allowsHitTesting(false)
    }

    static func drawMark(_ context: inout GraphicsContext, at point: CGPoint, target: ScopeTarget) {
        let ring = WaypointMarkStyle.ringDiameter
        let line = WaypointMarkStyle.ringLineWidth
        let ringRect = CGRect(x: point.x - ring / 2, y: point.y - ring / 2, width: ring, height: ring)
        // 暗い映像の上でも見えるよう、黒いリングの外と内に、ごく細い白い縁を付ける
        context.fill(Path(ellipseIn: ringRect.insetBy(dx: line, dy: line)), with: .color(Color.white.opacity(0.35)))
        let inner = WaypointMarkStyle.innerDiameter(distance: target.distance)
        let innerRect = CGRect(x: point.x - inner / 2, y: point.y - inner / 2, width: inner, height: inner)
        context.fill(Path(ellipseIn: innerRect), with: .color(target.mark.color))
        context.stroke(Path(ellipseIn: ringRect.insetBy(dx: -0.5, dy: -0.5)), with: .color(Color.white.opacity(0.9)), lineWidth: 1)
        context.stroke(Path(ellipseIn: ringRect.insetBy(dx: line / 2, dy: line / 2)), with: .color(.black), lineWidth: line)
        // 名前と距離・高低差(薄い背景を付ける)
        let label = context.resolve(Text("\(target.mark.name)  \(WaypointMath.distanceText(target.distance, heightDifference: target.heightDifference))")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white))
        let labelSize = label.measure(in: CGSize(width: 220, height: 40))
        let labelRect = CGRect(x: point.x - labelSize.width / 2 - 6, y: point.y + ring / 2 + 4, width: labelSize.width + 12, height: labelSize.height + 4)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 6), with: .color(Color.black.opacity(0.55)))
        context.draw(label, in: labelRect.insetBy(dx: 6, dy: 2))
    }
}
