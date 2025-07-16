import SwiftUI

struct PreferencesView: View {
    @AppStorage("defaultAppearance", store: UserDefaults(suiteName: iCloudSuite)) private var defaultAppearance: String = "System"
    @AppStorage("defaultOutputFolder", store: UserDefaults(suiteName: iCloudSuite)) private var defaultOutputFolder: String = ""

    var body: some View {
        Form {
            Picker("Appearance", selection: $defaultAppearance) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
            TextField("Default Output Folder", text: $defaultOutputFolder)
        }
        .padding()
        .frame(width: 350)
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
} 