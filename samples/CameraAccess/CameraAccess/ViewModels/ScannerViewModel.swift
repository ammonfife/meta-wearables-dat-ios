/*
 * ScannerViewModel.swift
 * Manages coin scanning: grabs frames from glasses camera, sends to lkup.info,
 * and announces results via speech.
 */

import AVFoundation
import SwiftUI

@MainActor
class ScannerViewModel: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var lastResult: CoinIdentification?
    @Published var showResult: Bool = false

    private let streamVM: StreamSessionViewModel
    private let synthesizer = AVSpeechSynthesizer()
    private var lastScanTime: Date = .distantPast
    private let cooldown: TimeInterval = 3.0
    private var autoDismissTask: Task<Void, Never>?

    init(streamVM: StreamSessionViewModel) {
        self.streamVM = streamVM
    }

    func scan() {
        guard !isScanning else {
            BluetoothManager.log("scan() — already scanning, skipped")
            return
        }
        guard Date().timeIntervalSince(lastScanTime) >= cooldown else {
            BluetoothManager.log("scan() — cooldown active, skipped")
            return
        }
        guard let frame = streamVM.currentVideoFrame else {
            BluetoothManager.log("scan() — no video frame available")
            return
        }

        isScanning = true
        lastScanTime = Date()
        BluetoothManager.log("scan() — sending frame \(frame.size) to lkup.info/api/identify")

        Task {
            let result = await LkupService.shared.identify(image: frame)
            self.isScanning = false

            if let result {
                BluetoothManager.log("scan() — IDENTIFIED: \(result.name), grade=\(result.grade ?? "?"), market=\(result.prices?.marketplaceAvg.map { String(format: "$%.0f", $0) } ?? "?")")
                self.lastResult = result
                self.showResult = true
                speak(result)
                scheduleAutoDismiss()
            } else {
                BluetoothManager.log("scan() — identification FAILED (nil result)")
            }
        }
    }

    func dismissResult() {
        showResult = false
        autoDismissTask?.cancel()
    }

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled {
                self.showResult = false
            }
        }
    }

    private func speak(_ coin: CoinIdentification) {
        let grade = coin.grade ?? "ungraded"
        let price = coin.prices?.marketplaceAvg.map { String(format: "$%.0f", $0) } ?? "unknown"
        let text = "\(coin.name), \(grade), market value \(price)"

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
