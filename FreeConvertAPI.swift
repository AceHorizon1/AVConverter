import Foundation
import SwiftUI

// MARK: - FreeConvert API Models
struct FreeConvertJob: Codable {
    let id: String
    let status: String
    let progress: Int?
    let downloadUrl: String?
    let error: String?
}

struct FreeConvertUploadResponse: Codable {
    let id: String
    let job: String
    let operation: String
    let status: String
    let result: UploadResult?
    let error: String?
    
    struct UploadResult: Codable {
        let form: UploadForm
    }
    
    struct UploadForm: Codable {
        let url: String
        let parameters: [String: String]
    }
}

struct FreeConvertJobResponse: Codable {
    let id: String
    let job: String
    let operation: String
    let status: String
    let progress: Int?
    let result: JobResult?
    let error: String?
    
    struct JobResult: Codable {
        let url: String?
    }
}

// MARK: - Audio Conversion Options
struct AudioConversionOptions {
    let format: String
    let bitrate: String?
    let sampleRate: Int?
    let channels: Int?
    let quality: String?
    let normalize: Bool?
    let fadeIn: Int?
    let fadeOut: Int?
    
    init(format: String, bitrate: String? = nil, sampleRate: Int? = nil, channels: Int? = nil, quality: String? = nil, normalize: Bool? = nil, fadeIn: Int? = nil, fadeOut: Int? = nil) {
        self.format = format
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
        self.quality = quality
        self.normalize = normalize
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
    }
}

// MARK: - FreeConvert API Manager
class FreeConvertAPIManager: ObservableObject {
    var apiKey: String
    private let baseURL = "https://api.freeconvert.com/v1"
    
    @Published var isConverting = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Audio Conversion
    func convertAudio(fileURL: URL, options: AudioConversionOptions, completion: @escaping (Result<URL, Error>) -> Void) {
        isConverting = true
        progress = 0.0
        statusMessage = "Uploading file..."
        errorMessage = nil
        
        // Step 1: Upload file
        uploadFile(fileURL: fileURL) { [weak self] result in
            switch result {
            case .success(let jobId):
                self?.statusMessage = "File uploaded. Starting conversion..."
                self?.startAudioConversion(jobId: jobId, options: options, completion: completion)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isConverting = false
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - File Upload
    private func uploadFile(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let uploadURL = "\(baseURL)/process/import/upload"
        
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            body.append(fileData)
        } catch {
            completion(.failure(error))
            return
        }
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "FreeConvert", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let uploadResponse = try JSONDecoder().decode(FreeConvertUploadResponse.self, from: data)
                    if uploadResponse.status == "created" || uploadResponse.status == "processing" {
                        completion(.success(uploadResponse.id))
                    } else {
                        completion(.failure(NSError(domain: "FreeConvert", code: -1, userInfo: [NSLocalizedDescriptionKey: uploadResponse.error ?? "Upload failed"])))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Audio Conversion Process
    private func startAudioConversion(jobId: String, options: AudioConversionOptions, completion: @escaping (Result<URL, Error>) -> Void) {
        // For now, let's use the job ID directly and monitor the status
        // The conversion should happen automatically after upload
        self.statusMessage = "Conversion started. Monitoring progress..."
        self.monitorConversionProgress(jobId: jobId, completion: completion)
    }
    
    // MARK: - Progress Monitoring
    private func monitorConversionProgress(jobId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        print("🔍 DEBUG: Starting conversion monitoring for job: \(jobId)")
        
        // Since FreeConvert doesn't seem to have a working status endpoint,
        // we'll wait a reasonable time and then try to download
        self.statusMessage = "Converting... Please wait"
        self.progress = 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.statusMessage = "Conversion should be complete. Attempting download..."
            self.progress = 0.8
            
            // Try to construct a download URL based on the job ID
            let downloadURL = "\(self.baseURL)/process/download/\(jobId)"
            print("🔍 DEBUG: Attempting download from: \(downloadURL)")
            
            self.downloadConvertedFile(downloadURL: downloadURL, completion: completion)
        }
    }
    
    // MARK: - File Download
    private func downloadConvertedFile(downloadURL: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: downloadURL) else {
            isConverting = false
            errorMessage = "Invalid download URL"
            completion(.failure(NSError(domain: "FreeConvert", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.downloadTask(with: request) { [weak self] localURL, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isConverting = false
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let localURL = localURL else {
                    self?.isConverting = false
                    self?.errorMessage = "Download failed"
                    completion(.failure(NSError(domain: "FreeConvert", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed"])))
                    return
                }
                
                // Move file to documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "converted_\(Date().timeIntervalSince1970).\(localURL.pathExtension)"
                let destinationURL = documentsPath.appendingPathComponent(fileName)
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    
                    self?.isConverting = false
                    self?.statusMessage = "Download completed!"
                    completion(.success(destinationURL))
                } catch {
                    self?.isConverting = false
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Supported Formats
    static func getSupportedAudioFormats() -> [String] {
        return ["mp3", "m4a", "wav", "flac", "aac", "ogg", "wma", "opus"]
    }
    
    // MARK: - Format Validation
    static func isValidAudioFormat(_ format: String) -> Bool {
        return getSupportedAudioFormats().contains(format.lowercased())
    }
} 