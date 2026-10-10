import Foundation
import Combine
import CryptoKit
import SwiftUI
import Security

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRevalidating: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var enteredKey: String = ""

    private enum StorageKeys: String {
        case hwid = "com.bypass7.proxy.hwid"
        case isLoggedIn = "com.bypass7.proxy.loggedIn"
    }

    private var storedHWID: String {
        get { UserDefaults.standard.string(forKey: StorageKeys.hwid.rawValue) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: StorageKeys.hwid.rawValue) }
    }

    private var hasValidSession: Bool {
        get { UserDefaults.standard.bool(forKey: StorageKeys.isLoggedIn.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKeys.isLoggedIn.rawValue) }
    }

    private let endpoint = URL(string: "https://kaygen-final.vercel.app/api/public/validate")!
    private let applicationID = "cc9389c9-f2b2-412b-999c-f7bc3ad30a1b"

    init() {
        // A persisted flag is never trusted on its own: a saved license must be
        // revalidated against the backend before the user session is restored.
        if !savedLicenseKey.isEmpty && !storedHWID.isEmpty {
            isRevalidating = true
            Task { await revalidateSavedLicense() }
        }
    }

    var deviceHWID: String {
        if !storedHWID.isEmpty { return storedHWID }
        let hwID = generateDeviceHWID()
        storedHWID = hwID
        return hwID
    }

    private func generateDeviceHWID() -> String {
        let identifiers = [
            ProcessInfo.processInfo.operatingSystemVersionString,
            ProcessInfo.processInfo.hostName,
            Locale.current.identifier,
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        ]
        let combined = identifiers.joined(separator: "|")
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func login() async {
        guard !isRevalidating else { return }
        let trimmed = enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Por favor, digite sua key"
            showError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        let body: [String: Any] = [
            "key": trimmed,
            "hwid": deviceHWID,
            "application_id": applicationID
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        log("[AUTH] POST url=\(endpoint.absoluteString) bodyFields=key,hwid,application_id")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("[AUTH] POST network_error=\(error.localizedDescription)")
            errorMessage = offlineMessage(for: error)
            showError = true
            return
        }

        guard let http = response as? HTTPURLResponse else {
            log("[AUTH] POST response=non_http")
            errorMessage = "Erro de conexão com o servidor"
            showError = true
            return
        }

        log("[AUTH] POST http_status=\(http.statusCode)")
        let payload = Self.parseJSONObject(data)

        switch http.statusCode {
        case 200...299:
            handleSuccess(licenseKey: trimmed)
        case 400:
            let raw = Self.stringFromPayload(payload, keys: ["error", "message"])
            errorMessage = raw.isEmpty ? "Requisição inválida. Verifique sua key." : raw
            showError = true
        case 401:
            errorMessage = "Autenticação falhou. Verifique sua key."
            showError = true
        case 403:
            errorMessage = "Acesso negado. Key bloqueada ou HWID incompatível."
            showError = true
        case 404:
            let code = Self.stringFromPayload(payload, keys: ["code"])
            if code.uppercased() == "LICENSE_NOT_FOUND" {
                errorMessage = "Chave não encontrada. Verifique sua key."
            } else {
                let raw = Self.stringFromPayload(payload, keys: ["error", "message"])
                errorMessage = raw.isEmpty
                    ? "Código de resposta inesperado: 404"
                    : raw
            }
            showError = true
        case 429:
            errorMessage = "Muitas requisições. Tente novamente mais tarde."
            showError = true
        case 500...599:
            errorMessage = "Erro no servidor. Tente novamente."
            showError = true
        default:
            let raw = Self.stringFromPayload(payload, keys: ["error", "message"])
            errorMessage = raw.isEmpty
                ? "Código de resposta inesperado: \(http.statusCode)"
                : raw
            showError = true
        }
    }

    /// Kaygen reports successful validation with HTTP 2xx; its documented
    /// response contains status and expires_at, without requiring `valid`.
    private func handleSuccess(licenseKey: String) {
        isAuthenticated = true
        hasValidSession = true
        persistLicenseKey(licenseKey)
        isRevalidating = false
        showError = false
        errorMessage = ""
        enteredKey = ""
    }

    private func denyLogin(with payload: [String: Any]) {
        errorMessage = denialReason(from: payload)
        showError = true
        enteredKey = ""
    }

    private enum LicenseStatus: Equatable {
        case valid
        case denied(String)
        case offline(String)
    }

    /// Validates the license that was saved during the last successful login.
    /// Uses the exact same endpoint and contract as login; preserves HWID.
    private func validateSavedLicense() async -> LicenseStatus {
        let key = savedLicenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return .denied("Chave não encontrada. Verifique sua key.")
        }

        let body: [String: Any] = [
            "key": key,
            "hwid": deviceHWID,
            "application_id": applicationID
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        log("[AUTH] revalidation POST url=\(endpoint.absoluteString) bodyFields=key,hwid,application_id")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("[AUTH] revalidation network_error=\(error.localizedDescription)")
            return .offline(offlineMessage(for: error))
        }

        guard let http = response as? HTTPURLResponse else {
            log("[AUTH] revalidation response=non_http")
            return .offline("Erro de conexão com o servidor")
        }

        log("[AUTH] revalidation http_status=\(http.statusCode)")
        let payload = Self.parseJSONObject(data)
        if (200...299).contains(http.statusCode) {
            return .valid
        }
        if http.statusCode == 429 || (500...599).contains(http.statusCode) {
            return .offline(denialMessage(for: http.statusCode, payload: payload))
        }
        return .denied(denialMessage(for: http.statusCode, payload: payload))
    }

    /// Launch-time revalidation. Runs before the user can use the app.
    private func revalidateSavedLicense() async {
        defer { isRevalidating = false }
        switch await validateSavedLicense() {
        case .valid:
            isAuthenticated = true
            hasValidSession = true
            showError = false
            errorMessage = ""
        case .denied(let message):
            clearSavedSession()
            hasValidSession = false
            showError = true
            errorMessage = message
        case .offline(let message):
            // Offline is NOT treated as valid and NOT treated as revoked: the user
            // stays logged out, but the saved key is kept so the next launch can retry.
            isAuthenticated = false
            hasValidSession = false
            showError = true
            errorMessage = message
        }
    }

    /// Foreground revalidation (e.g. the app was left open and the license expired).
    /// Offline or success leave the session untouched; a definitive denial logs out.
    func revalidateInBackground() {
        guard isAuthenticated, !isRevalidating else { return }
        isRevalidating = true
        Task {
            defer { isRevalidating = false }
            switch await validateSavedLicense() {
            case .valid:
                hasValidSession = true
            case .denied(let message):
                clearSavedSession()
                hasValidSession = false
                showError = true
                errorMessage = message
            case .offline:
                break
            }
        }
    }

    private func clearSavedSession() {
        isAuthenticated = false
        hasValidSession = false
        storedHWID = ""
        deleteSavedLicenseKey()
        enteredKey = ""
    }

    func logout() {
        clearSavedSession()
    }

    private func denialReason(from payload: [String: Any]) -> String {
        if (payload["status"] as? String) == "hwid_mismatch" {
            return "HWID incompatível. Esta key foi gerada para outro dispositivo."
        }
        if (payload["status"] as? String) == "error" {
            return "Key inválida. Verifique e tente novamente."
        }
        let reason = Self.stringFromPayload(payload, keys: ["message", "error", "reason"]).lowercased()

        if Self.isJSONTrue(payload["expired"]) || reason.contains("expir") {
            return "A key expirou. Por favor, solicite uma nova key."
        }
        if Self.isJSONTrue(payload["blocked"]) || reason.contains("block") {
            return "A key foi bloqueada. Contate o suporte."
        }
        if Self.isJSONTrue(payload["hwid_mismatch"]) || reason.contains("hwid") {
            return "HWID incompatível. Esta key foi gerada para outro dispositivo."
        }
        let raw = Self.stringFromPayload(payload, keys: ["message", "error", "reason"])
        return raw.isEmpty ? "Key inválida. Verifique e tente novamente." : raw
    }

    private func denialMessage(for statusCode: Int, payload: [String: Any]) -> String {
        if (payload["status"] as? String) == "hwid_mismatch" {
            return "HWID incompatível. Esta key foi gerada para outro dispositivo."
        }
        if (payload["status"] as? String) == "error" {
            return "Key inválida. Verifique e tente novamente."
        }
        switch statusCode {
        case 400:
            let raw = Self.stringFromPayload(payload, keys: ["error", "message"])
            return raw.isEmpty ? "Requisição inválida. Verifique sua key." : raw
        case 401:
            return "Autenticação falhou. Verifique sua key."
        case 403:
            return "Acesso negado. Key bloqueada ou HWID incompatível."
        case 404:
            let code = Self.stringFromPayload(payload, keys: ["code"])
            if code.uppercased() == "LICENSE_NOT_FOUND" {
                return "Chave não encontrada. Verifique sua key."
            }
            let raw = Self.stringFromPayload(payload, keys: ["error", "message"])
            return raw.isEmpty ? "Código de resposta inesperado: 404" : raw
        case 429:
            return "Muitas requisições. Tente novamente mais tarde."
        case 500...599:
            return "Erro no servidor. Tente novamente."
        default:
            let raw = Self.stringFromPayload(payload, keys: ["error", "message"])
            return raw.isEmpty ? "Código de resposta inesperado: \(statusCode)" : raw
        }
    }

    private func offlineMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Sem conexão com a internet. Verifique sua rede."
            case .timedOut:
                return "Timeout na conexão. Tente novamente."
            default:
                return "Erro de rede: \(urlError.localizedDescription)"
            }
        }
        return "Erro ao conectar: \(error.localizedDescription)"
    }

    // MARK: - Saved license key (Keychain, never logged)

    private var savedLicenseKey: String {
        Self.keychainLoad().flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func persistLicenseKey(_ key: String) {
        Self.keychainStore(Data(key.utf8))
    }

    private func deleteSavedLicenseKey() {
        Self.keychainDelete()
    }

    private static let keychainService = "com.bypass7.proxy.license"
    private static let keychainAccount = "saved-license-key"

    private static func keychainStore(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { return }
        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        SecItemAdd(newItem as CFDictionary, nil)
    }

    private static func keychainLoad() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              !data.isEmpty else {
            return nil
        }
        return data
    }

    private static func keychainDelete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func parseJSONObject(_ data: Data) -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    private static func stringFromPayload(_ payload: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let str = payload[key] as? String, !str.isEmpty {
                return str
            }
            if let num = payload[key] as? NSNumber {
                return num.stringValue
            }
        }
        return ""
    }

    /// Returns true only for the JSON boolean literal `true`.
    /// Rejects: missing, NSNull, NSNumber numbers (0/1/2...), strings ("true"/"false").
    private static func isJSONTrue(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return false
        }
        return number.boolValue
    }
}
