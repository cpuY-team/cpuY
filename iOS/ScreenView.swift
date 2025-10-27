//
//  ScreenView.swift
//  cpuY
//
//  Created by Nathan  on 30/06/2025.
//


import SwiftUI

struct ScreenView: View {
    var body: some View {
        NavigationView {
            List {
                infoRow(label: "Résolution", value: "\(Int(UIScreen.main.nativeBounds.width)) x \(Int(UIScreen.main.nativeBounds.height))")
                infoRow(label: "Taux max", value: refreshRate())
                infoRow(label: "True Tone", value: isTrueToneAvailable() ? "Oui" : "Non")
                infoRow(label: "Luminosité", value: "\(Int(UIScreen.main.brightness * 100))%")
            }
            .navigationTitle("Écran")
        }
    }

    func refreshRate() -> String {
        if #available(iOS 15.0, *) {
            let maxHz = UIScreen.main.maximumFramesPerSecond
            return "\(maxHz) Hz"
        } else {
            return "60 Hz"
        }
    }

    func isTrueToneAvailable() -> Bool {
        UIScreen.main.traitCollection.displayGamut == .P3
    }
}
