import SwiftUI
import AVFoundation
import AVKit
import UserNotifications
import QuickLook
import AppKit
import Foundation
import UniformTypeIdentifiers
import CoreImage
import CoreAudio
import CoreMedia
import MediaPlayer
import Photos
import Security
import SystemConfiguration
// import ffmpegkit  // FFmpeg Kit Swift Package not available, using shell commands with enhanced features

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

struct ContentView: View {
    // UI-only state
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
    @State private var isDropTargeted: Bool = false
    @State private var quickLookURL: URL? = nil
    @State private var showQuickLookSheet: Bool = false
    @State private var isNetworkAvailable: Bool = true
    @State private var audioAnalysis: [String: Any] = [:]
    @State private var showAdvancedSettings: Bool = false

    let formats = ["mp3", "m4a", "wav", "aac"]
    let engines = ["AVFoundation", "ffmpeg"]
    
    // MARK: - UI Components
    private var backgroundGradient: some View {
        Group {
            if appearance == .dark {
                Color.black
                    .ignoresSafeArea()
            } else {
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
        }
    }
    
    private var titleView: some View {
        Text("Audio/Video Converter")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(appearance == .dark ? .white : .primary)
            .padding(.top, 8)
    }
    
    private var dragDropArea: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isDropTargeted ? Color.blue.opacity(0.25) : Color.white.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(isDropTargeted ? Color.blue : Color.white.opacity(0.5))
            )
            .frame(height: 120)
            .overlay(
                Text("Drag & drop files or folders here")
                    .foregroundColor(appearance == .dark ? .white.opacity(0.8) : .primary.opacity(0.8))
            )
            .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
            .accessibilityLabel("File and folder drop area")
            .accessibilityHint("Drag and drop audio or video files or folders here to import them.")
    }
    
    private var importButton: some View {
        Button(action: importFiles) {
            Label("Import Files", systemImage: "tray.and.arrow.down.fill")
                .padding()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .padding(.horizontal)
    }
    
    private var fileListView: some View {
        List(selection: $selectedFile) {
            ForEach(importedFiles) { file in
                fileRow(for: file)
            }
        }
        .animation(.easeInOut, value: importedFiles)
        .frame(height: 150)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .listStyle(PlainListStyle())
        .accessibilityLabel("Imported files list")
        .accessibilityHint("List of imported audio and video files. Use arrow keys to navigate.")
    }
    
    private var previewPlayerView: some View {
        Group {
            if let file = selectedFile {
                PreviewPlayer(url: file.url)
                    .frame(height: 80)
                    .padding(.bottom, 10)
            }
        }
    }
    
    private var formatSelectionView: some View {
        Picker("Convert to:", selection: $selectedFormat) {
            ForEach(formats, id: \.self) { format in
                Text(format.uppercased())
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var engineSelectionView: some View {
        Picker("Engine:", selection: $selectedEngine) {
            ForEach(engines, id: \.self) { engine in
                Text(engine)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var conversionSettingsView: some View {
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
                
                Button("Advanced Settings") {
                    showAdvancedSettings.toggle()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            .foregroundColor(appearance == .dark ? .white : .primary)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showAdvancedSettings) {
            VStack(spacing: 20) {
                Text("Advanced Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Network Status: \(isNetworkAvailable ? "Connected" : "Disconnected")")
                        .foregroundColor(isNetworkAvailable ? .green : .red)
                    
                    if !audioAnalysis.isEmpty {
                        Text("File Analysis:")
                            .fontWeight(.semibold)
                        Text("Duration: \(String(format: "%.2f", audioAnalysis["duration"] as? Double ?? 0))s")
                        Text("Has Audio: \(audioAnalysis["hasAudio"] as? Bool == true ? "Yes" : "No")")
                        Text("Has Video: \(audioAnalysis["hasVideo"] as? Bool == true ? "Yes" : "No")")
                        
                        if let audioStreams = audioAnalysis["audioStreams"] as? Int {
                            Text("Audio Streams: \(audioStreams)")
                        }
                        if let videoStreams = audioAnalysis["videoStreams"] as? Int {
                            Text("Video Streams: \(videoStreams)")
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Button("Close") {
                    showAdvancedSettings = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(width: 400, height: 300)
        }
    }
    
    private var metadataView: some View {
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
            .foregroundColor(appearance == .dark ? .white : .primary)
        }
        .padding(.horizontal)
    }
    
    private var outputFolderView: some View {
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
                    .foregroundColor(appearance == .dark ? .white.opacity(0.8) : .primary.opacity(0.8))
            } else {
                Text("(Default: Same as original file)")
                    .font(.caption)
                    .foregroundColor(appearance == .dark ? .white.opacity(0.8) : .primary.opacity(0.8))
            }
        }
        .padding(.horizontal)
    }
    
    private var appearanceView: some View {
        HStack {
            Text("Appearance:")
                .foregroundColor(appearance == .dark ? .white : .primary)
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
    }
    
    private var convertButtonView: some View {
        Button(action: convertFiles) {
            Label("Convert", systemImage: "arrow.right.circle.fill")
                .padding()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .padding(.horizontal)
        .disabled(importedFiles.isEmpty || isConverting)
        .accessibilityLabel("Convert Files")
        .accessibilityHint("Convert the imported files to the selected format.")
    }
    
    private var progressView: some View {
        Group {
            if isConverting {
                ProgressView(value: progress, total: 1.0) {
                    Text("Converting...")
                        .foregroundColor(appearance == .dark ? .white : .primary)
                }
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .padding(.horizontal)
                .opacity(isConverting ? 1 : 0)
                .animation(.easeInOut, value: isConverting)
            }
        }
    }
    
    private var statusMessageView: some View {
        Group {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(appearance == .dark ? .white : .primary)
                    .opacity(!statusMessage.isEmpty ? 1 : 0)
                    .animation(.easeInOut, value: statusMessage)
            }
        }
    }
    
    private var conversionHistoryView: some View {
        GroupBox(label: Label("Recent Conversions", systemImage: "clock.arrow.circlepath")) {
            VStack(alignment: .leading, spacing: 8) {
                if conversionHistory.isEmpty {
                    Text("No recent conversions.")
                        .foregroundColor(appearance == .dark ? .white.opacity(0.7) : .primary.opacity(0.7))
                } else {
                    ForEach(conversionHistory) { item in
                        HStack {
                            Text(item.fileName)
                                .foregroundColor(appearance == .dark ? .white : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(item.date, style: .time)
                                .font(.caption)
                                .foregroundColor(appearance == .dark ? .white.opacity(0.7) : .primary.opacity(0.7))
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
    }

    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 14) {
                    titleView
                    dragDropArea
                    importButton
                    fileListView
                    previewPlayerView
                    formatSelectionView
                    engineSelectionView
                    conversionSettingsView
                    metadataView
                    outputFolderView
                    appearanceView
                    convertButtonView
                    progressView
                    statusMessageView
                    conversionHistoryView
                }
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: importFiles) {
                    Label("Import Files", systemImage: "tray.and.arrow.down.fill")
                }
                .help("Import Files")
                .accessibilityLabel("Import Files")
                .accessibilityHint("Open a dialog to import audio or video files.")
                Button(action: convertFiles) {
                    Label("Convert", systemImage: "arrow.right.circle.fill")
                }
                .help("Convert Selected Files")
                .accessibilityLabel("Convert Files")
                .accessibilityHint("Convert the imported files to the selected format.")
                Button(action: showPreferences) {
                    Label("Preferences", systemImage: "gearshape")
                }
                .help("Preferences")
                .accessibilityLabel("Preferences")
                .accessibilityHint("Open the Preferences window.")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49, let file = selectedFile { // 49 is Space bar
                    showQuickLook(for: file.url)
                    return nil // Swallow the event
                }
                return event
            }
        }
        .sheet(isPresented: $showQuickLookSheet) {
            if let url = quickLookURL {
                QuickLookSheetView(url: url)
            }
        }
        .touchBar {
            TouchBarHost(importAction: importFiles, convertAction: convertFiles, preferencesAction: showPreferences)
        }
    }

    // MARK: - Preferences
    private func showPreferences() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    
    // MARK: - File Import Helpers
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        importURL(url)
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
                if isSupportedMediaFile(url) {
                    if !importedFiles.contains(where: { $0.url == url }) {
                        importedFiles.append(ConvertibleFile(url: url))
                    }
                }
            }
        }
    }

    private func importURL(_ url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            // Recursively import supported files from folder
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if isSupportedMediaFile(fileURL) {
                        if !importedFiles.contains(where: { $0.url == fileURL }) {
                            importedFiles.append(ConvertibleFile(url: fileURL))
                        }
                    }
                }
            }
        } else if isSupportedMediaFile(url) {
            if !importedFiles.contains(where: { $0.url == url }) {
                importedFiles.append(ConvertibleFile(url: url))
            }
        }
    }

    private func isSupportedMediaFile(_ url: URL) -> Bool {
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "mp4", "mov", "mkv", "avi"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
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
                                        addToHistory(fileName: file.url.lastPathComponent, outputURL: outputURL)
                                        setSpotlightMetadata(for: outputURL)
                                        if index == importedFiles.count - 1 {
                                            isConverting = false
                                            notifyConversionComplete()
                                        }
                                    } else {
                                        updateFileStatus(file: file, status: .error, errorMessage: ffError?.localizedDescription ?? "FFmpeg failed")
                                        logError("FFmpeg failed for \(file.url.lastPathComponent): \(ffError?.localizedDescription ?? "Unknown error")")
                                        statusMessage = "Conversion failed for \(file.url.lastPathComponent)"
                                        if index == importedFiles.count - 1 {
                                            isConverting = false
                                        }
                                    }
                                }
                            }
                        } else {
                            updateFileStatus(file: file, status: .success)
                            logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                            addToHistory(fileName: file.url.lastPathComponent, outputURL: outputURL)
                            setSpotlightMetadata(for: outputURL)
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
                            addToHistory(fileName: file.url.lastPathComponent, outputURL: outputURL)
                            setSpotlightMetadata(for: outputURL)
                            if index == importedFiles.count - 1 {
                                isConverting = false
                                notifyConversionComplete()
                            }
                        } else {
                            updateFileStatus(file: file, status: .error, errorMessage: error?.localizedDescription ?? "FFmpeg failed")
                            logError("FFmpeg failed for \(file.url.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")")
                            statusMessage = "Conversion failed for \(file.url.lastPathComponent)"
                            if index == importedFiles.count - 1 {
                                isConverting = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func convertWithAVFoundation(inputURL: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        let asset = AVAsset(url: inputURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = fileType(for: selectedFormat)
        exportSession?.exportAsynchronously {
            completion(exportSession?.status == .completed, exportSession?.error)
        }
    }

    private func fileType(for ext: String) -> AVFileType? {
        switch ext.lowercased() {
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "wav": return .wav
        case "aac": return .m4a  // Use .m4a for AAC files
        default: return .m4a
        }
    }

    private func convertWithFFmpeg(inputURL: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        // Check if FFmpeg is available on the system
        let ffmpegPath = findFFmpegPath()
        
        guard let ffmpeg = ffmpegPath else {
            completion(false, NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "FFmpeg not found. Please install FFmpeg using Homebrew: brew install ffmpeg"]))
            return
        }
        
        // Build FFmpeg command based on selected format and settings
        let command = buildFFmpegCommand(inputURL: inputURL, outputURL: outputURL)
        
        // Create process with enhanced error handling
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = command
        
        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Handle process completion with progress tracking
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    completion(true, nil)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown FFmpeg error"
                    completion(false, NSError(domain: "FFmpeg", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString]))
                }
            }
        }
        
        // Start conversion with progress monitoring
        do {
            try process.run()
            
            // Monitor progress by reading error output (FFmpeg writes progress to stderr)
            DispatchQueue.global(qos: .background).async {
                let errorHandle = errorPipe.fileHandleForReading
                while process.isRunning {
                    if let data = try? errorHandle.read(upToCount: 1024),
                       let line = String(data: data, encoding: .utf8) {
                        // Parse FFmpeg progress output
                        if line.contains("time=") {
                            self.parseFFmpegProgress(line)
                        }
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        } catch {
            completion(false, error)
        }
    }
    
    private func parseFFmpegProgress(_ line: String) {
        // Parse FFmpeg progress output like "time=00:00:15.00 bitrate= 128.0kbits/s"
        if let timeRange = line.range(of: "time=\\d{2}:\\d{2}:\\d{2}\\.\\d{2}", options: .regularExpression) {
            let timeString = String(line[timeRange]).replacingOccurrences(of: "time=", with: "")
            let components = timeString.split(separator: ":")
            if components.count == 3,
               let hours = Double(components[0]),
               let minutes = Double(components[1]),
               let seconds = Double(components[2]) {
                let totalSeconds = hours * 3600 + minutes * 60 + seconds
                DispatchQueue.main.async {
                    self.progress = min(totalSeconds / 60.0, 1.0) // Assuming 60 seconds max
                }
            }
        }
    }
    
    private func findFFmpegPath() -> String? {
        // Check common FFmpeg installation paths
        let possiblePaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try to find FFmpeg in PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return path
                }
            }
        } catch {
            // Ignore errors, continue to next method
        }
        
        return nil
    }
    
    private func buildFFmpegCommand(inputURL: URL, outputURL: URL) -> [String] {
        var command = ["-i", inputURL.path]
        
        // Add format-specific settings
        switch selectedFormat.lowercased() {
        case "mp3":
            command += ["-c:a", "libmp3lame", "-b:a", audioBitrate]
        case "m4a":
            command += ["-c:a", "aac", "-b:a", audioBitrate]
        case "aac":
            command += ["-c:a", "aac", "-b:a", audioBitrate]
        case "wav":
            command += ["-c:a", "pcm_s16le"]
        default:
            command += ["-c:a", "libmp3lame", "-b:a", audioBitrate]
        }
        
        // Add sample rate
        if let sampleRateInt = Int(sampleRate) {
            command += ["-ar", "\(sampleRateInt)"]
        }
        
        // Add channels
        command += ["-ac", "\(audioChannels)"]
        
        // Add metadata if available
        if !metadataTitle.isEmpty {
            command += ["-metadata", "title=\(metadataTitle)"]
        }
        if !metadataArtist.isEmpty {
            command += ["-metadata", "artist=\(metadataArtist)"]
        }
        if !metadataAlbum.isEmpty {
            command += ["-metadata", "album=\(metadataAlbum)"]
        }
        
        // Add output file
        command.append(outputURL.path)
        
        return command
    }
    
    // MARK: - Advanced Features using new frameworks
    
    private func checkNetworkStatus() {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            isNetworkAvailable = false
            return
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            isNetworkAvailable = false
            return
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        isNetworkAvailable = isReachable && !needsConnection
    }
    
    private func analyzeAudioFile(_ url: URL) {
        let asset = AVAsset(url: url)
        
        // Enhanced AVFoundation analysis with more details
        var analysis: [String: Any] = [
            "duration": asset.duration.seconds,
            "hasAudio": (try? asset.tracks(withMediaType: .audio))?.isEmpty == false,
            "hasVideo": (try? asset.tracks(withMediaType: .video))?.isEmpty == false
        ]
        
        // Get additional details if available
        if let audioTracks = try? asset.tracks(withMediaType: .audio), !audioTracks.isEmpty {
            analysis["audioStreams"] = audioTracks.count
        }
        
        if let videoTracks = try? asset.tracks(withMediaType: .video), !videoTracks.isEmpty {
            analysis["videoStreams"] = videoTracks.count
        }
        
        self.audioAnalysis = analysis
    }
    
    // Enhanced AVFoundation analysis provides sufficient media information
    
    private func processCoverArt(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Apply filters for better cover art
        let filters: [CIFilter] = [
            // Enhance contrast
            {
                let filter = CIFilter(name: "CIColorControls")
                filter?.setValue(ciImage, forKey: kCIInputImageKey)
                filter?.setValue(1.1, forKey: kCIInputContrastKey)
                filter?.setValue(0.0, forKey: kCIInputSaturationKey)
                return filter
            }(),
            // Sharpen
            {
                let filter = CIFilter(name: "CISharpenLuminance")
                filter?.setValue(ciImage, forKey: kCIInputImageKey)
                filter?.setValue(0.5, forKey: kCIInputSharpnessKey)
                return filter
            }()
        ].compactMap { $0 }
        
        var processedImage = ciImage
        for filter in filters {
            if let outputImage = filter.outputImage {
                processedImage = outputImage
            }
        }
        
        if let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) {
            return NSImage(cgImage: outputCGImage, size: image.size)
        }
        
        return image
    }
    
    private func getAudioDeviceInfo() -> [String: Any] {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
        
        var deviceID: AudioDeviceID = 0
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
        
        // Get device name
        propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
        var deviceName: CFString? = nil
        propertySize = UInt32(MemoryLayout<CFString?>.size)
        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &deviceName)
        
        return [
            "deviceID": deviceID,
            "deviceName": deviceName as? String ?? "Unknown"
        ]
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            outputFolder = panel.url
        }
    }

    private func pickCoverArt() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg]
        if panel.runModal() == .OK {
            if let url = panel.url, let image = NSImage(contentsOf: url) {
                coverArt = image
                coverArtURL = url
            }
        }
    }

    private func updateFileStatus(file: ConvertibleFile, status: ConvertibleFile.Status, errorMessage: String? = nil) {
        if let idx = importedFiles.firstIndex(of: file) {
            importedFiles[idx].status = status
            importedFiles[idx].errorMessage = errorMessage
        }
    }

    private func notifyConversionComplete() {
        let notification = NSUserNotification()
        notification.title = "Conversion Complete"
        notification.informativeText = "All files have been converted successfully."
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func addToHistory(fileName: String, outputURL: URL) {
        let item = HistoryItem(id: UUID(), fileName: fileName, outputURL: outputURL, date: Date())
        conversionHistory.append(item)
        HistoryItem.save(conversionHistory)
    }

    private func setSpotlightMetadata(for url: URL) {
        setExtendedAttribute(name: "com.apple.metadata.kMDItemTitle", value: metadataTitle, url: url)
        setExtendedAttribute(name: "com.apple.metadata.kMDItemArtist", value: metadataArtist, url: url)
        setExtendedAttribute(name: "com.apple.metadata.kMDItemAlbum", value: metadataAlbum, url: url)
    }

    private func setExtendedAttribute(name: String, value: String, url: URL) {
        if !value.isEmpty {
            if let data = value.data(using: .utf8) {
                setxattr(url.path, name, data.withUnsafeBytes { $0.baseAddress }, data.count, 0, 0)
            }
        }
    }

    private func logError(_ message: String) {
        logMessages.append("[ERROR] \(message)")
    }

    private func logEvent(_ message: String) {
        logMessages.append("[INFO] \(message)")
    }

    private func showQuickLook(for url: URL) {
        quickLookURL = url
        showQuickLookSheet = true
    }

    private func shareFile(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: .zero, of: NSApp.keyWindow?.contentView ?? NSView(), preferredEdge: .minY)
    }

    // Move fileRow inside ContentView
    func fileRow(for file: ConvertibleFile) -> some View {
        HStack {
            Text(file.url.lastPathComponent)
                .foregroundColor(appearance == .dark ? .white : .primary)
                .accessibilityLabel("File name: \(file.url.lastPathComponent)")
            Spacer()
            switch file.status {
            case .pending:
                Image(systemName: "clock").foregroundColor(.yellow)
                    .accessibilityLabel("Pending")
            case .converting:
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .accessibilityLabel("Converting")
            case .success:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    .accessibilityLabel("Conversion successful")
            case .error:
                Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                    .accessibilityLabel("Conversion error")
                if let msg = file.errorMessage {
                    Text(msg).font(.caption).foregroundColor(.red)
                        .accessibilityLabel("Error: \(msg)")
                }
            }
        }
        .onDrag {
            if file.status == .success {
                let provider = NSItemProvider(object: file.url as NSURL)
                provider.suggestedName = file.url.lastPathComponent
                return provider
            }
            return NSItemProvider()
        }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            .accessibilityLabel("Reveal in Finder")
            .accessibilityHint("Show this file in Finder.")
            Button("Play/Preview") {
                selectedFile = file
            }
            .accessibilityLabel("Play or Preview")
            .accessibilityHint("Preview this file in the app.")
            Button("Quick Look") {
                showQuickLook(for: file.url)
            }
            .accessibilityLabel("Quick Look")
            .accessibilityHint("Show a Quick Look preview of this file.")
            if file.status == .success {
                Button("Share") {
                    shareFile(file.url)
                }
                .accessibilityLabel("Share")
                .accessibilityHint("Share this file using the macOS share sheet.")
            }
            Button("Remove from List") {
                if let idx = importedFiles.firstIndex(of: file) {
                    withAnimation {
                        importedFiles.remove(at: idx)
                    }
                }
            }
            .accessibilityLabel("Remove from List")
            .accessibilityHint("Remove this file from the imported files list.")
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    struct QuickLookSheetView: View {
        let url: URL
        var body: some View {
            if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                VideoPlayer(player: AVPlayer(url: url))
            } else if ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) {
                if let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Text("Cannot preview image")
                }
            } else {
                Text("Preview not available")
            }
        }
    }

    struct TouchBarHost: NSViewControllerRepresentable {
        let importAction: () -> Void
        let convertAction: () -> Void
        let preferencesAction: () -> Void

        func makeNSViewController(context: Context) -> NSViewController {
            let controller = NSViewController()
            let touchBar = NSTouchBar()
            let coordinator = context.coordinator
            touchBar.delegate = coordinator
            touchBar.defaultItemIdentifiers = [.importItem, .convertItem, .preferencesItem]
            controller.touchBar = touchBar
            return controller
        }
        func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
        func makeCoordinator() -> Coordinator {
            Coordinator(importAction: importAction, convertAction: convertAction, preferencesAction: preferencesAction)
        }
        class Coordinator: NSObject, NSTouchBarDelegate {
            let importAction: () -> Void
            let convertAction: () -> Void
            let preferencesAction: () -> Void
            init(importAction: @escaping () -> Void, convertAction: @escaping () -> Void, preferencesAction: @escaping () -> Void) {
                self.importAction = importAction
                self.convertAction = convertAction
                self.preferencesAction = preferencesAction
            }
            func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
                switch identifier {
                case .importItem:
                    let item = NSCustomTouchBarItem(identifier: .importItem)
                    item.view = NSButton(title: "Import", target: self, action: #selector(importTapped))
                    return item
                case .convertItem:
                    let item = NSCustomTouchBarItem(identifier: .convertItem)
                    item.view = NSButton(title: "Convert", target: self, action: #selector(convertTapped))
                    return item
                case .preferencesItem:
                    let item = NSCustomTouchBarItem(identifier: .preferencesItem)
                    item.view = NSButton(title: "Preferences", target: self, action: #selector(preferencesTapped))
                    return item
                default:
                    return nil
                }
            }
            @objc func importTapped() { importAction() }
            @objc func convertTapped() { convertAction() }
            @objc func preferencesTapped() { preferencesAction() }
        }
    }
}

// Touch Bar Identifiers
extension NSTouchBarItem.Identifier {
    static let importItem = NSTouchBarItem.Identifier("com.Ayaan.AudioVideoConverter.import")
    static let convertItem = NSTouchBarItem.Identifier("com.Ayaan.AudioVideoConverter.convert")
    static let preferencesItem = NSTouchBarItem.Identifier("com.Ayaan.AudioVideoConverter.preferences")
}

// MARK: - Gradient Button Style
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.orange]), startPoint: .leading, endPoint: .trailing)
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
        let defaults = UserDefaults(suiteName: "iCloud.com.Ayaan.AudioVideoConverter") ?? .standard
        if let data = defaults.data(forKey: "conversionHistory"),
           let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            return items
        }
        return []
    }
    static func save(_ items: [HistoryItem]) {
        let defaults = UserDefaults(suiteName: "iCloud.com.Ayaan.AudioVideoConverter") ?? .standard
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: "conversionHistory")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
