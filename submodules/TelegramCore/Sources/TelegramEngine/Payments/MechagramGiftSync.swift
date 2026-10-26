import Foundation
import Security
import Postbox
import SwiftSignalKit

// An installation publishes only its own preview ledger. This is not Telegram
// account authentication or a source of real NFT ownership/payment information.
private final class MechagramPinnedGiftSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let certificate = "MIIDLjCCAhagAwIBAgIUYEnb8DAPhP2iblx7d7785XHC9ukwDQYJKoZIhvcNAQELBQAwHjEcMBoGA1UEAwwTTWVjaGFncmFtIEdpZnQgU3luYzAeFw0yNjEwMjYxMjE1MTNaFw0zNjEwMjMxMjE1MTNaMB4xHDAaBgNVBAMME01lY2hhZ3JhbSBHaWZ0IFN5bmMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCVstCN/woocnJskkinwUdTM+2rhpM+hCJzXedXkrFNI35dNU5HslQYscEreTUVskJATLqzTZJDXR/0avv0uYx9ypFv+9ky5g2/z2ikg4+e79ry31d0gnFMYm5uoRtDomTrxiVGh/aDCFFcVuV5koNfQ+FDqZjJsCm0pUqtNbV2jccFPspwLjOkBldGZTgaNsLVy0orCPaNA0XLk7CCEvxMFsgfuYoCxdv0qeBeJaLl2/jB1g9UPe8azbEq94sxcu2nbLly/dx3Qommy7qKf/9hL3PT4YBH0CsU6PoSkHtTMCucdvQkcGh3n+U4WQnvLYCU/37V20gyv7psjTUkuns1AgMBAAGjZDBiMB0GA1UdDgQWBBS9RLwzWzXBWnHguq46OfBW7M/PxDAfBgNVHSMEGDAWgBS9RLwzWzXBWnHguq46OfBW7M/PxDAPBgNVHRMBAf8EBTADAQH/MA8GA1UdEQQIMAaHBB9NCzYwDQYJKoZIhvcNAQELBQADggEBAFIeexcreDPUh8WXijeeeurYBSY6OE3Aqs1dzC9TWMin24JV21RHfimYSAgDyFOxeigBYI0NguZ2KcpfrZqdTGvqc3tZlIKB2kFjPZ/HuceBMcdv1u2YkM7TJ7HIz4GHAv5iLQ6WFLTNSGVfKcUIRepE/iuhFuOv2H4iVI3MXbfWkVTJwODeAjZRGRNTmBftBBuD96EMczG4Jg/tcJ/APWH9MDCosdFnCErfTiyxgJrKBLfY6KRd+P+Y+NmW2OGIXlR1gK6ljPcUNJ6y1DfToW/VpCSjdoqXEoZnVIYpUtdhcFZdi+DNBz6/gudG3flZ9L/azU+G+EbB/SrFeNwk434="

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == "31.77.11.54",
              let trust = challenge.protectionSpace.serverTrust,
              let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = certificates.first,
              SecCertificateCopyData(leaf) as Data == Data(base64Encoded: Self.certificate) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class MechagramGiftSync {
    static let shared = MechagramGiftSync()
    private let queue = DispatchQueue(label: "mechagram.gift.sync")
    private let delegate = MechagramPinnedGiftSession()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self.delegate, delegateQueue: nil)
    }()
    private var refreshing = Set<Int64>()
    private var lastRefresh: [Int64: Date] = [:]
    private var uploading = false
    private let bootstrapLock = NSLock()
    private let outboxKey = "mechagram.giftSync.outbox.v1"
    private let identityKey = "mechagram.giftSync.identity.v1"

    func bootstrap(_ entries: [ProfileGiftsContext.State.StarGift], peerId: PeerId) {
        self.bootstrapLock.lock()
        let key = "mechagram.giftSync.bootstrapped.v1.\(peerId.toInt64())"
        if UserDefaults.standard.bool(forKey: key) { self.bootstrapLock.unlock(); return }
        UserDefaults.standard.set(true, forKey: key)
        self.bootstrapLock.unlock()
        self.publish(entries, peerId: peerId)
    }

    private func request(_ path: String, body: [String: Any]? = nil, authenticated: Bool = false, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: "https://31.77.11.54:8443" + path) else { completion(nil); return }
        var request = URLRequest(url: url)
        if let body {
            request.httpMethod = "POST"
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated {
            guard let identity = UserDefaults.standard.dictionary(forKey: self.identityKey), let installation = identity["installation"] as? String, let token = identity["token"] as? String else { completion(nil); return }
            request.setValue(installation, forHTTPHeaderField: "X-Mechagram-Installation")
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        self.session.dataTask(with: request) { data, response, _ in
            let valid = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            self.queue.async { completion(valid && (data?.count ?? 0) <= 8_000_000 ? data : nil) }
        }.resume()
    }

    func publish(_ entries: [ProfileGiftsContext.State.StarGift], peerId: PeerId) {
        // Build sanitized wrappers before crossing queues. In particular, do not
        // serialize sender IDs, message text, server references or payment data.
        var records: [String: [String: Any]] = [:]
        for entry in entries {
            guard case let .unique(gift) = entry.gift,
                  let data = try? JSONEncoder().encode(entry.withGift(.unique(gift.withAttributes(gift.attributes.filter { $0.attributeType != .originalInfo })))),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            let allowed: Set<String> = ["gift", "date", "nameHidden", "savedToProfile", "pinnedToTop", "canUpgrade", "upgradeSeparate", "isRefunded"]
            let sanitized = object.filter { allowed.contains($0.key) }
            guard let payload = try? JSONSerialization.data(withJSONObject: sanitized), payload.count <= 175_000 else { continue }
            records[String(gift.id)] = ["id": String(gift.id), "owner": String(peerId.toInt64()), "payload": payload.base64EncodedString(), "worn": mechagramLocalGiftIsWorn(peerId: peerId, giftId: gift.id)]
        }
        self.queue.async {
            var outbox = UserDefaults.standard.dictionary(forKey: self.outboxKey) ?? [:]
            for (id, record) in records { outbox[id] = record }
            UserDefaults.standard.set(outbox, forKey: self.outboxKey)
            self.flush()
        }
    }

    private func flush() {
        guard !self.uploading, let outbox = UserDefaults.standard.dictionary(forKey: self.outboxKey), let id = outbox.keys.sorted().first, let record = outbox[id] as? [String: Any] else { return }
        self.uploading = true
        if UserDefaults.standard.dictionary(forKey: self.identityKey) == nil {
            self.request("/v1/register", body: [:]) { data in
                self.uploading = false
                guard let data, let identity = (try? JSONSerialization.jsonObject(with: data)) as? [String: String], identity["installation"] != nil, identity["token"] != nil else { return }
                UserDefaults.standard.set(identity, forKey: self.identityKey)
                self.flush()
            }
            return
        }
        self.request("/v1/gift", body: record, authenticated: true) { data in
            self.uploading = false
            guard data != nil else { return } // Persist failed writes for the next refresh.
            var pending = UserDefaults.standard.dictionary(forKey: self.outboxKey) ?? [:]
            if let current = pending[id] as? NSDictionary, current.isEqual(to: record) { pending.removeValue(forKey: id) }
            UserDefaults.standard.set(pending, forKey: self.outboxKey)
            self.flush()
        }
    }

    func refresh(peerId: PeerId) {
        guard peerId.namespace == Namespaces.Peer.CloudUser else { return }
        self.queue.async {
            self.flush()
            let value = peerId.toInt64()
            guard !self.refreshing.contains(value), Date().timeIntervalSince(self.lastRefresh[value] ?? .distantPast) >= 10 else { return }
            self.refreshing.insert(value)
            self.lastRefresh[value] = Date()
            self.request("/v1/profile/\(value)") { data in
                self.refreshing.remove(value)
                guard let data, let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let records = result["gifts"] as? [[String: Any]] else { return }
                var entries: [ProfileGiftsContext.State.StarGift] = []
                var wornId = ""
                for record in records {
                    guard let raw = record["payload"] as? String, let payload = Data(base64Encoded: raw), let entry = try? JSONDecoder().decode(ProfileGiftsContext.State.StarGift.self, from: payload), entry.reference == nil,
                          case let .unique(gift) = entry.gift, case let .peerId(owner) = gift.owner, owner == peerId else { continue }
                    entries.append(entry)
                    if record["worn"] as? Bool == true { wornId = String(gift.id) }
                }
                let key = "mechagram.giftSync.cache.v1.\(value)"
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let wornKey = "mechagram.giftSync.worn.v1.\(value)"
                let movedKey = "mechagram.giftSync.moved.v1.\(value)"
                let moved = result["moved"] as? [String] ?? []
                guard let encoded = try? encoder.encode(entries), UserDefaults.standard.data(forKey: key) != encoded || UserDefaults.standard.string(forKey: wornKey) != wornId || UserDefaults.standard.stringArray(forKey: movedKey) != moved else { return }
                UserDefaults.standard.set(encoded, forKey: key)
                UserDefaults.standard.set(wornId, forKey: wornKey)
                UserDefaults.standard.set(moved, forKey: movedKey)
                NotificationCenter.default.post(name: Notification.Name("MechagramLocalProfileGiftsChanged"), object: nil)
            }
        }
    }
}

public func mechagramLocalGiftsChanged() -> Signal<Void, NoError> {
    return Signal { subscriber in
        subscriber.putNext(Void())
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name("MechagramLocalProfileGiftsChanged"), object: nil, queue: nil) { _ in subscriber.putNext(Void()) }
        return ActionDisposable { NotificationCenter.default.removeObserver(observer) }
    }
}
