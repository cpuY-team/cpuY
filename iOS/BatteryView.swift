
import SwiftUI

struct BatteryView: View {
    @State private var batteryLevelText = ""
    @State private var batteryStatusText = ""
    @State private var batteryUsageText = ""

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    var body: some View {
        NavigationView {
            List {
                infoRow(label: "Niveau de batterie", value: batteryLevelText)
                infoRow(label: "État de la batterie", value: batteryStatusText)
                infoRow(label: "Temps d'utilisation", value: batteryUsageText)

                Text("Note: Depuis iOS 17, les apps n'ont plus accès au niveau exact de batterie. Il est arrondi par palier de 5%.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .navigationTitle("Batterie")
            .onAppear {
                updateBatteryInfo()
            }
            .onReceive(timer) { _ in
                updateBatteryInfo()
            }
        }
    }

    func updateBatteryInfo() {
        batteryLevelText = batteryLevel()
        batteryStatusText = batteryStatus()
        batteryUsageText = usageTime()
    }

    func batteryLevel() -> String {
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            return "Non disponible"
        } else {
            let percent = Int(level * 100)
            return "\(percent)%"
        }
    }

    func batteryStatus() -> String {
        switch UIDevice.current.batteryState {
        case .unknown:
            return "Inconnu"
        case .unplugged:
            return "Sur batterie"
        case .charging:
            return "En charge"
        case .full:
            return "Chargée"
        @unknown default:
            return "Inconnu"
        }
    }

    func usageTime() -> String {
        let batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel < 0 {
            return "Non disponible"
        }

        let batteryPercentage = batteryLevel * 100
        let fullUsageInMinutes = 8 * 60
        let remainingMinutes = Int((batteryPercentage / 100) * Float(fullUsageInMinutes))

        let hours = remainingMinutes / 60
        let minutes = remainingMinutes % 60

        return "\(hours)h \(minutes)m estimées restantes"
    }
}
