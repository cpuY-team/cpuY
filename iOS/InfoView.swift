import SwiftUI
import AVKit

struct InfoView: View {
    @State private var showEasterEgg = false
    @State private var tapCount = 0

    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    tapCount += 1
                    if tapCount >= 10 {
                        showEasterEgg = true
                        tapCount = 0
                    }
                }) {
                    infoRow(label: "Modèle", value: modelName())
                }

                infoRow(label: "Version iOS", value: "iOS \(UIDevice.current.systemVersion)")
                infoRow(label: "Capacité", value: storageCapacity())
                infoRow(label: "Dynamic Island", value: hasDynamicIsland() ? "Oui" : "Non")
            }
            .navigationTitle("Informations")
            .sheet(isPresented: $showEasterEgg) {
                if let url = Bundle.main.url(forResource: "egg", withExtension: "mp4") {
                    VideoPlayer(player: AVPlayer(url: url))
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Text("Vidéo introuvable.")
                }
            }
        }
    }

    func modelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        let modelMap: [String: String] = [
            "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone16,4": "iPhone 16",
            "iPhone16,5": "iPhone 16 Plus",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max"
        ]

        return modelMap[machine] ?? machine
    }

    func storageCapacity() -> String {
        if let totalSpace = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemSize] as? NSNumber {
            let totalGB = Double(truncating: totalSpace) / pow(1024, 3)
            return String(format: "%.0f Go", totalGB)
        }
        return "Inconnu"
    }

    func hasDynamicIsland() -> Bool {
        let modelsWithIsland = [
            "iPhone15,2", "iPhone15,3", // iPhone 14 Pro / Pro Max
            "iPhone16,1", "iPhone16,2", // iPhone 15 Pro / Pro Max
            "iPhone17,1", "iPhone17,2"  // iPhone 16 Pro / Pro Max
        ]
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return modelsWithIsland.contains(machine)
    }
}
