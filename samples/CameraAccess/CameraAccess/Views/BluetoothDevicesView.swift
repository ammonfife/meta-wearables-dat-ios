/*
 * BluetoothDevicesView.swift
 * Shows BT permission status, nearby devices, and scan controls.
 */

import CoreBluetooth
import SwiftUI

struct BluetoothDevicesView: View {
    @ObservedObject var btManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Status header
            HStack {
                Image(systemName: btManager.isPoweredOn ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(btManager.isPoweredOn ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Bluetooth")
                        .font(.headline)
                    Text(btManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Auth badge
                authBadge
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Scan button
            if btManager.isPoweredOn {
                Button(action: {
                    if btManager.isScanning {
                        btManager.stopScanning()
                    } else {
                        btManager.startScanning()
                    }
                }) {
                    HStack {
                        if btManager.isScanning {
                            ProgressView()
                                .tint(.white)
                            Text("Scanning...")
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Scan for Devices")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(btManager.isScanning ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            // Device list
            if !btManager.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nearby Devices (\(btManager.discoveredDevices.count))")
                        .font(.subheadline.bold())
                        .padding(.horizontal)
                    
                    ForEach(btManager.discoveredDevices) { device in
                        HStack {
                            Image(systemName: iconFor(device.name))
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.body.bold())
                                Text("Signal: \(signalLabel(device.rssi))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            signalBars(device.rssi)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            } else if !btManager.isScanning && btManager.isPoweredOn {
                Text("No devices found. Make sure glasses or scanner are nearby and awake.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            // Network services section
            if !btManager.networkServices.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text("Network Services (\(btManager.networkServices.count))")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal)
                    
                    ForEach(btManager.networkServices) { svc in
                        HStack {
                            Image(systemName: networkIcon(svc.type))
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(svc.name)
                                    .font(.body.bold())
                                Text(friendlyType(svc.type))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.gray)
                    Text(btManager.networkStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private func networkIcon(_ type: String) -> String {
        if type.contains("ipp") || type.contains("printer") || type.contains("pdl") {
            return "printer.fill"
        } else if type.contains("http") {
            return "globe"
        }
        return "network"
    }
    
    private func friendlyType(_ type: String) -> String {
        if type.contains("ipps") { return "Printer (secure)" }
        if type.contains("ipp") { return "Printer (AirPrint)" }
        if type.contains("pdl") { return "Printer (raw)" }
        if type.contains("printer") { return "Printer" }
        if type.contains("http") { return "Web service" }
        return type
    }
    
    private var authBadge: some View {
        let (color, text): (Color, String) = {
            switch btManager.authorizationStatus {
            case .allowedAlways: return (.green, "Allowed")
            case .denied: return (.red, "Denied")
            case .restricted: return (.orange, "Restricted")
            case .notDetermined: return (.yellow, "Pending")
            @unknown default: return (.gray, "Unknown")
            }
        }()
        
        return Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    private func iconFor(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("ray-ban") || lower.contains("glasses") || lower.contains("meta") {
            return "eyeglasses"
        } else if lower.contains("scanner") || lower.contains("barcode") || lower.contains("symbol") || lower.contains("zebra") {
            return "barcode.viewfinder"
        } else if lower.contains("keyboard") {
            return "keyboard"
        } else if lower.contains("airpod") || lower.contains("headphone") || lower.contains("beats") {
            return "headphones"
        } else if lower.contains("watch") {
            return "applewatch"
        }
        return "wave.3.right"
    }
    
    private func signalLabel(_ rssi: Int) -> String {
        if rssi > -50 { return "Excellent" }
        if rssi > -70 { return "Good" }
        if rssi > -85 { return "Fair" }
        return "Weak"
    }
    
    private func signalBars(_ rssi: Int) -> some View {
        let bars: Int = {
            if rssi > -50 { return 4 }
            if rssi > -65 { return 3 }
            if rssi > -80 { return 2 }
            return 1
        }()
        
        return HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i <= bars ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(i * 4 + 4))
            }
        }
    }
}
