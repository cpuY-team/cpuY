import SwiftUI

struct CPUInfo {
    let name: String
    let frequency: String
    let cores: Int
}

struct CPUView: View {
    private let cpuData: [String: CPUInfo] = [
        // iPhone 7 / 7 Plus
        "iPhone9,1": CPUInfo(name: "A10 Fusion", frequency: "2.34 GHz", cores: 4),
        "iPhone9,2": CPUInfo(name: "A10 Fusion", frequency: "2.34 GHz", cores: 4),
        "iPhone9,3": CPUInfo(name: "A10 Fusion", frequency: "2.34 GHz", cores: 4),
        "iPhone9,4": CPUInfo(name: "A10 Fusion", frequency: "2.34 GHz", cores: 4),
        // iPhone 8 / 8 Plus
        "iPhone10,1": CPUInfo(name: "A11 Bionic", frequency: "2.39 GHz", cores: 6),
        "iPhone10,2": CPUInfo(name: "A11 Bionic", frequency: "2.39 GHz", cores: 6),
        // iPhone X
        "iPhone10,3": CPUInfo(name: "A11 Bionic", frequency: "2.39 GHz", cores: 6),
        "iPhone10,6": CPUInfo(name: "A11 Bionic", frequency: "2.39 GHz", cores: 6),
        // iPhone XR
        "iPhone11,8": CPUInfo(name: "A12 Bionic", frequency: "2.49 GHz", cores: 6),
        // iPhone XS / XS Max
        "iPhone11,2": CPUInfo(name: "A12 Bionic", frequency: "2.49 GHz", cores: 6),
        "iPhone11,6": CPUInfo(name: "A12 Bionic", frequency: "2.49 GHz", cores: 6),
        // iPhone 11
        "iPhone12,1": CPUInfo(name: "A13 Bionic", frequency: "2.65 GHz", cores: 6),
        // iPhone 11 Pro / Pro Max
        "iPhone12,3": CPUInfo(name: "A13 Bionic", frequency: "2.65 GHz", cores: 6),
        "iPhone12,5": CPUInfo(name: "A13 Bionic", frequency: "2.65 GHz", cores: 6),
        // iPhone SE (2nd gen)
        "iPhone12,8": CPUInfo(name: "A13 Bionic", frequency: "2.65 GHz", cores: 6),
        // iPhone 12 / 12 Mini
        "iPhone13,1": CPUInfo(name: "A14 Bionic", frequency: "3.1 GHz", cores: 6),
        "iPhone13,2": CPUInfo(name: "A14 Bionic", frequency: "3.1 GHz", cores: 6),
        // iPhone 12 Pro / Pro Max
        "iPhone13,3": CPUInfo(name: "A14 Bionic", frequency: "3.1 GHz", cores: 6),
        "iPhone13,4": CPUInfo(name: "A14 Bionic", frequency: "3.1 GHz", cores: 6),
        // iPhone 13 / 13 Mini
        "iPhone14,5": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        "iPhone14,4": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        // iPhone 13 Pro / Pro Max
        "iPhone14,2": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        "iPhone14,3": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        // iPhone SE (3rd gen)
        "iPhone14,6": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        // iPhone 14
        "iPhone14,7": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        // iPhone 14 Plus
        "iPhone14,8": CPUInfo(name: "A15 Bionic", frequency: "3.23 GHz", cores: 6),
        // iPhone 14 Pro / Pro Max
        "iPhone15,2": CPUInfo(name: "A16 Bionic", frequency: "3.46 GHz", cores: 6),
        "iPhone15,3": CPUInfo(name: "A16 Bionic", frequency: "3.46 GHz", cores: 6),
        // iPhone 15 / 15 Plus
        "iPhone15,4": CPUInfo(name: "A16 Bionic", frequency: "3.46 GHz", cores: 6),
        "iPhone15,5": CPUInfo(name: "A16 Bionic", frequency: "3.46 GHz", cores: 6),
        // iPhone 15 Pro / Pro Max
        "iPhone16,1": CPUInfo(name: "A17 Pro", frequency: "3.78 GHz", cores: 6),
        "iPhone16,2": CPUInfo(name: "A17 Pro", frequency: "3.78 GHz", cores: 6),
        // iPhone 16 / 16 Plus
        "iPhone17,1": CPUInfo(name: "A18", frequency: "3.90 GHz", cores: 6),
        "iPhone17,2": CPUInfo(name: "A18", frequency: "3.90 GHz", cores: 6),
        // iPhone 16 Pro / Pro Max
        "iPhone17,3": CPUInfo(name: "A18 Pro", frequency: "4.00 GHz", cores: 6),
        "iPhone17,4": CPUInfo(name: "A18 Pro", frequency: "4.00 GHz", cores: 6)
    ]

    private func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if let cpu = cpuData[modelIdentifier()] {
                    infoRow(label: "Puce", value: cpu.name)
                    infoRow(label: "Fréquence", value: cpu.frequency)
                    infoRow(label: "Cœurs", value: "\(cpu.cores)")
                } else {
                    Text("Informations CPU non disponibles pour ce modèle.")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("CPU")
        }
    }
}
