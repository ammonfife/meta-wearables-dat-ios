/*
 * lkup.info Coin Identification Service
 * Posts camera frames to lkup.info API for AI-powered coin identification and pricing.
 */

import Foundation
import UIKit

struct CoinPrices: Codable {
    let melt: Double?
    let base: Double?
    let marketplaceAvg: Double?
    let guide: Double?
    let retail: Double?

    enum CodingKeys: String, CodingKey {
        case melt, base, guide, retail
        case marketplaceAvg = "marketplace_avg"
    }
}

struct CoinIdentification: Codable {
    let coinId: String?
    let name: String
    let year: String?
    let mint: String?
    let grade: String?
    let denomination: String?
    let metal: String?
    let prices: CoinPrices?

    enum CodingKeys: String, CodingKey {
        case name, year, mint, grade, denomination, metal, prices
        case coinId = "coin_id"
    }
}

actor LkupService {
    static let shared = LkupService()

    private let baseURL = "https://lkup.info/api/identify"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    func identify(image: UIImage) async -> CoinIdentification? {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            let decoder = JSONDecoder()
            return try decoder.decode(CoinIdentification.self, from: data)
        } catch {
            #if DEBUG
            NSLog("[lkup] Identification failed: \(error)")
            #endif
            return nil
        }
    }
}
