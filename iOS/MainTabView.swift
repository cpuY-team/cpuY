import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            InfoView()
                .tabItem {
                    Label("Infos", systemImage: "iphone")
                }

            BatteryView()
                .tabItem {
                    Label("Batterie", systemImage: "battery.75")
                }

            StorageView()
                .tabItem {
                    Label("Stockage", systemImage: "externaldrive")
                }

            RAMView()
                .tabItem {
                    Label("RAM", systemImage: "memorychip")
                }

            CPUView()
                .tabItem {
                    Label("CPU", systemImage: "cpu")
                }

            NetworkView()
                .tabItem {
                    Label("Réseau", systemImage: "wifi")
                }

            ScreenView()
                .tabItem {
                    Label("Écran", systemImage: "display")
                }

            SecurityView()
                .tabItem {
                    Label("Sécurité", systemImage: "lock.shield")
                }
        }
    }
}
