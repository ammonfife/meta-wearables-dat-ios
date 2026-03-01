/*
 * BluetoothManager.swift
 * Proactively requests Bluetooth permission, scans for nearby BLE devices,
 * and displays them (glasses, barcode scanners, etc.)
 */

import CoreBluetooth
import Foundation
import Combine
import Network

struct DiscoveredNetworkService: Identifiable {
    let id = UUID()
    let name: String
    let type: String
}

struct DiscoveredDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

class BluetoothManager: NSObject, ObservableObject {
    
    // File logger - writes to Documents/lkup_log.txt for remote retrieval
    static func log(_ msg: String) {
        let formatted = "[lkup] \(msg)"
        NSLog("%@", formatted)
        
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logFile = docs.appendingPathComponent("lkup_log.txt")
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "\(timestamp) \(formatted)\n"
            if fm.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(line.data(using: .utf8)!)
                    handle.closeFile()
                }
            } else {
                try? line.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }

    static let shared = BluetoothManager()
    
    @Published var authorizationStatus: CBManagerAuthorization = .notDetermined
    @Published var isScanning = false
    @Published var isPoweredOn = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var statusMessage = "Initializing Bluetooth..."
    @Published var networkServices: [DiscoveredNetworkService] = []
    @Published var networkStatus = "Not scanned"
    
    private var centralManager: CBCentralManager!
    private var scanTimer: Timer?
    private var netBrowser: NWBrowser?
    private var bonjourBrowsers: [NetServiceBrowser] = []
    private var bonjourDelegate: BonjourDelegate?
    
    override init() {
        super.init()
        // This triggers the BT permission prompt
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
        BluetoothManager.log("BluetoothManager initialized — this triggers permission request")
        
        // Trigger local network permission by browsing for services
        startNetworkDiscovery()
    }
    
    func startNetworkDiscovery() {
        networkStatus = "Scanning network..."
        networkServices.removeAll()
        
        // Use NetServiceBrowser to trigger the Local Network permission prompt
        // and discover printers/services
        let delegate = BonjourDelegate { [weak self] services in
            DispatchQueue.main.async {
                self?.networkServices = services
                self?.networkStatus = "Found \(services.count) service(s)"
            }
        }
        self.bonjourDelegate = delegate
        
        let serviceTypes = ["_ipp._tcp.", "_ipps._tcp.", "_pdl-datastream._tcp.", "_printer._tcp.", "_http._tcp."]
        for type in serviceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = delegate
            browser.searchForServices(ofType: type, inDomain: "local.")
            bonjourBrowsers.append(browser)
        }
        
        BluetoothManager.log("Started network service discovery (triggers Local Network permission)")
        
        // Stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.bonjourBrowsers.forEach { $0.stop() }
            if self?.networkServices.isEmpty == true {
                self?.networkStatus = "No network services found"
            }
        }
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            BluetoothManager.log("BT not powered on (state: \(centralManager.state.rawValue)), can't scan")
            statusMessage = "Bluetooth not available (state: \(centralManager.state.rawValue))"
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        statusMessage = "Scanning for devices..."
        BluetoothManager.log("Starting BLE scan")
        
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // Stop after 15 seconds
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = "Found \(discoveredDevices.count) device(s)"
        BluetoothManager.log("Stopped BLE scan. Found \(discoveredDevices.count) devices")
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        authorizationStatus = CBCentralManager.authorization
        isPoweredOn = central.state == .poweredOn
        
        BluetoothManager.log("BT state changed: \(central.state.rawValue), auth: \(CBCentralManager.authorization.rawValue)")
        
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
            // Auto-scan on first power on
            startScanning()
        case .poweredOff:
            statusMessage = "Bluetooth is off — turn it on in Settings"
        case .unauthorized:
            statusMessage = "Bluetooth permission denied — enable in Settings → lkup Scanner"
        case .unsupported:
            statusMessage = "Bluetooth not supported on this device"
        case .resetting:
            statusMessage = "Bluetooth resetting..."
        case .unknown:
            statusMessage = "Bluetooth initializing..."
        @unknown default:
            statusMessage = "Unknown Bluetooth state"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        
        // Only show named devices (skip anonymous ones)
        guard let deviceName = name, !deviceName.isEmpty else { return }
        
        // Update existing or add new
        if let idx = discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            discoveredDevices[idx] = DiscoveredDevice(id: peripheral.identifier, name: deviceName, rssi: RSSI.intValue, peripheral: peripheral)
        } else {
            let device = DiscoveredDevice(id: peripheral.identifier, name: deviceName, rssi: RSSI.intValue, peripheral: peripheral)
            discoveredDevices.append(device)
            BluetoothManager.log("Found device: \(deviceName) (RSSI: \(RSSI))")
        }
        
        // Sort by signal strength
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }
}

// MARK: - Bonjour Service Discovery Delegate

class BonjourDelegate: NSObject, NetServiceBrowserDelegate {
    private var found: [DiscoveredNetworkService] = []
    private let onUpdate: ([DiscoveredNetworkService]) -> Void
    
    init(onUpdate: @escaping ([DiscoveredNetworkService]) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let svc = DiscoveredNetworkService(name: service.name, type: service.type)
        BluetoothManager.log("Found network service: \(service.name) (\(service.type))")
        
        // Avoid duplicates by name
        if !found.contains(where: { $0.name == service.name && $0.type == service.type }) {
            found.append(svc)
        }
        
        if !moreComing {
            onUpdate(found)
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        found.removeAll { $0.name == service.name && $0.type == service.type }
        if !moreComing {
            onUpdate(found)
        }
    }
}
