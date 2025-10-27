import SwiftUI

struct OtherView: View {
    var body: some View {
        NavigationView {
            List {
                infoRow(label: "Processeur", value: cpuName())
                infoRow(label: "Uptime", value: getUptime())
                infoRow(label: "Date", value: getCurrentDate())
            }
            .navigationTitle("Autres")
        }
    }
}
