import SwiftUI
import AVFoundation
import AVKit
import UserNotifications

struct ContentView: View {
    @State private var importedFiles: [ConvertibleFile] = []
    @State private var selectedFormat: String = "mp3"
    @State private var selectedEngine: String = "AVFoundation"
    @State private var isConverting = false
    @State private var progress: Double = 0.0
    @State private var statusMessage: String = ""
    @State private var outputFolder: URL? = nil
    @State private var selectedFile: ConvertibleFile? = nil
    // Conversion settings state
    @State private var audioBitrate: String = "192k"
    @State private var sampleRate: String = "44100"
    @State private var audioChannels: Int = 2
    @State private var videoResolution: String = "1280x720"
    @State private var videoBitrate: String = "2M"
    // Metadata editing state
    @State private var metadataTitle: String = ""
    @State private var metadataArtist: String = ""
    @State private var metadataAlbum: String = ""
    @State private var coverArt: NSImage? = nil
    @State private var coverArtURL: URL? = nil
    // Conversion history state
    @State private var conversionHistory: [HistoryItem] = HistoryItem.load()
    @State private var appearance: Appearance = .system
    // Error log state
    @State private var logMessages: [String] = []

    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
    }

    let formats = ["mp3", "m4a", "wav", "aac"]
    let engines = ["AVFoundation", "ffmpeg"]

    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Audio/Video Converter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)

                // Drag & Drop Area
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.white.opacity(0.5))
                    )
                    .frame(height: 120)
                    .overlay(
                        Text("Drag & drop files here")
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                    }

                // File Picker Button
                Button(action: importFiles) {
                    Label("Import Files", systemImage: "tray.and.arrow.down.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal)

                // List of imported files
                List(selection: $selectedFile) {
                    ForEach(importedFiles) { file in
                        HStack {
                            Text(file.url.lastPathComponent)
                                .foregroundColor(.white)
                            Spacer()
                            switch file.status {
                            case .pending:
                                Image(systemName: "clock").foregroundColor(.yellow)
                            case .converting:
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            case .success:
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            case .error:
                                Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                                if let msg = file.errorMessage {
                                    Text(msg).font(.caption).foregroundColor(.red)
                                }
                            }
                        }
                        .onDrag {
                            if file.status == .success {
                                return NSItemProvider(object: file.url as NSURL)
                            }
                            return NSItemProvider()
                        }
                    }
                }
                .frame(height: 150)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .listStyle(PlainListStyle())

                // Preview Player below the list
                if let file = selectedFile {
                    PreviewPlayer(url: file.url)
                        .frame(height: 80)
                        .padding(.bottom, 10)
                }

                // Format selection
                Picker("Convert to:", selection: $selectedFormat) {
                    ForEach(formats, id: \.self) { format in
                        Text(format.uppercased())
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Engine selection
                Picker("Engine:", selection: $selectedEngine) {
                    ForEach(engines, id: \.self) { engine in
                        Text(engine)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Conversion Settings Section
                GroupBox(label: Label("Conversion Settings", systemImage: "slider.horizontal.3")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Audio Bitrate:")
                            TextField("e.g. 192k", text: $audioBitrate)
                                .frame(width: 60)
                        }
                        HStack {
                            Text("Sample Rate:")
                            TextField("e.g. 44100", text: $sampleRate)
                                .frame(width: 60)
                        }
                        HStack {
                            Text("Channels:")
                            Stepper(value: $audioChannels, in: 1...8) {
                                Text("\(audioChannels)")
                            }
                            .frame(width: 100)
                        }
                        HStack {
                            Text("Video Resolution:")
                            TextField("e.g. 1280x720", text: $videoResolution)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Video Bitrate:")
                            TextField("e.g. 2M", text: $videoBitrate)
                                .frame(width: 60)
                        }
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)

                // Metadata Editing Section
                GroupBox(label: Label("Metadata", systemImage: "tag")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Title:")
                            TextField("Title", text: $metadataTitle)
                        }
                        HStack {
                            Text("Artist:")
                            TextField("Artist", text: $metadataArtist)
                        }
                        HStack {
                            Text("Album:")
                            TextField("Album", text: $metadataAlbum)
                        }
                        HStack {
                            Text("Cover Art:")
                            if let coverArt = coverArt {
                                Image(nsImage: coverArt)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(4)
                            }
                            Button("Choose Image") {
                                pickCoverArt()
                            }
                        }
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)

                // Output Folder Picker
                HStack {
                    Button(action: pickOutputFolder) {
                        Label("Choose Output Folder", systemImage: "folder.fill")
                            .padding(8)
                    }
                    .buttonStyle(GradientButtonStyle())
                    if let folder = outputFolder {
                        Text(folder.path)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("(Default: Same as original file)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)

                // Appearance Picker
                HStack {
                    Text("Appearance:")
                        .foregroundColor(.white)
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { mode in
                            Text(mode.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 220)
                }
                .padding(.horizontal)
                .onChange(of: appearance) { newValue in
                    switch newValue {
                    case .system:
                        NSApp.appearance = nil
                    case .light:
                        NSApp.appearance = NSAppearance(named: .aqua)
                    case .dark:
                        NSApp.appearance = NSAppearance(named: .darkAqua)
                    }
                }

                // Convert Button
                Button(action: convertFiles) {
                    Label("Convert", systemImage: "arrow.right.circle.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal)
                .disabled(importedFiles.isEmpty || isConverting)

                // Progress Indicator
                if isConverting {
                    ProgressView(value: progress, total: 1.0) {
                        Text("Converting...")
                            .foregroundColor(.white)
                    }
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .padding(.horizontal)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(.white)
                }

                // Conversion History Section
                GroupBox(label: Label("Recent Conversions", systemImage: "clock.arrow.circlepath")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if conversionHistory.isEmpty {
                            Text("No recent conversions.")
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            ForEach(conversionHistory) { item in
                                HStack {
                                    Text(item.fileName)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(item.date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Button(action: { NSWorkspace.shared.open(item.outputURL) }) {
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([item.outputURL]) }) {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    // Drag support
                                    .onDrag {
                                        NSItemProvider(object: item.outputURL as NSURL)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Logs Section
                GroupBox(label: Label("Logs", systemImage: "doc.text.magnifyingglass")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if logMessages.isEmpty {
                            Text("No logs yet.")
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            ScrollView {
                                ForEach(logMessages.indices, id: \.self) { idx in
                                    Text(logMessages[idx])
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.bottom, 2)
                                }
                            }
                            HStack {
                                Button("Copy All") {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(logMessages.joined(separator: "\n"), forType: .string)
                                }
                                .buttonStyle(GradientButtonStyle())
                                Button("Clear") { logMessages.removeAll() }
                                    .buttonStyle(GradientButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .frame(width: 500, height: 700)
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    // MARK: - File Import Helpers
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        if !importedFiles.contains(where: { $0.url == url }) {
                            importedFiles.append(ConvertibleFile(url: url))
                        }
                    }
                }
            }
        }
        return true
    }

    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .movie]
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !importedFiles.contains(where: { $0.url == url }) {
                    importedFiles.append(ConvertibleFile(url: url))
                }
            }
        }
    }

    // MARK: - Conversion Logic
    private func convertFiles() {
        isConverting = true
        progress = 0.0
        statusMessage = ""
        let total = Double(importedFiles.count)
        for (index, file) in importedFiles.enumerated() {
            updateFileStatus(file: file, status: .converting)
            let outputDir = outputFolder ?? file.url.deletingLastPathComponent()
            let outputURL = outputDir.appendingPathComponent(file.url.deletingPathExtension().lastPathComponent)
                .appendingPathExtension(selectedFormat)
            if selectedEngine == "AVFoundation" {
                convertWithAVFoundation(inputURL: file.url, outputURL: outputURL) { success, error in
                    DispatchQueue.main.async {
                        progress = Double(index + 1) / total
                        if !success {
                            updateFileStatus(file: file, status: .error, errorMessage: error?.localizedDescription ?? "AVFoundation failed")
                            logError("AVFoundation failed for \(file.url.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")")
                            statusMessage = "AVFoundation failed: \(error?.localizedDescription ?? "Unknown error"). Trying ffmpeg..."
                            convertWithFFmpeg(inputURL: file.url, outputURL: outputURL) { ffSuccess, ffError in
                                DispatchQueue.main.async {
                                    if ffSuccess {
                                        updateFileStatus(file: file, status: .success)
                                        logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                                        addToHistory(fileName: outputURL.lastPathComponent, outputURL: outputURL)
                                    } else {
                                        updateFileStatus(file: file, status: .error, errorMessage: ffError?.localizedDescription ?? "ffmpeg failed")
                                        logError("ffmpeg failed for \(file.url.lastPathComponent): \(ffError?.localizedDescription ?? "Unknown error")")
                                        statusMessage = "Both engines failed: \(ffError?.localizedDescription ?? "Unknown error")"
                                    }
                                    if index == importedFiles.count - 1 {
                                        isConverting = false
                                        notifyConversionComplete()
                                    }
                                }
                            }
                        } else {
                            updateFileStatus(file: file, status: .success)
                            logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                            addToHistory(fileName: outputURL.lastPathComponent, outputURL: outputURL)
                            if index == importedFiles.count - 1 {
                                isConverting = false
                                notifyConversionComplete()
                            }
                        }
                    }
                }
            } else {
                convertWithFFmpeg(inputURL: file.url, outputURL: outputURL) { success, error in
                    DispatchQueue.main.async {
                        progress = Double(index + 1) / total
                        if success {
                            updateFileStatus(file: file, status: .success)
                            logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                            addToHistory(fileName: outputURL.lastPathComponent, outputURL: outputURL)
                        } else {
                            updateFileStatus(file: file, status: .error, errorMessage: error?.localizedDescription ?? "ffmpeg failed")
                            logError("ffmpeg failed for \(file.url.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")")
                            statusMessage = "ffmpeg failed: \(error?.localizedDescription ?? "Unknown error")"
                        }
                        if index == importedFiles.count - 1 {
                            isConverting = false
                            notifyConversionComplete()
                        }
                    }
                }
            }
        }
    }

    private func convertWithAVFoundation(inputURL: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(false, NSError(domain: "AVFoundation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"]))
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = fileType(for: outputURL.pathExtension)
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true, nil)
            case .failed, .cancelled:
                completion(false, exportSession.error)
            default:
                completion(false, NSError(domain: "AVFoundation", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))
            }
        }
    }

    private func fileType(for ext: String) -> AVFileType? {
        switch ext.lowercased() {
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "wav": return .wav
        case "aac": return .m4a // Use .m4a for AAC
        case "mov": return .mov
        case "mp4": return .mp4
        default: return nil
        }
    }

    // Update convertWithFFmpeg to use metadata
    private func convertWithFFmpeg(inputURL: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        let process = Process()
        process.launchPath = "/opt/homebrew/bin/ffmpeg"
        var args = ["-i", inputURL.path]
        // Audio settings
        if ["mp3", "m4a", "aac", "wav"].contains(outputURL.pathExtension.lowercased()) {
            args += ["-b:a", audioBitrate, "-ar", sampleRate, "-ac", "\(audioChannels)"]
        }
        // Video settings
        if ["mp4", "mov", "mkv", "avi"].contains(outputURL.pathExtension.lowercased()) {
            args += ["-s", videoResolution, "-b:v", videoBitrate]
        }
        // Metadata
        if !metadataTitle.isEmpty { args += ["-metadata", "title=\(metadataTitle)"] }
        if !metadataArtist.isEmpty { args += ["-metadata", "artist=\(metadataArtist)"] }
        if !metadataAlbum.isEmpty { args += ["-metadata", "album=\(metadataAlbum)"] }
        if let coverArtURL = coverArtURL {
            args += ["-i", coverArtURL.path, "-map", "0", "-map", "1", "-c", "copy", "-disposition:v:1", "attached_pic"]
        }
        args.append(outputURL.path)
        process.arguments = args
        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    completion(true, nil)
                } else {
                    completion(false, NSError(domain: "ffmpeg", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "ffmpeg failed with code \(proc.terminationStatus)"]))
                }
            }
        }
        do {
            try process.run()
        } catch {
            completion(false, error)
        }
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            outputFolder = panel.url
        }
    }

    private func pickCoverArt() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            coverArt = image
            coverArtURL = url
        }
    }

    private func updateFileStatus(file: ConvertibleFile, status: ConvertibleFile.Status, errorMessage: String? = nil) {
        if let idx = importedFiles.firstIndex(of: file) {
            importedFiles[idx].status = status
            importedFiles[idx].errorMessage = errorMessage
        }
    }

    // Send notification when all conversions are done
    private func notifyConversionComplete() {
        let content = UNMutableNotificationContent()
        content.title = "Conversion Complete"
        content.body = "All files have been converted."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // Add addToHistory function
    private func addToHistory(fileName: String, outputURL: URL) {
        let item = HistoryItem(id: UUID(), fileName: fileName, outputURL: outputURL, date: Date())
        conversionHistory.insert(item, at: 0)
        if conversionHistory.count > 20 { conversionHistory.removeLast() }
        HistoryItem.save(conversionHistory)
    }

    // Add logError and logEvent helpers
    private func logError(_ message: String) {
        logMessages.append("[Error] " + message)
    }
    private func logEvent(_ message: String) {
        logMessages.append("[Info] " + message)
    }
}

// MARK: - Gradient Button Style
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - File Model
struct ConvertibleFile: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    var status: Status = .pending
    var errorMessage: String? = nil
    
    enum Status {
        case pending, converting, success, error
    }
}

// MARK: - Preview Player
struct PreviewPlayer: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .minimal
        view.player = AVPlayer(url: url)
        return view
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = AVPlayer(url: url)
    }
}

// MARK: - History Item Model
struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let outputURL: URL
    let date: Date
    
    static func load() -> [HistoryItem] {
        if let data = UserDefaults.standard.data(forKey: "conversionHistory"),
           let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            return items
        }
        return []
    }
    static func save(_ items: [HistoryItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "conversionHistory")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 