import SwiftUI
import AVFoundation

struct CameraScreen: View {
    @EnvironmentObject private var camera: CameraController
    @State private var mode: CaptureMode = .photo
    @State private var showSettings = false
    @State private var showMore = false
    @State private var showProControls = false
    @State private var showZoom = false
    @State private var selectedTab = "Aparat"
    @State private var manualFocus: Double = 0.5

    private let accent = Color(red: 0.75, green: 1.0, blue: 0.22)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if camera.isConfigured {
                    CameraPreview(session: camera.session).ignoresSafeArea()
                } else {
                    PreviewPlaceholder()
                }

                if camera.gridEnabled { GridOverlay().allowsHitTesting(false) }
                if camera.levelEnabled { LevelOverlay().allowsHitTesting(false) }
                if camera.zebraEnabled { ZebraOverlay().allowsHitTesting(false) }

                VStack(spacing: 0) {
                    topBar
                    if mode == .pro { proStrip.padding(.top, 8) }
                    Spacer(minLength: 10)
                    if camera.histogramEnabled { HistogramView().frame(width: 120, height: 50).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18) }
                    if showZoom { zoomSlider.padding(.bottom, 12) }
                    bottomControls
                }
                .padding(.top, geometry.safeAreaInsets.top + 5)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 4)

                if showProControls { proControls.padding(.horizontal, 18).padding(.bottom, 174).frame(maxHeight: .infinity, alignment: .bottom) }

                VStack {
                    Spacer()
                    if let error = camera.errorMessage {
                        Text(error).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 10).background(.black.opacity(0.75), in: Capsule())
                            .padding(.bottom, 180).onTapGesture { camera.errorMessage = nil }
                    }
                }
            }
            .statusBarHidden()
            .sheet(isPresented: $showSettings) { CameraSettingsView(mode: mode).environmentObject(camera).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        }
        .onAppear { camera.requestAndConfigure() }
        .onChange(of: camera.torchOn) { _, value in camera.setTorch(value) }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { showSettings = true } label: { Image(systemName: "gearshape").font(.system(size: 18, weight: .medium)).frame(width: 42, height: 42).background(.black.opacity(0.38), in: Circle()) }
            Button { camera.flash.toggle() } label: { Image(systemName: camera.flash ? "bolt.fill" : "bolt.slash").foregroundStyle(camera.flash ? accent : .white).frame(width: 42, height: 42).background(.black.opacity(0.38), in: Circle()) }
            Button { camera.aspectRatio = camera.aspectRatio == "4:3" ? "16:9" : camera.aspectRatio == "16:9" ? "1:1" : "4:3" } label: {
                Text(camera.aspectRatio).font(.system(size: 12, weight: .bold, design: .rounded)).frame(width: 48, height: 42).background(.black.opacity(0.38), in: Capsule())
            }
            Spacer()
            Text(mode == .pro ? "OPTICA PRO" : "OPTICA").font(.system(size: 11, weight: .black, design: .rounded)).tracking(2.5).foregroundStyle(accent)
            Spacer()
            Button { camera.timerSeconds = camera.timerSeconds == 0 ? 3 : camera.timerSeconds == 3 ? 10 : 0 } label: {
                VStack(spacing: 1) { Image(systemName: "timer").font(.system(size: 16)); Text(camera.timerSeconds == 0 ? "OFF" : "\(camera.timerSeconds)s").font(.system(size: 8, weight: .bold)) }
                    .frame(width: 42, height: 42).background(.black.opacity(0.38), in: Circle())
            }
            Button { showMore = true } label: { Image(systemName: "ellipsis").font(.system(size: 18, weight: .bold)).frame(width: 42, height: 42).background(.black.opacity(0.38), in: Circle()) }
                .confirmationDialog("Szybkie narzędzia", isPresented: $showMore, titleVisibility: .visible) {
                    Button("Histogram") { camera.histogramEnabled.toggle() }
                    Button("Linie zebry") { camera.zebraEnabled.toggle() }
                    Button("Focus peaking") { camera.focusPeakingEnabled.toggle() }
                    Button("RAW / DNG") { camera.rawEnabled.toggle() }
                    Button("Pokaż ustawienia") { showSettings = true }
                    Button("Anuluj", role: .cancel) { }
                }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
    }

    private var proStrip: some View {
        HStack(spacing: 0) {
            proValue("ISO", value: camera.isoValue == 0 ? "AUTO" : "\(Int(camera.isoValue))") { showProControls = true }
            Divider().overlay(.white.opacity(0.2)).frame(height: 25)
            proValue("CZAS", value: camera.shutterSeconds == 0 ? "AUTO" : "1/\(Int(1 / camera.shutterSeconds))") { showProControls = true }
            Divider().overlay(.white.opacity(0.2)).frame(height: 25)
            proValue("WB", value: camera.whiteBalance == "Automatyczny" ? "AUTO" : camera.whiteBalance) { showProControls = true }
            Divider().overlay(.white.opacity(0.2)).frame(height: 25)
            proValue("AF", value: camera.focusMode == "Ciągły" ? "AF‑C" : "MF") { showProControls = true }
        }
        .padding(.horizontal, 10).padding(.vertical, 8).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 30)
    }

    private func proValue(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 3) { Text(title).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.6)); Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(accent) }.frame(maxWidth: .infinity) }
    }

    private var zoomSlider: some View {
        HStack(spacing: 12) {
            ForEach([1.0, 1.5, 2.0, 3.0], id: \.self) { factor in
                Button { camera.setZoom(factor) } label: {
                    Text(factor == 1 ? "1×" : "\(String(format: "%.1f", factor))×")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(abs(camera.zoom - factor) < 0.12 ? accent : .white)
                        .frame(width: 44, height: 38).background(.black.opacity(0.5), in: Circle())
                }
            }
            Slider(value: Binding(get: { Double(camera.zoom) }, set: { camera.setZoom(CGFloat($0)) }), in: 1...8).tint(accent).frame(width: 100)
        }
        .padding(.horizontal, 12).padding(.vertical, 7).background(.black.opacity(0.5), in: Capsule())
    }

    private var proControls: some View {
        VStack(spacing: 12) {
            HStack { Text("TRYB RĘCZNY").font(.system(size: 10, weight: .black)).tracking(1.2).foregroundStyle(accent); Spacer(); Button { showProControls = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.65)) } }
            controlRow("ISO", value: camera.isoValue == 0 ? "AUTO" : "\(Int(camera.isoValue))", range: 0...1600, number: Binding(get: { Double(camera.isoValue) }, set: { camera.setISO(Float($0)) }))
            controlRow("CZAS", value: camera.shutterSeconds == 0 ? "AUTO" : "1/\(Int(1 / camera.shutterSeconds))", range: 0...1, number: Binding(get: { camera.shutterSeconds }, set: { camera.setShutter(max($0, 1 / 8000)) }))
            controlRow("EV", value: String(format: "%+.1f", camera.exposureEV), range: -2...2, number: Binding(get: { Double(camera.exposureEV) }, set: { camera.setExposure(Float($0)) }))
            HStack { Text("OSTROŚĆ").foregroundStyle(.white.opacity(0.65)); Slider(value: $manualFocus).tint(accent); Text(camera.focusMode == "Ręczny" ? "MF" : "AF").foregroundStyle(accent).frame(width: 35) }
                .font(.system(size: 10, weight: .bold))
                .onChange(of: manualFocus) { _, value in camera.setFocusPosition(Float(value)) }
        }
        .padding(14).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
    }

    private func controlRow(_ title: String, value: String, range: ClosedRange<Double>, number: Binding<Double>) -> some View {
        HStack { Text(title).foregroundStyle(.white.opacity(0.65)).frame(width: 38, alignment: .leading); Slider(value: number, in: range).tint(accent); Text(value).foregroundStyle(accent).frame(width: 50, alignment: .trailing) }.font(.system(size: 10, weight: .bold))
    }

    private var bottomControls: some View {
        VStack(spacing: 13) {
            HStack(spacing: 10) {
                Button { showZoom.toggle() } label: { Text("\(String(format: "%.1f", Double(camera.zoom)))×").font(.system(size: 12, weight: .bold)).frame(width: 50, height: 32).background(.black.opacity(0.5), in: Capsule()) }
                Button { showProControls.toggle() } label: { Text("EV \(camera.exposureEV, specifier: "%+.1f")").font(.system(size: 11, weight: .bold)).foregroundStyle(accent).frame(height: 32).padding(.horizontal, 12).background(.black.opacity(0.5), in: Capsule()) }
                Spacer()
                if mode.isVideo {
                    Menu { ForEach(camera.frameRates, id: \.self) { fps in Button("\(fps) kl./s\(camera.supportedRates().contains(fps) ? "" : " · niedostępne")") { camera.setFrameRate(fps) } } } label: {
                        Text("\(camera.videoResolution) · \(camera.frameRate) fps").font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).frame(height: 32).background(.black.opacity(0.5), in: Capsule())
                    }
                } else {
                    Menu { ForEach(camera.photoSizes) { size in Button(size.label) { camera.photoSize = size.label } } } label: {
                        Text(camera.photoSize).font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).frame(height: 32).background(.black.opacity(0.5), in: Capsule())
                    }
                }
            }
            .foregroundStyle(.white).padding(.horizontal, 21)

            HStack(alignment: .center, spacing: 0) {
                Button { selectedTab = "Galeria" } label: {
                    Group {
                        if let image = camera.lastPhoto { Image(uiImage: image).resizable().scaledToFill() }
                        else { Image(systemName: "square.stack").font(.system(size: 20)).foregroundStyle(.white) }
                    }.frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.65), lineWidth: 1))
                }
                Spacer()
                Button { camera.capture(mode: mode) } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                        if camera.isRecording { RoundedRectangle(cornerRadius: 7).fill(.red).frame(width: 28, height: 28) }
                        else { Circle().fill(mode.isVideo ? Color.red : .white).frame(width: 62, height: 62) }
                    }
                }
                .accessibilityLabel(camera.isRecording ? "Zatrzymaj nagrywanie" : "Zrób zdjęcie lub rozpocznij nagrywanie")
                Spacer()
                Button { camera.toggleCamera() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera.fill").font(.system(size: 23)).foregroundStyle(.white).frame(width: 48, height: 48).background(.black.opacity(0.38), in: Circle()) }
            }
            .padding(.horizontal, 28)

            if let countdown = camera.countdown {
                Text("\(countdown)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(accent)
                    .padding(.bottom, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 23) {
                    ForEach(CaptureMode.allCases) { item in
                        Button { selectMode(item) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.icon).font(.system(size: 15, weight: .semibold))
                                Text(item.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.7)
                            }
                            .foregroundStyle(mode == item ? accent : .white.opacity(0.7))
                            .frame(minWidth: 46)
                        }
                    }
                }.padding(.horizontal, 20)
            }
            HStack(spacing: 19) {
                bottomTab("Aparat", icon: "camera")
                bottomTab("Kolekcja", icon: "square.grid.2x2")
                bottomTab("Studio", icon: "slider.horizontal.3")
            }.padding(.top, 3)
        }
        .padding(.top, 10).padding(.bottom, 5)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.54), .black.opacity(0.84)], startPoint: .top, endPoint: .bottom))
    }

    private func bottomTab(_ name: String, icon: String) -> some View {
        Button { if name == "Studio" { showSettings = true }; selectedTab = name } label: {
            HStack(spacing: 6) { Image(systemName: icon); Text(name) }.font(.system(size: 11, weight: .semibold)).foregroundStyle(selectedTab == name ? accent : .white.opacity(0.55))
        }
    }

    private func selectMode(_ newMode: CaptureMode) {
        withAnimation(.easeOut(duration: 0.16)) { mode = newMode; showProControls = false }
        if newMode == .slowMotion {
            let rates = camera.supportedRates()
            camera.setFrameRate(rates.contains(240) ? 240 : (rates.contains(120) ? 120 : (rates.contains(60) ? 60 : 30)))
        } else if newMode == .video {
            camera.setFrameRate(30)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let view = PreviewView(); view.videoPreviewLayer.session = session; view.videoPreviewLayer.videoGravity = .resizeAspectFill; return view }
    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.videoPreviewLayer.session = session }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct PreviewPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.12, blue: 0.13), .black, Color(red: 0.14, green: 0.18, blue: 0.11)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(Color(red: 0.65, green: 0.87, blue: 0.28).opacity(0.08)).frame(width: 300).blur(radius: 40).offset(x: 100, y: 20)
            VStack(spacing: 13) { Image(systemName: "viewfinder").font(.system(size: 55, weight: .ultraLight)).foregroundStyle(.white.opacity(0.5)); Text("OPTICA PRO").font(.system(size: 15, weight: .black, design: .rounded)).tracking(4).foregroundStyle(.white.opacity(0.8)); Text("Uruchamiam kamerę…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)) }
        }
    }
}

private struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for i in 1...2 {
                    let x = geo.size.width * CGFloat(i) / 3
                    let y = geo.size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }.stroke(.white.opacity(0.33), style: StrokeStyle(lineWidth: 0.6, dash: [5, 5]))
        }
    }
}

private struct LevelOverlay: View {
    var body: some View {
        VStack { Spacer(); Capsule().fill(Color(red: 0.75, green: 1, blue: 0.22).opacity(0.8)).frame(width: 68, height: 2); Spacer() }
    }
}

private struct ZebraOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let rect = CGRect(x: geo.size.width * 0.76, y: geo.size.height * 0.28, width: geo.size.width * 0.18, height: geo.size.height * 0.12)
                p.addRect(rect)
                stride(from: rect.minX, through: rect.maxX, by: 8).forEach { x in p.move(to: CGPoint(x: x, y: rect.minY)); p.addLine(to: CGPoint(x: x + 35, y: rect.maxY)) }
            }.stroke(.white.opacity(0.55), lineWidth: 1)
        }.mask(Rectangle())
    }
}

private struct HistogramView: View {
    private let heights: [CGFloat] = [0.10,0.16,0.24,0.38,0.52,0.69,0.83,0.91,0.86,0.76,0.62,0.49,0.35,0.25,0.16,0.10,0.06]
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) { ForEach(heights.indices, id: \.self) { i in Capsule().fill(Color(red: 0.75, green: 1, blue: 0.22).opacity(0.8)).frame(maxWidth: .infinity).frame(height: 42 * heights[i]) } }
            .padding(7).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

