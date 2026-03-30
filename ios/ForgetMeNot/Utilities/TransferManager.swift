import Foundation
import CoreImage.CIFilterBuiltins
import UIKit
import Compression

enum TransferManager {

    // MARK: - Generate QR for transfer OUT

    /// Generates a QR code UIImage from the full app export.
    /// Returns nil if data exceeds ~4KB QR practical limit.
    static func generateTransferQR(store: TaskStore, baseURL: String = "https://forgetmenot.lucianlabs.ca") -> (image: UIImage, url: String)? {
        guard let jsonData = store.exportJSON() else { return nil }

        // Compress then base64
        let encoded: String
        if let compressed = zlibCompress(jsonData) {
            encoded = compressed.base64EncodedString()
        } else {
            encoded = jsonData.base64EncodedString()
        }

        let url = "\(baseURL)/#import=\(encoded)"

        // QR codes max out around 4KB
        guard url.count <= 4000 else { return nil }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.utf8)
        filter.correctionLevel = "L"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up for display
        let scale = CGAffineTransform(scaleX: 8, y: 8)
        let scaled = ciImage.transformed(by: scale)

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return (UIImage(cgImage: cgImage), url)
    }

    /// Returns the data size description (for "too large" messaging)
    static func exportSizeKB(store: TaskStore) -> Int {
        guard let data = store.exportJSON() else { return 0 }
        return data.count / 1024
    }

    // MARK: - Import from transfer URL

    /// Parses a transfer URL (from QR scan, clipboard, or share).
    /// Handles both `#import=...` and `?import=...` formats.
    static func importFromURL(_ urlString: String, into store: TaskStore) -> Result<Int, TransferError> {
        // Extract the encoded payload
        let payload: String
        if let range = urlString.range(of: "#import=") {
            payload = String(urlString[range.upperBound...])
        } else if let range = urlString.range(of: "?import=") {
            payload = String(urlString[range.upperBound...])
        } else {
            return .failure(.noPayload)
        }

        // Try to decode: compressed first, then raw base64
        guard let base64Data = Data(base64Encoded: payload) else {
            return .failure(.invalidBase64)
        }

        let jsonData: Data
        if let decompressed = zlibDecompress(base64Data) {
            jsonData = decompressed
        } else {
            // Might be uncompressed — treat the base64-decoded bytes as UTF-8 JSON directly
            jsonData = base64Data
        }

        do {
            try store.importJSON(jsonData)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let payload = try? decoder.decode(ImportCount.self, from: jsonData) {
                return .success(payload.tasks?.count ?? 0)
            }
            return .success(store.tasks.count)
        } catch {
            return .failure(.importFailed(error.localizedDescription))
        }
    }

    /// Imports from raw JSON data (file import, clipboard JSON)
    static func importFromJSON(_ data: Data, into store: TaskStore) -> Result<Int, TransferError> {
        do {
            try store.importJSON(data)
            return .success(store.tasks.count)
        } catch {
            return .failure(.importFailed(error.localizedDescription))
        }
    }

    // MARK: - Clipboard helpers

    static func copyTransferLink(store: TaskStore, baseURL: String = "https://forgetmenot.lucianlabs.ca") -> Bool {
        guard let jsonData = store.exportJSON() else { return false }

        let encoded: String
        if let compressed = zlibCompress(jsonData) {
            encoded = compressed.base64EncodedString()
        } else {
            encoded = jsonData.base64EncodedString()
        }

        let url = "\(baseURL)/#import=\(encoded)"
        UIPasteboard.general.string = url
        return true
    }

    static func importFromClipboard(into store: TaskStore) -> Result<Int, TransferError>? {
        guard let text = UIPasteboard.general.string else { return nil }

        // Check if it's a transfer URL
        if text.contains("#import=") || text.contains("?import=") {
            return importFromURL(text, into: store)
        }

        // Check if it's raw JSON
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            guard let data = text.data(using: .utf8) else { return .failure(.invalidBase64) }
            return importFromJSON(data, into: store)
        }

        return nil
    }

    // MARK: - Compression (zlib, compatible with web CompressionStream('deflate'))

    private static func zlibCompress(_ data: Data) -> Data? {
        let capacity = data.count + 512
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { dst.deallocate() }

        let size = data.withUnsafeBytes { src -> Int in
            guard let srcBase = src.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_encode_buffer(dst, capacity, srcBase, data.count, nil, COMPRESSION_ZLIB)
        }

        guard size > 0 else { return nil }
        return Data(bytes: dst, count: size)
    }

    private static func zlibDecompress(_ data: Data) -> Data? {
        // Start with 8x buffer, retry larger if needed
        for multiplier in [8, 16, 32, 64] {
            let capacity = data.count * multiplier
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            defer { dst.deallocate() }

            let size = data.withUnsafeBytes { src -> Int in
                guard let srcBase = src.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(dst, capacity, srcBase, data.count, nil, COMPRESSION_ZLIB)
            }

            if size > 0 && size < capacity {
                return Data(bytes: dst, count: size)
            }
        }
        return nil
    }
}

enum TransferError: Error, LocalizedError {
    case noPayload
    case invalidBase64
    case importFailed(String)
    case tooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .noPayload: return "No import data found in URL"
        case .invalidBase64: return "Could not decode transfer data"
        case .importFailed(let msg): return "Import failed: \(msg)"
        case .tooLarge(let kb): return "Data is \(kb)KB — too large for QR (max ~4KB)"
        }
    }
}

private struct ImportCount: Codable {
    var tasks: [FMNTask]?
}
