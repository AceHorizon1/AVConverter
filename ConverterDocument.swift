import SwiftUI
import UniformTypeIdentifiers

struct ConverterDocument: FileDocument, Codable {
    static var readableContentTypes: [UTType] { [UTType(exportedAs: "com.ayaan.avconverter.project")] }

    var importedFiles: [String] = []
    var selectedFormat: String = "mp3"
    var selectedEngine: String = "AVFoundation"
    var outputFolderPath: String? = nil
    var metadataTitle: String = ""
    var metadataArtist: String = ""
    var metadataAlbum: String = ""
    var audioBitrate: String = "192k"
    var sampleRate: String = "44100"
    var audioChannels: Int = 2
    var videoResolution: String = "1280x720"
    var videoBitrate: String = "2M"

    // MARK: - FileDocument
    init(importedFiles: [String] = [], selectedFormat: String = "mp3", selectedEngine: String = "AVFoundation", outputFolderPath: String? = nil, metadataTitle: String = "", metadataArtist: String = "", metadataAlbum: String = "", audioBitrate: String = "192k", sampleRate: String = "44100", audioChannels: Int = 2, videoResolution: String = "1280x720", videoBitrate: String = "2M") {
        self.importedFiles = importedFiles
        self.selectedFormat = selectedFormat
        self.selectedEngine = selectedEngine
        self.outputFolderPath = outputFolderPath
        self.metadataTitle = metadataTitle
        self.metadataArtist = metadataArtist
        self.metadataAlbum = metadataAlbum
        self.audioBitrate = audioBitrate
        self.sampleRate = sampleRate
        self.audioChannels = audioChannels
        self.videoResolution = videoResolution
        self.videoBitrate = videoBitrate
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self = try JSONDecoder().decode(ConverterDocument.self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(self)
        return FileWrapper(regularFileWithContents: data)
    }
} 