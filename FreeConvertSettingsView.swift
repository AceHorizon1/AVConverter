import SwiftUI

struct FreeConvertSettingsView: View {
    @AppStorage("freeconvert_api_key") private var apiKey: String = ""
    @AppStorage("freeconvert_enabled") private var isEnabled: Bool = false
    @AppStorage("freeconvert_auto_fallback") private var autoFallback: Bool = true
    @AppStorage("freeconvert_quality") private var quality: String = "high"
    @AppStorage("freeconvert_normalize") private var normalize: Bool = false
    @AppStorage("freeconvert_fade_in") private var fadeIn: Int = 0
    @AppStorage("freeconvert_fade_out") private var fadeOut: Int = 0
    
    @State private var showingAPIKeyAlert = false
    @State private var testResult: String = ""
    @State private var isTesting = false
    
    private let qualityOptions = ["low", "medium", "high", "very_high"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("FreeConvert API Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configure cloud-based audio conversion with advanced features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)
                
                // Main Configuration Section
                VStack(alignment: .leading, spacing: 16) {
                    // Enable/Disable Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable FreeConvert API")
                                .font(.headline)
                            Text("Use cloud-based conversion instead of local processing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $isEnabled)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    if isEnabled {
                        // API Key Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("API Key Configuration")
                                    .font(.headline)
                                Spacer()
                                Button("Get API Key") {
                                    NSWorkspace.shared.open(URL(string: "https://www.freeconvert.com/api")!)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            SecureField("Enter your FreeConvert API key", text: $apiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: .infinity)
                            
                            if !apiKey.isEmpty {
                                HStack {
                                    Button("Test API Key") {
                                        testAPIKey()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(isTesting)
                                    
                                    if isTesting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Spacer()
                                    
                                    if !testResult.isEmpty {
                                        Text(testResult)
                                            .font(.caption)
                                            .foregroundColor(testResult.contains("Success") ? .green : .red)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                        
                        if !apiKey.isEmpty {
                            // Conversion Settings
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Conversion Settings")
                                    .font(.headline)
                                
                                VStack(spacing: 12) {
                                    // Auto Fallback
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Auto Fallback")
                                                .font(.subheadline)
                                            Text("Fall back to local conversion if cloud fails")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $autoFallback)
                                    }
                                    
                                    Divider()
                                    
                                    // Quality Setting
                                    HStack {
                                        Text("Quality")
                                            .font(.subheadline)
                                        Spacer()
                                        Picker("Quality", selection: $quality) {
                                            ForEach(qualityOptions, id: \.self) { option in
                                                Text(option.capitalized)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .frame(width: 120)
                                    }
                                    
                                    Divider()
                                    
                                    // Normalize Audio
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Normalize Audio")
                                                .font(.subheadline)
                                            Text("Normalize audio levels for consistent volume")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $normalize)
                                    }
                                    
                                    Divider()
                                    
                                    // Fade Effects
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Fade In")
                                                .font(.subheadline)
                                            Text("Fade in duration in seconds")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Stepper(value: $fadeIn, in: 0...30) {
                                            Text("\(fadeIn)s")
                                        }
                                        .frame(width: 100)
                                    }
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Fade Out")
                                                .font(.subheadline)
                                            Text("Fade out duration in seconds")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Stepper(value: $fadeOut, in: 0...30) {
                                            Text("\(fadeOut)s")
                                        }
                                        .frame(width: 100)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                            
                            // Supported Formats
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Supported Audio Formats")
                                    .font(.headline)
                                
                                Text("FreeConvert API supports the following audio formats:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(FreeConvertAPIManager.getSupportedAudioFormats(), id: \.self) { format in
                                        Text(format.uppercased())
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.05))
                            .cornerRadius(8)
                            
                            // Benefits
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Benefits")
                                    .font(.headline)
                                
                                VStack(spacing: 8) {
                                    BenefitRow(icon: "cloud", title: "Cloud Processing", description: "No local dependencies required")
                                    BenefitRow(icon: "speedometer", title: "Fast Processing", description: "High-performance cloud servers")
                                    BenefitRow(icon: "slider.horizontal.3", title: "Advanced Options", description: "Audio effects, normalization, and more")
                                    BenefitRow(icon: "network", title: "Reliable", description: "99.9% uptime with automatic retries")
                                }
                            }
                            .padding()
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500, maxHeight: 700)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func testAPIKey() {
        isTesting = true
        testResult = "Testing API key..."
        
        let apiManager = FreeConvertAPIManager(apiKey: apiKey)
        
        // Create a simple test file
        let testData = "test".data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        
        do {
            try testData.write(to: tempURL)
            
            let options = AudioConversionOptions(format: "mp3")
            apiManager.convertAudio(fileURL: tempURL, options: options) { result in
                DispatchQueue.main.async {
                    isTesting = false
                    
                    switch result {
                    case .success(_):
                        testResult = "Success: API key is valid!"
                    case .failure(let error):
                        if error.localizedDescription.contains("401") || error.localizedDescription.contains("unauthorized") {
                            testResult = "Error: Invalid API key"
                        } else {
                            testResult = "Error: \(error.localizedDescription)"
                        }
                    }
                    
                    // Clean up test file
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
        } catch {
            isTesting = false
            testResult = "Error: Could not create test file"
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    FreeConvertSettingsView()
} 