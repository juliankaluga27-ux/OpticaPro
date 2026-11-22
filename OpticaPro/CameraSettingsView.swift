import SwiftUI

struct CameraSettingsView: View {
    @EnvironmentObject private var camera: CameraController
    @Environment(\.dismiss) private var dismiss
    let mode: CaptureMode
    @State private var selectedSection = "Obraz"

    private let accent = Color(red: 0.75, green: 1.0, blue: 0.22)
    private let sections = ["Obraz", "Wideo", "Sterowanie", "Nakładki"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    sectionPicker
                    switch selectedSection {
                    case "Obraz": photoSettings
                    case "Wideo": videoSettings
                    case "Sterowanie": controlSettings
                    default: overlaySettings
                    }
                    footer
                }
                .padding(20)
            }
            .background(Color(red: 0.075, green: 0.085, blue: 0.09))
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("USTAWIENIA").font(.system(size: 10, weight: .black)).tracking(2).foregroundStyle(accent)
                Text("Dopasuj aparat").font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Pełna kontrola nad ujęciem i plikiem.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.7)).frame(width: 34, height: 34).background(.white.opacity(0.08), in: Circle()) }
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 5) {
            ForEach(sections, id: \.self) { section in
                Button { selectedSection = section } label: {
                    Text(section).font(.system(size: 11, weight: .bold)).foregroundStyle(selectedSection == section ? .black : .white.opacity(0.65))
                        .frame(maxWidth: .infinity).padding(.vertical, 10).background(selectedSection == section ? accent : .clear, in: Capsule())
                }
            }
        }.padding(4).background(.white.opacity(0.06), in: Capsule())
    }

    private var photoSettings: some View {
        VStack(spacing: 14) {
            SettingGroup(title: "ZDJĘCIA", symbol: "camera.aperture") {
                SettingMenuRow(title: "Rozdzielczość", subtitle: "Od 0,3 MP do maksimum kamery", value: camera.photoSize) {
                    ForEach(camera.photoSizes) { size in Button(size.label) { camera.photoSize = size.label } }
                }
                SettingMenuRow(title: "Format pliku", subtitle: "Konwersja po wykonaniu zdjęcia", value: camera.photoFormat.rawValue) {
                    ForEach(PhotoEncoding.allCases) { format in Button(format.rawValue) { camera.photoFormat = format } }
                }
                SettingMenuRow(title: "Proporcje", subtitle: "Kadr pod publikację lub wydruk", value: camera.aspectRatio) {
                    ForEach(["4:3", "16:9", "1:1", "3:2"], id: \.self) { ratio in Button(ratio) { camera.aspectRatio = ratio } }
                }
                ToggleRow(title: "RAW / DNG", subtitle: "Zapis surowych danych, jeśli kamera je udostępnia", isOn: $camera.rawEnabled)
                ToggleRow(title: "Live Photo", subtitle: "Krótki ruch przed i po zdjęciu", isOn: $camera.livePhotoEnabled)
            }
            SettingGroup(title: "WYGLĄD KADRU", symbol: "viewfinder") {
                ToggleRow(title: "Siatka trójpodziału", subtitle: "Pomoc w kompozycji", isOn: $camera.gridEnabled)
                ToggleRow(title: "Poziomica", subtitle: "Wskaźnik poziomego kadru", isOn: $camera.levelEnabled)
            }
        }
    }

    private var videoSettings: some View {
        VStack(spacing: 14) {
            SettingGroup(title: "WIDEO", symbol: "video") {
                SettingMenuRow(title: "Rozdzielczość", subtitle: "Opcje zależą od modelu i trybu kamery", value: camera.videoResolution) {
                    ForEach(camera.videoResolutions, id: \.self) { res in Button(res) { camera.setVideoResolution(res) } }
                }
                SettingMenuRow(title: "Klatkaż", subtitle: "Dostępność sprawdzana na aktywnej kamerze", value: "\(camera.frameRate) kl./s") {
                    ForEach(camera.frameRates, id: \.self) { fps in
                        Button("\(fps) kl./s\(camera.supportedRates().contains(fps) ? "" : " · niedostępne")") { camera.setFrameRate(fps) }
                    }
                }
                SettingMenuRow(title: "Kontener i kodek", subtitle: "Format filmu", value: camera.videoFormat) {
                    ForEach(camera.videoFormats, id: \.self) { format in Button(format) { camera.videoFormat = format } }
                }
                SettingMenuRow(title: "Tryb zwolnionego tempa", subtitle: "Rejestruj z wysokim klatkażem", value: camera.frameRate >= 120 ? "Wysoki klatkaż" : "Automatyczny") {
                    ForEach(["Automatyczny", "120 kl./s", "240 kl./s"], id: \.self) { rate in Button(rate) { let fps = Int(rate.components(separatedBy: " ").first ?? "30") ?? 30; if fps > 0 { camera.setFrameRate(fps) } } }
                }
                SettingMenuRow(title: "Przyspieszenie timelapse", subtitle: "Tempo odtwarzania gotowego klipu", value: "×\(camera.timeLapseSpeed)") {
                    ForEach([2, 5, 10, 20, 30], id: \.self) { speed in Button("×\(speed)") { camera.timeLapseSpeed = speed } }
                }
            }
            SettingGroup(title: "DŹWIĘK I OBSZAR", symbol: "waveform") {
                ToggleRow(title: "Rejestruj dźwięk", subtitle: "Wideo z mikrofonem iPhone’a", isOn: .constant(true))
                ToggleRow(title: "Blokada ekspozycji", subtitle: "Zachowaj jasność podczas nagrania", isOn: .constant(false))
            }
            note("Klatkaż i najwyższa rozdzielczość zależą od modelu iPhone’a, wybranej kamery oraz aktualnego trybu.")
        }
    }

    private var controlSettings: some View {
        VStack(spacing: 14) {
            SettingGroup(title: "USTAWIENIA APARATU", symbol: "slider.horizontal.3") {
                SettingMenuRow(title: "Tryb ostrości", subtitle: "Automatyczny lub ręczny", value: camera.focusMode) {
                    ForEach(["Ciągły", "Pojedynczy", "Ręczny"], id: \.self) { value in Button(value) { camera.setFocus(value) } }
                }
                SettingMenuRow(title: "Balans bieli", subtitle: "Temperatura światła", value: camera.whiteBalance) {
                    ForEach(["Automatyczny", "Dzienny", "Pochmurny", "Żarówka", "Fluorescencyjny", "Ręczny"], id: \.self) { value in Button(value) { camera.setWhiteBalance(value) } }
                }
                SettingMenuRow(title: "Samowyzwalacz", subtitle: "Opóźnienie migawki", value: camera.timerSeconds == 0 ? "Wyłączony" : "\(camera.timerSeconds) sek.") {
                    ForEach([0, 3, 5, 10], id: \.self) { n in Button(n == 0 ? "Wyłączony" : "\(n) sekund") { camera.timerSeconds = n } }
                }
                ToggleRow(title: "Ciągły błysk", subtitle: "Użyj latarki podczas kadrowania", isOn: $camera.torchOn)
            }
            SettingGroup(title: "PRZETWARZANIE", symbol: "sparkles") {
                ToggleRow(title: "Focus peaking", subtitle: "Podświetl krawędzie ostre na podglądzie", isOn: $camera.focusPeakingEnabled)
                ToggleRow(title: "Zebry", subtitle: "Paski ostrzegające o przepaleniach", isOn: $camera.zebraEnabled)
            }
            note("Manual ISO, czas naświetlania, EV i zoom są dostępne w pasku aparatu. Zakres zależy od aktywnej kamery.")
        }
    }

    private var overlaySettings: some View {
        VStack(spacing: 14) {
            SettingGroup(title: "PODGLĄD", symbol: "rectangle.dashed") {
                ToggleRow(title: "Siatka kadrowania", subtitle: "Linie trójpodziału", isOn: $camera.gridEnabled)
                ToggleRow(title: "Poziomica", subtitle: "Wyrównanie horyzontu", isOn: $camera.levelEnabled)
                ToggleRow(title: "Histogram", subtitle: "Rozkład jasności w kadrze", isOn: $camera.histogramEnabled)
                ToggleRow(title: "Zebra", subtitle: "Ostrzeżenie o jasnych partiach", isOn: $camera.zebraEnabled)
                ToggleRow(title: "Focus peaking", subtitle: "Podgląd ręcznego ostrzenia", isOn: $camera.focusPeakingEnabled)
            }
            SettingGroup(title: "PERSONALIZACJA", symbol: "paintpalette") {
                SettingMenuRow(title: "Kolor akcentu", subtitle: "Kolor elementów sterujących", value: "Limonkowy") {
                    ForEach(["Limonkowy", "Błękitny", "Pomarańczowy", "Biały"], id: \.self) { Button($0) { } }
                }
                SettingMenuRow(title: "Położenie histogramu", subtitle: "Umieszczenie w podglądzie", value: "Lewy dół") {
                    ForEach(["Lewy dół", "Prawy dół", "Lewy górny", "Prawy górny"], id: \.self) { Button($0) { } }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right").foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("OPTICA PRO · iPHONE").font(.system(size: 9, weight: .black)).tracking(1)
                Text("Funkcje sprzętowe są dobierane do możliwości urządzenia.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            }
        }.padding(.top, 4)
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) { Image(systemName: "info.circle.fill").foregroundStyle(accent); Text(text).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true) }
            .font(.system(size: 11)).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SettingGroup<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) { Image(systemName: symbol).foregroundStyle(Color(red: 0.75, green: 1, blue: 0.22)); Text(title).font(.system(size: 10, weight: .black)).tracking(1.2).foregroundStyle(.white.opacity(0.55)); Spacer() }.padding(.horizontal, 14).padding(.vertical, 12)
            content
        }
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.055), lineWidth: 1))
    }
}

private struct SettingMenuRow<Options: View>: View {
    let title: String
    let subtitle: String
    let value: String
    @ViewBuilder let options: Options
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13, weight: .semibold)); Text(subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.43)) }
            Spacer(minLength: 8)
            Menu(content: { options }) {
                HStack(spacing: 4) { Text(value).lineLimit(1); Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold)) }
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(red: 0.75, green: 1, blue: 0.22)).padding(.horizontal, 9).padding(.vertical, 7).background(.white.opacity(0.08), in: Capsule())
            }
        }.padding(.horizontal, 14).padding(.vertical, 11)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13, weight: .semibold)); Text(subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.43)) }
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().tint(Color(red: 0.75, green: 1, blue: 0.22)).scaleEffect(0.8, anchor: .trailing)
        }.padding(.horizontal, 14).padding(.vertical, 9)
    }
}

