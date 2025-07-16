import SwiftUI
import UniformTypeIdentifiers

@main
struct AudioVideoConverterApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { ConverterDocument() }) { file in
            ContentView(document: file.$document)
        }
    }
} 