//
//  NetworkView.swift
//  cpuY
//
//  Created by Nathan  on 30/06/2025.
//


import SwiftUI
import SystemConfiguration.CaptiveNetwork

struct NetworkView: View {
    var body: some View {
        NavigationView {
            List {
                infoRow(label: "Connexion", value: connectionType())
                infoRow(label: "Nom du Wi-Fi", value: wifiSSID() ?? "Non disponible")
                infoRow(label: "IP locale", value: localIPAddress() ?? "Non disponible")
            }
            .navigationTitle("Réseau")
        }
    }

    func connectionType() -> String {
        let reachability = try? Reachability()
        switch reachability?.connection {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellulaire"
        case .unavailable: return "Aucune"
        default: return "Inconnu"
        }
    }

    func wifiSSID() -> String? {
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    return interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
                }
            }
        }
        return nil
    }

    func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr else { continue }
                let addrFamily = interface.pointee.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6),
                   let name = String(validatingUTF8: interface.pointee.ifa_name),
                   name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.pointee.ifa_addr, socklen_t(interface.pointee.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
