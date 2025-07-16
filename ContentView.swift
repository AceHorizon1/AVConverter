import SwiftUI
import AVFoundation
import AVKit
import UserNotifications
import QuickLook
import AppKit
import Foundation
import UniformTypeIdentifiers

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

struct ContentView: View {
    @Binding var document: ConverterDocument
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

    let formats = ["mp3", "m4a", "wav", "aac"]
    let engines = ["AVFoundation", "ffmpeg"]
    let iCloudSuite = "iCloud.com.Ayaan.AudioVideoConverter"

    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 14) {
                    Text("Audio/Video Converter")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    // Drag & Drop Area
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
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted) { providers in
                            handleDrop(providers: providers)
                        }
                        .accessibilityLabel("File and folder drop area")
                        .accessibilityHint("Drag and drop audio or video files or folders here to import them.")

                    // File Picker Button
                    Button(action: importFiles) {
                        Label("Import Files", systemImage: "tray.and.arrow.down.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                    .padding(.horizontal)

                    // List of imported files
                    List(selection: $document.selectedFile) {
                        ForEach(document.importedFiles) { file in
                            HStack {
                                Text(file.url.lastPathComponent)
                                    .foregroundColor(.white)
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
                                    document.selectedFile = file
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
                                    if let idx = document.importedFiles.firstIndex(of: file) {
                                        withAnimation {
                                            document.importedFiles.remove(at: idx)
                                        }
                                    }
                                }
                                .accessibilityLabel("Remove from List")
                                .accessibilityHint("Remove this file from the imported files list.")
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut, value: document.importedFiles)
                    .frame(height: 150)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .listStyle(PlainListStyle())
                    .accessibilityLabel("Imported files list")
                    .accessibilityHint("List of imported audio and video files. Use arrow keys to navigate.")

                    // Preview Player below the list
                    if let file = document.selectedFile {
                        PreviewPlayer(url: file.url)
                            .frame(height: 80)
                            .padding(.bottom, 10)
                    }

                    // Format selection
                    Picker("Convert to:", selection: $document.selectedFormat) {
                        ForEach(formats, id: \.self) { format in
                            Text(format.uppercased())
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Engine selection
                    Picker("Engine:", selection: $document.selectedEngine) {
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
                        if let folder = document.outputFolder {
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
                    .disabled(document.importedFiles.isEmpty || document.isConverting)
                    .accessibilityLabel("Convert Files")
                    .accessibilityHint("Convert the imported files to the selected format.")

                    // Progress Indicator
                    if document.isConverting {
                        ProgressView(value: document.progress, total: 1.0) {
                            Text("Converting...")
                                .foregroundColor(.white)
                        }
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .padding(.horizontal)
                        .opacity(document.isConverting ? 1 : 0)
                        .animation(.easeInOut, value: document.isConverting)
                    }

                    if !document.statusMessage.isEmpty {
                        Text(document.statusMessage)
                            .foregroundColor(.white)
                            .opacity(!document.statusMessage.isEmpty ? 1 : 0)
                            .animation(.easeInOut, value: document.statusMessage)
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

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: 500)
                .navigationTitle("Audio/Video Converter")
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
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
        .onChange(of: document.importFilesTrigger) { newValue in
            if newValue {
                importFiles()
            }
        }
        .onChange(of: document.pickOutputFolderTrigger) { newValue in
            if newValue {
                pickOutputFolder()
            }
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
                Button(action: {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }) {
                    Label("Preferences", systemImage: "gearshape")
                }
                .help("Preferences")
                .accessibilityLabel("Preferences")
                .accessibilityHint("Open the Preferences window.")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49, let file = document.selectedFile { // 49 is Space bar
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
        .background(TouchBarHost(importAction: importFiles, convertAction: convertFiles, preferencesAction: {}))
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
        panel.allowedContentTypes = [.png, .jpeg]
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !document.importedFiles.contains(where: { $0.url == url }) {
                    document.importedFiles.append(ConvertibleFile(url: url))
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
                        if !document.importedFiles.contains(where: { $0.url == fileURL }) {
                            document.importedFiles.append(ConvertibleFile(url: fileURL))
                        }
                    }
                }
            }
        } else if isSupportedMediaFile(url) {
            if !document.importedFiles.contains(where: { $0.url == url }) {
                document.importedFiles.append(ConvertibleFile(url: url))
            }
        }
    }

    private func isSupportedMediaFile(_ url: URL) -> Bool {
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "mp4", "mov", "mkv", "avi"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Conversion Logic
    private func convertFiles() {
        document.isConverting = true
        document.progress = 0.0
        document.statusMessage = ""
        let total = Double(document.importedFiles.count)
        for (index, file) in document.importedFiles.enumerated() {
            updateFileStatus(file: file, status: .converting)
            let outputDir = document.outputFolder ?? file.url.deletingLastPathComponent()
            let outputURL = outputDir.appendingPathComponent(file.url.deletingPathExtension().lastPathComponent)
                .appendingPathExtension(document.selectedFormat)
            if document.selectedEngine == "AVFoundation" {
                convertWithAVFoundation(inputURL: file.url, outputURL: outputURL) { success, error in
                    DispatchQueue.main.async {
                        document.progress = Double(index + 1) / total
                        if !success {
                            updateFileStatus(file: file, status: .error, errorMessage: error?.localizedDescription ?? "AVFoundation failed")
                            logError("AVFoundation failed for \(file.url.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")")
                            document.statusMessage = "AVFoundation failed: \(error?.localizedDescription ?? "Unknown error"). Trying ffmpeg..."
                            convertWithFFmpeg(inputURL: file.url, outputURL: outputURL) { ffSuccess, ffError in
                                DispatchQueue.main.async {
                                    if ffSuccess {
                                        updateFileStatus(file: file, status: .success)
                                        logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                                        addToHistory(fileName: outputURL.lastPathComponent, outputURL: outputURL)
                                    } else {
                                        updateFileStatus(file: file, status: .error, errorMessage: ffError?.localizedDescription ?? "ffmpeg failed")
                                        logError("ffmpeg failed for \(file.url.lastPathComponent): \(ffError?.localizedDescription ?? "Unknown error")")
                                        document.statusMessage = "Both engines failed: \(ffError?.localizedDescription ?? "Unknown error")"
                                    }
                                    if index == document.importedFiles.count - 1 {
                                        document.isConverting = false
                                        notifyConversionComplete()
                                    }
                                }
                            }
                        } else {
                            updateFileStatus(file: file, status: .success)
                            logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                            addToHistory(fileName: outputURL.lastPathComponent, outputURL: outputURL)
                            if index == document.importedFiles.count - 1 {
                                document.isConverting = false
                                notifyConversionComplete()
                            }
                        }
                    }
                }
            } else {
                convertWithFFmpeg(inputURL: file.url, outputURL: outputURL) { success, error in
                    DispatchQueue.main.async {
                        document.progress = Double(index + 1) / total
                        if success {
                            updateFileStatus(file: file, status: .success)
                            logEvent("Successfully converted \(file.url.lastPathComponent) to \(outputURL.lastPathComponent)")
                            addToHistory(fileName: outputURL.lastPathComponent, outputURL: outputURL)
                        } else {
                            updateFileStatus(file: file, status: .error, errorMessage: error?.localizedDescription ?? "ffmpeg failed")
                            logError("ffmpeg failed for \(file.url.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")")
                            document.statusMessage = "ffmpeg failed: \(error?.localizedDescription ?? "Unknown error")"
                        }
                        if index == document.importedFiles.count - 1 {
                            document.isConverting = false
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
            document.outputFolder = panel.url
        }
    }

    private func pickCoverArt() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            coverArt = image
            coverArtURL = url
        }
    }

    private func updateFileStatus(file: ConvertibleFile, status: ConvertibleFile.Status, errorMessage: String? = nil) {
        if let idx = document.importedFiles.firstIndex(of: file) {
            document.importedFiles[idx].status = status
            document.importedFiles[idx].errorMessage = errorMessage
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
        setSpotlightMetadata(for: outputURL)
    }

    private func setSpotlightMetadata(for url: URL) {
        let title = metadataTitle
        if !title.isEmpty {
            setExtendedAttribute(name: "com.apple.metadata:kMDItemTitle", value: title, url: url)
        }
    }

    private func setExtendedAttribute(name: String, value: String, url: URL) {
        guard let data = value.data(using: .utf8) else { return }
        data.withUnsafeBytes { rawBuffer in
            let result = setxattr(url.path, name, rawBuffer.baseAddress, data.count, 0, 0)
            if result != 0 {
                print("Failed to set xattr \(name) on \(url.path)")
            }
        }
    }

    // Add logError and logEvent helpers
    private func logError(_ message: String) {
        logMessages.append("[Error] " + message)
    }
    private func logEvent(_ message: String) {
        logMessages.append("[Info] " + message)
    }

    private func showQuickLook(for url: URL) {
        quickLookURL = url
        showQuickLookSheet = true
    }

    private func shareFile(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApp.keyWindow, let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
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
            controller.touchBar = makeTouchBar()
            return controller
        }
        func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
        private func makeTouchBar() -> NSTouchBar {
            let touchBar = NSTouchBar()
            touchBar.delegate = context.coordinator
            touchBar.defaultItemIdentifiers = [.importItem, .convertItem, .preferencesItem]
            return touchBar
        }
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

    // Touch Bar Identifiers
    extension NSTouchBarItem.Identifier {
        static let importItem = NSTouchBarItem.Identifier("com.Ayaan.AudioVideoConverter.import")
        static let convertItem = NSTouchBarItem.Identifier("com.Ayaan.AudioVideoConverter.convert")
        static let preferencesItem = NSTouchBarItem.Identifier("com.Ayaan.AudioVideoConverter.preferences")
    }
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
        let defaults = UserDefaults(suiteName: iCloudSuite) ?? .standard
        if let data = defaults.data(forKey: "conversionHistory"),
           let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            return items
        }
        return []
    }
    static func save(_ items: [HistoryItem]) {
        let defaults = UserDefaults(suiteName: iCloudSuite) ?? .standard
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: "conversionHistory")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(ConverterDocument()))
    }
} 