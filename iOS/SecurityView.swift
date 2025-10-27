//
//  SecurityView.swift
//  cpuY
//
//  Created by Nathan  on 30/06/2025.
//


import SwiftUI
import LocalAuthentication

struct SecurityView: View {
    var body: some View {
        NavigationView {
            List {
                infoRow(label: "Authentification", value: authType())
                infoRow(label: "VPN actif", value: vpnStatus() ? "Oui" : "Non")
            }
            .navigationTitle("Sécurité")
        }
    }

    func authType() -> String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            default:
                return "Aucune"
            }
        }
        return "Aucune"
    }

    func vpnStatus() -> Bool {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as? [String: Any],
              let scopes = settings["__SCOPED__"] as? [String: Any] else {
            return false
        }
        for key in scopes.keys {
            if key.contains("tap") || key.contains("tun") || key.contains("ppp") {
                return true
            }
        }
        return false
    }
}
