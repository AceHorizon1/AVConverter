# Audio/Video Converter

A modern, native macOS application for converting audio and video files between popular formats, built with SwiftUI and featuring a comprehensive set of macOS-native features.

## Features

### Core Functionality
- **File Import**: Drag & drop or browse to import audio and video files
- **Format Conversion**: Convert between popular formats (MP4, MOV, MP3, M4A, WAV, FLAC, OGG, etc.)
- **Real-time Progress**: Live conversion progress with detailed status updates
- **Multiple Engines**: Choose between AVFoundation, FFmpeg, or FreeConvert API
- **Cloud Processing**: FreeConvert API for cloud-based conversions with advanced features

### Native macOS Features
- **Custom Menu Bar**: Native macOS menu with File, Edit, View, and Help menus
- **Toolbar**: Quick access to common actions with customizable toolbar
- **Preferences Window**: App settings and configuration management
- **Context Menus**: Right-click context menus for file operations
- **Enhanced Drag & Drop**: Native drag & drop support with visual feedback
- **Quick Look Integration**: Preview files before conversion
- **Share Sheet**: Native macOS share functionality
- **Spotlight Metadata**: Files are indexed and searchable in Spotlight
- **Accessibility**: Full VoiceOver and accessibility support
- **Touch Bar Support**: Custom Touch Bar controls on supported MacBooks
- **Window Management**: Proper window state management and restoration

### Advanced Features
- **Document-based Architecture**: Save and load conversion projects (.avproj files)
- **iCloud Sync**: Preferences and conversion history sync across devices
- **Metadata Editing**: View and edit file metadata
- **Conversion History**: Track and manage previous conversions
- **Batch Processing**: Convert multiple files simultaneously
- **Adaptive Appearance**: Automatic light/dark mode support

## Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 14.0 or later
- **FFmpeg**: Optional - install via Homebrew: `brew install ffmpeg` (for local conversions)
- **FreeConvert API Key**: Optional - get from [FreeConvert.com](https://www.freeconvert.com/api) (for cloud conversions)

## Installation

### Prerequisites
1. **For local conversions** (optional): Install FFmpeg:
   ```bash
   brew install ffmpeg
   ```

2. **For cloud conversions** (optional): Get a FreeConvert API key:
   - Visit [FreeConvert.com API](https://www.freeconvert.com/api)
   - Sign up for an account
   - Generate an API key
   - Configure it in the app settings

### Building from Source
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd "Audio and Video Converter"
   ```

2. Open the project in Xcode:
   ```bash
   open AudioVideoConverter.xcodeproj
   ```

3. Build and run the application (⌘+R)

## Usage

### Basic Conversion
1. Launch the app
2. Import files by dragging them into the app or using File → Import
3. Select your desired output format
4. Choose your conversion engine:
   - **AVFoundation**: Fast local conversion (limited formats)
   - **FFmpeg**: High-quality local conversion (requires FFmpeg installation)
   - **FreeConvert**: Cloud-based conversion with advanced features (requires API key)
5. Click "Convert" to start the process
6. Monitor progress in real-time
7. Find converted files in the specified output directory

### Advanced Features
- **Batch Conversion**: Select multiple files and convert them all at once
- **Metadata Editing**: Right-click files to view and edit metadata
- **Project Saving**: Save conversion projects for later use
- **History Management**: View and manage your conversion history

## Supported Formats

### Video Formats
- MP4, MOV, AVI, MKV, WMV, FLV, WebM, and more

### Audio Formats
- MP3, M4A, WAV, FLAC, AAC, OGG, WMA, OPUS, and more

## Architecture

The app is built using modern SwiftUI practices with:
- **Document-based Architecture**: Uses `FileDocument` protocol for project management
- **Native macOS Integration**: Leverages AppKit and SwiftUI for platform-specific features
- **Modular Design**: Clean separation of concerns with dedicated components
- **Error Handling**: Comprehensive error handling and user feedback

## Development

### Project Structure
- `AudioVideoConverterApp.swift`: Main app entry point
- `ContentView.swift`: Primary UI and app logic
- `ConverterDocument.swift`: Document-based state management
- Supporting files for localization, assets, and tests

### Key Dependencies
- SwiftUI for UI framework
- AVFoundation for media handling
- Core Data for data persistence
- Various macOS frameworks for native features
- FreeConvert API for cloud-based conversions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

For issues, feature requests, or questions, please open an issue on the repository. 