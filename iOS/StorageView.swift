import SwiftUI

struct StorageView: View {
    @State private var totalStorage: String = "Chargement..."
    @State private var usedStorage: String = "Chargement..."
    @State private var freeStorage: String = "Chargement..."
    @State private var usedPercentage: Double = 0.0

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            List {
                VStack(alignment: .leading) {
                    Text("Utilisation du stockage")
                        .font(.headline)
                    ProgressView(value: usedPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.vertical, 5)
                }

                infoRow(label: "Stockage utilisé", value: usedStorage)
                infoRow(label: "Stockage libre", value: freeStorage)
                infoRow(label: "Stockage total", value: totalStorage)

                Text("Les valeurs sont estimées et mises à jour automatiquement toutes les 2 secondes.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .navigationTitle("Stockage")
            .onAppear {
                updateStorageInfo()
            }
            .onReceive(timer) { _ in
                updateStorageInfo()
            }
        }
    }

    func updateStorageInfo() {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let totalSpace = attributes[.systemSize] as? NSNumber,
           let freeSpace = attributes[.systemFreeSize] as? NSNumber {

            let total = Double(truncating: totalSpace) / (1024 * 1024 * 1024)
            let free = Double(truncating: freeSpace) / (1024 * 1024 * 1024)
            let used = total - free
            let percentUsed = used / total

            totalStorage = String(format: "%.2f Go", total)
            freeStorage = String(format: "%.2f Go", free)
            usedStorage = String(format: "%.2f Go", used)
            usedPercentage = percentUsed
        } else {
            totalStorage = "Erreur"
            freeStorage = "Erreur"
            usedStorage = "Erreur"
            usedPercentage = 0.0
        }
    }
}
