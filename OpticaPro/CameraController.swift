import AVFoundation
import Photos
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

enum CaptureMode: String, CaseIterable, Identifiable {
    case photo = "Zdjęcie", portrait = "Portret", pro = "Pro", video = "Wideo"
    case slowMotion = "Slow‑mo", timeLapse = "Timelapse", panorama = "Panorama", scan = "Skan"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .photo: return "camera.fill"
        case .portrait: return "person.crop.square"
        case .pro: return "slider.horizontal.3"
        case .video: return "video.fill"
        case .slowMotion: return "slowmo"
        case .timeLapse: return "timelapse"
        case .panorama: return "pano"
        case .scan: return "viewfinder"
        }
    }
    var isVideo: Bool { self == .video || self == .slowMotion || self == .timeLapse }
}

struct PhotoSize: Identifiable, Hashable {
    let label: String
    let megapixels: Double?
    var id: String { label }
}

enum PhotoEncoding: String, CaseIterable, Identifiable {
    case jpeg = "JPEG", heic = "HEIC", heif = "HEIF", png = "PNG", tiff = "TIFF"
    case gif = "GIF", bmp = "BMP", jpeg2000 = "JPEG 2000", webp = "WebP", dng = "RAW / DNG"
    var id: String { rawValue }
    var type: String? {
        switch self {
        case .jpeg: return "public.jpeg"
        case .heic: return "public.heic"
        case .heif: return "public.heif"
        case .png: return "public.png"
        case .tiff: return "public.tiff"
        case .gif: return "com.compuserve.gif"
        case .bmp: return "com.microsoft.bmp"
        case .jpeg2000: return "public.jpeg-2000"
        case .webp: return "org.webmproject.webp"
        case .dng: return nil
        }
    }
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .heif: return "heif"
        case .png: return "png"
        case .tiff: return "tiff"
        case .gif: return "gif"
        case .bmp: return "bmp"
        case .jpeg2000: return "jp2"
        case .webp: return "webp"
        case .dng: return "dng"
        }
    }
}

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "optica.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var cameraInput: AVCaptureDeviceInput?
    private var recordingURL: URL?
    private var recordingMode: CaptureMode = .video
    private var maximumMegapixels: Double = 12

    @Published var permissionGranted = false
    @Published var isConfigured = false
    @Published var isRecording = false
    @Published var countdown: Int?
    @Published var errorMessage: String?
    @Published var lastPhoto: UIImage?
    @Published var zoom: CGFloat = 1
    @Published var flash = false
    @Published var exposureEV: Float = 0
    @Published var isoValue: Float = 0
    @Published var shutterSeconds: Double = 0
    @Published var whiteBalance = "Automatyczny"
    @Published var focusMode = "Ciągły"
    @Published var photoSize = "Maksimum"
    @Published var photoFormat: PhotoEncoding = .heic
    @Published var videoResolution = "4K"
    @Published var frameRate = 30
    @Published var timeLapseSpeed = 10
    @Published var videoFormat = "MOV · HEVC"
    @Published var torchOn = false
    @Published var isFrontCamera = false
    @Published var timerSeconds = 0
    @Published var gridEnabled = true
    @Published var levelEnabled = true
    @Published var histogramEnabled = false
    @Published var zebraEnabled = false
    @Published var focusPeakingEnabled = false
    @Published var rawEnabled = false
    @Published var livePhotoEnabled = true
    @Published var aspectRatio = "4:3"

    let photoSizes: [PhotoSize] = [
        PhotoSize(label: "0,3 MP", megapixels: 0.3), PhotoSize(label: "1 MP", megapixels: 1),
        PhotoSize(label: "2 MP", megapixels: 2), PhotoSize(label: "5 MP", megapixels: 5),
        PhotoSize(label: "8 MP", megapixels: 8), PhotoSize(label: "12 MP", megapixels: 12),
        PhotoSize(label: "24 MP", megapixels: 24), PhotoSize(label: "48 MP", megapixels: 48),
        PhotoSize(label: "Maksimum", megapixels: nil)
    ]
    let frameRates = [24, 25, 30, 48, 50, 60, 120, 240]
    let videoResolutions = ["720p", "1080p", "4K", "Maksimum"]
    let videoFormats = ["MOV · HEVC", "MOV · H.264", "MP4 · HEVC", "MP4 · H.264"]

    func requestAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: prepareAudioAndConfigure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async { self?.permissionGranted = allowed }
                if allowed { self?.prepareAudioAndConfigure() }
            }
        default: DispatchQueue.main.async { self.errorMessage = "Włącz dostęp do aparatu w Ustawieniach iPhone’a." }
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
    }

    private func prepareAudioAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized, .denied, .restricted: configure()
        case .notDetermined: AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in self?.configure() }
        @unknown default: configure()
        }
    }

    private func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.errorMessage = "Nie udało się uruchomić kamery." }
                return
            }
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            if self.session.canAddInput(input) { self.session.addInput(input); self.cameraInput = input }
            if let mic = AVCaptureDevice.default(for: .audio), let micInput = try? AVCaptureDeviceInput(device: mic), self.session.canAddInput(micInput) { self.session.addInput(micInput) }
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
            if self.session.canAddOutput(self.movieOutput) { self.session.addOutput(self.movieOutput) }
            if #available(iOS 16.0, *), let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: { Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height) }) {
                self.photoOutput.maxPhotoDimensions = maxDimensions
                self.maximumMegapixels = Double(maxDimensions.width) * Double(maxDimensions.height) / 1_000_000
            } else {
                self.maximumMegapixels = Double(device.activeFormat.highResolutionStillImageDimensions.width * device.activeFormat.highResolutionStillImageDimensions.height) / 1_000_000
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async { self.permissionGranted = true; self.isConfigured = true }
        }
    }

    func toggleCamera() {
        isFrontCamera.toggle()
        configure()
    }

    func setZoom(_ value: CGFloat) {
        guard let device = cameraInput?.device else { return }
        let clamped = min(max(value, 1), device.activeFormat.videoMaxZoomFactor)
        try? device.lockForConfiguration()
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
        DispatchQueue.main.async { self.zoom = clamped }
    }

    func setExposure(_ ev: Float) {
        guard let device = cameraInput?.device else { return }
        try? device.lockForConfiguration()
        device.setExposureTargetBias(ev) { _ in }
        device.unlockForConfiguration()
        exposureEV = ev
    }

    func setISO(_ iso: Float) {
        guard let device = cameraInput?.device, device.isExposureModeSupported(.custom) else { return }
        try? device.lockForConfiguration()
        if iso <= 0 {
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            isoValue = 0
            shutterSeconds = 0
            return
        }
        let duration = shutterSeconds > 0 ? CMTime(seconds: shutterSeconds, preferredTimescale: 1_000_000) : device.exposureDuration
        device.setExposureModeCustom(duration: duration, iso: min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)) { _ in }
        device.unlockForConfiguration()
        isoValue = iso
    }

    func setShutter(_ seconds: Double) {
        guard let device = cameraInput?.device, device.isExposureModeSupported(.custom) else { return }
        try? device.lockForConfiguration()
        if seconds <= 0 {
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            shutterSeconds = 0
            isoValue = 0
            return
        }
        let iso = isoValue > 0 ? isoValue : device.iso
        device.setExposureModeCustom(duration: CMTime(seconds: seconds, preferredTimescale: 1_000_000), iso: iso) { _ in }
        device.unlockForConfiguration()
        shutterSeconds = seconds
    }

    func setFocus(_ mode: String) {
        guard let device = cameraInput?.device else { return }
        try? device.lockForConfiguration()
        device.focusMode = mode == "Ręczny" ? .locked : (device.isFocusModeSupported(.continuousAutoFocus) ? .continuousAutoFocus : .autoFocus)
        device.unlockForConfiguration()
        focusMode = mode
    }

    func setFocusPosition(_ position: Float) {
        guard let device = cameraInput?.device, device.isLockingFocusWithCustomLensPositionSupported else { return }
        try? device.lockForConfiguration()
        device.setFocusModeLocked(lensPosition: min(max(position, 0), 1), completionHandler: nil)
        device.unlockForConfiguration()
        focusMode = "Ręczny"
    }

    func setWhiteBalance(_ preset: String) {
        guard let device = cameraInput?.device else { whiteBalance = preset; return }
        try? device.lockForConfiguration()
        if preset == "Automatyczny" {
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
        } else {
            let temperature: Float
            switch preset {
            case "Dzienny": temperature = 5600
            case "Pochmurny": temperature = 6500
            case "Żarówka": temperature = 3000
            case "Fluorescencyjny": temperature = 4200
            default: device.unlockForConfiguration(); whiteBalance = preset; return
            }
            let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0)
            let raw = device.deviceWhiteBalanceGains(for: values)
            let gains = AVCaptureDevice.WhiteBalanceGains(redGain: min(max(raw.redGain, 1), device.maxWhiteBalanceGain), greenGain: min(max(raw.greenGain, 1), device.maxWhiteBalanceGain), blueGain: min(max(raw.blueGain, 1), device.maxWhiteBalanceGain))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        }
        device.unlockForConfiguration()
        whiteBalance = preset
    }

    func setFrameRate(_ fps: Int) {
        guard let device = cameraInput?.device else { frameRate = fps; return }
        let wanted = Double(fps)
        let formats = device.formats.filter { $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= wanted && $0.maxFrameRate >= wanted } }
        let targetWidth: Int32?
        switch videoResolution {
        case "720p": targetWidth = 1280
        case "1080p": targetWidth = 1920
        case "4K": targetWidth = 3840
        default: targetWidth = nil
        }
        let ranked = formats.sorted { a, b in
            let wa = CMVideoFormatDescriptionGetDimensions(a.formatDescription).width
            let wb = CMVideoFormatDescriptionGetDimensions(b.formatDescription).width
            if let targetWidth { return abs(wa - targetWidth) < abs(wb - targetWidth) }
            return wa > wb
        }
        guard let format = ranked.first else {
            DispatchQueue.main.async { self.errorMessage = "(fps) kl./s nie jest dostępne dla tej kamery i rozdzielczości." }
            return
        }
        try? device.lockForConfiguration()
        device.activeFormat = format
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        device.unlockForConfiguration()
        frameRate = fps
    }

    func setVideoResolution(_ resolution: String) {
        videoResolution = resolution
        let preset: AVCaptureSession.Preset
        switch resolution {
        case "720p": preset = .hd1280x720
        case "1080p": preset = .hd1920x1080
        case "4K": preset = .hd4K3840x2160
        default: preset = .inputPriority
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(preset) { self.session.sessionPreset = preset }
            self.session.commitConfiguration()
            DispatchQueue.main.async { self.setFrameRate(self.frameRate) }
        }
    }

    func supportedRates() -> [Int] {
        guard let device = cameraInput?.device else { return [24, 30, 60] }
        return frameRates.filter { fps in
            let candidates = device.formats.filter { format in format.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= Double(fps) && $0.maxFrameRate >= Double(fps) } }
            guard !candidates.isEmpty else { return false }
            let desired: Int32?
            switch videoResolution { case "720p": desired = 1280; case "1080p": desired = 1920; case "4K": desired = 3840; default: desired = nil }
            return candidates.contains { format in
                guard let desired else { return true }
                return abs(CMVideoFormatDescriptionGetDimensions(format.formatDescription).width - desired) < 300
            }
        }
    }

    func setTorch(_ enabled: Bool) {
        guard let device = cameraInput?.device, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = enabled ? .on : .off
        device.unlockForConfiguration()
        torchOn = enabled
    }

    func capture(mode: CaptureMode) {
        guard !mode.isVideo else { toggleRecording(mode: mode); return }
        guard countdown == nil else { return }
        if timerSeconds > 0 {
            countdown = timerSeconds
            tickCountdown()
            return
        }
        captureStill()
    }

    private func tickCountdown() {
        guard let current = countdown else { return }
        if current <= 1 { countdown = nil; captureStill(); return }
        countdown = current - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.tickCountdown() }
    }

    private func captureStill() {
        let settings: AVCapturePhotoSettings
        if rawEnabled, let raw = photoOutput.availableRawPhotoPixelFormatTypes.first {
            settings = AVCapturePhotoSettings(rawPixelFormatType: raw, processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            let codec: AVVideoCodecType = photoFormat == .jpeg ? .jpeg : .hevc
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
        }
        if #available(iOS 16.0, *) { settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions }
        settings.flashMode = flash ? .on : .off
        if photoOutput.isLivePhotoCaptureSupported && livePhotoEnabled && !rawEnabled {
            settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func toggleRecording(mode: CaptureMode) {
        if movieOutput.isRecording { movieOutput.stopRecording(); return }
        recordingMode = mode
        let actualExtension = "mov"
        if let connection = movieOutput.connection(with: .video) {
            let codec: AVVideoCodecType = videoFormat.contains("H.264") ? .h264 : .hevc
            if movieOutput.availableVideoCodecTypes.contains(codec) {
                movieOutput.setOutputSettings([AVVideoCodecKey: codec], for: connection)
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Optica-\(UUID().uuidString).\(actualExtension)")
        recordingURL = url
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    private func saveVideo(_ url: URL) {
        let speed: Double
        if recordingMode == .slowMotion { speed = Double(max(frameRate, 60)) / 30.0 }
        else if recordingMode == .timeLapse { speed = Double(max(timeLapseSpeed, 2)) }
        else { speed = 1 }
        let wantsMP4 = videoFormat.hasPrefix("MP4")
        if speed != 1 || wantsMP4 {
            retimeVideo(at: url, speed: speed, wantsMP4: wantsMP4) { [weak self] output in
                guard let self else { return }
                if let output { self.storeVideo(output) }
                else { DispatchQueue.main.async { self.errorMessage = "Nie udało się przetworzyć filmu. Zachowano oryginalne nagranie."; self.storeVideo(url) } }
            }
        } else { storeVideo(url) }
    }

    private func storeVideo(_ url: URL) {
        PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }) { [weak self] ok, error in
            DispatchQueue.main.async {
                self?.isRecording = false
                if !ok { self?.errorMessage = error?.localizedDescription ?? "Nie udało się zapisać filmu." }
            }
        }
    }

    private func retimeVideo(at url: URL, speed: Double, wantsMP4: Bool, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: url)
        guard let sourceTrack = asset.tracks(withMediaType: .video).first else { completion(nil); return }
        let composition = AVMutableComposition()
        guard let targetTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { completion(nil); return }
        do {
            let range = CMTimeRange(start: .zero, duration: asset.duration)
            try targetTrack.insertTimeRange(range, of: sourceTrack, at: .zero)
            targetTrack.preferredTransform = sourceTrack.preferredTransform
            let outputDuration = CMTime(seconds: asset.duration.seconds / speed, preferredTimescale: 600)
            targetTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: asset.duration), toDuration: outputDuration)
        } catch { completion(nil); return }
        let preset = speed == 1 ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
        guard let exporter = AVAssetExportSession(asset: composition, presetName: preset) else { completion(nil); return }
        let requestedType: AVFileType = wantsMP4 ? .mp4 : .mov
        let outputType = exporter.supportedFileTypes.contains(requestedType) ? requestedType : .mov
        if outputType != requestedType { DispatchQueue.main.async { self.errorMessage = "MP4 nie jest dostępny dla tego klipu. Zapisano MOV." } }
        let ext = outputType == .mp4 ? "mp4" : "mov"
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("Optica-\(UUID().uuidString).\(ext)")
        exporter.outputURL = output
        exporter.outputFileType = outputType
        exporter.shouldOptimizeForNetworkUse = false
        exporter.exportAsynchronously {
            completion(exporter.status == .completed ? output : nil)
        }
    }

    private func processPhoto(_ data: Data, isRaw: Bool) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            DispatchQueue.main.async { self.errorMessage = "Nie udało się odczytać zdjęcia." }; return
        }
        let targetMP = photoSizes.first(where: { $0.label == photoSize })?.megapixels
        var outputImage = image
        let targetRatio: CGFloat?
        switch aspectRatio {
        case "16:9": targetRatio = 16.0 / 9.0
        case "1:1": targetRatio = 1
        case "3:2": targetRatio = 3.0 / 2.0
        default: targetRatio = nil
        }
        if let targetRatio {
            let currentRatio = CGFloat(image.width) / CGFloat(image.height)
            let cropRect: CGRect
            if currentRatio > targetRatio {
                let width = CGFloat(image.height) * targetRatio
                cropRect = CGRect(x: (CGFloat(image.width) - width) / 2, y: 0, width: width, height: CGFloat(image.height))
            } else {
                let height = CGFloat(image.width) / targetRatio
                cropRect = CGRect(x: 0, y: (CGFloat(image.height) - height) / 2, width: CGFloat(image.width), height: height)
            }
            outputImage = image.cropping(to: cropRect.integral) ?? image
        }
        if let targetMP, targetMP < maximumMegapixels {
            let ratio = sqrt((targetMP * 1_000_000) / Double(image.width * image.height))
            let width = max(1, Int(Double(image.width) * min(1, ratio)))
            let height = max(1, Int(Double(image.height) * min(1, ratio)))
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                outputImage = context.makeImage() ?? image
            }
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("Optica-\(UUID().uuidString).\(isRaw ? "dng" : photoFormat.fileExtension)")
        if isRaw {
            try? data.write(to: outputURL)
        } else if let type = photoFormat.type, let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, type as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, outputImage, nil)
            _ = CGImageDestinationFinalize(destination)
        } else if let jpeg = UIImage(cgImage: outputImage).jpegData(compressionQuality: 0.96) {
            try? jpeg.write(to: outputURL)
            DispatchQueue.main.async { self.errorMessage = "Ten format nie jest obsługiwany przez system. Zapisano JPEG." }
        }
        DispatchQueue.main.async { self.lastPhoto = UIImage(cgImage: outputImage) }
        PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: outputURL) }) { [weak self] ok, error in
            if !ok { DispatchQueue.main.async { self?.errorMessage = error?.localizedDescription ?? "Nie udało się zapisać zdjęcia." } }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { DispatchQueue.main.async { self.errorMessage = error.localizedDescription }; return }
        guard let data = photo.fileDataRepresentation() else { return }
        processPhoto(data, isRaw: photo.isRawPhoto)
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil { saveVideo(outputFileURL) }
        else { DispatchQueue.main.async { self.errorMessage = error?.localizedDescription } }
    }
}
