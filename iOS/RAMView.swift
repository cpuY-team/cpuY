import SwiftUI

struct RAMView: View {
    @State private var usedMemory: String = "Chargement..."
    @State private var freeMemory: String = "Chargement..."
    @State private var totalMemory: String = "Chargement..."
    @State private var usagePercentage: Double = 0.0

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            List {
                VStack(alignment: .leading) {
                    Text("Utilisation de la RAM")
                        .font(.headline)
                    ProgressView(value: usagePercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .padding(.vertical, 5)
                }

                infoRow(label: "RAM utilisée", value: usedMemory)
                infoRow(label: "RAM libre", value: freeMemory)
                infoRow(label: "RAM totale", value: totalMemory)

                Text("La mémoire est estimée en Go et mise à jour toutes les 2 secondes.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .navigationTitle("RAM")
            .onAppear {
                updateMemoryInfo()
            }
            .onReceive(timer) { _ in
                updateMemoryInfo()
            }
        }
    }

    func updateMemoryInfo() {
        let total = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(total) / 1073741824.0

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vmStats) / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let free = Double(vmStats.free_count + vmStats.inactive_count) * Double(vm_page_size) / 1073741824.0
            let used = totalGB - free

            usedMemory = String(format: "%.2f Go", used)
            freeMemory = String(format: "%.2f Go", free)
            totalMemory = String(format: "%.2f Go", totalGB)
            usagePercentage = used / totalGB
        } else {
            usedMemory = "Erreur"
            freeMemory = "Erreur"
            totalMemory = String(format: "%.2f Go", totalGB)
            usagePercentage = 0.0
        }
    }
}
