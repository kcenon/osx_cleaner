// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import SwiftUI

// MARK: - Localization Helper

/// Localized string helper that uses Bundle.module for SPM resource access
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

/// Localized string with format arguments
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}

// MARK: - LocalizedStringKey Extension

extension String {
    /// Returns localized string from Bundle.module
    var localized: String {
        L(self)
    }

    /// Returns localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        String(format: L(self), arguments: arguments)
    }
}

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case korean = "ko"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L("settings.language.auto")
        case .english: return "English"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .system: return L("settings.language.auto")
        case .english: return L("settings.language.english")
        case .korean: return L("settings.language.korean")
        case .japanese: return L("settings.language.japanese")
        }
    }
}

// MARK: - Language Manager

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage("appLanguage") private(set) var selectedLanguage: String = "system"
    @Published var currentLocale: Locale = .current

    private init() {
        updateLocale()
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language.rawValue
        updateLocale()
        objectWillChange.send()
    }

    func getLanguage() -> AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    private func updateLocale() {
        switch getLanguage() {
        case .system:
            currentLocale = .current
        case .english:
            currentLocale = Locale(identifier: "en")
        case .korean:
            currentLocale = Locale(identifier: "ko")
        case .japanese:
            currentLocale = Locale(identifier: "ja")
        }
    }

    /// Returns the effective language code based on current selection
    var effectiveLanguageCode: String {
        switch getLanguage() {
        case .system:
            return Locale.current.language.languageCode?.identifier ?? "en"
        case .english:
            return "en"
        case .korean:
            return "ko"
        case .japanese:
            return "ja"
        }
    }
}

// MARK: - Localized Text View

/// A Text view that automatically uses localized strings
struct LocalizedText: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(L(key))
    }
}
