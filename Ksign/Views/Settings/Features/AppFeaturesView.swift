//
//  AppFeaturesView.swift
//  Ksign
//
//  Created by Nagata Asami on 10/10/25.
//

import SwiftUI
import NimbleViews
import UserNotifications

struct AppFeaturesView: View {
    @StateObject private var _optionsManager = OptionsManager.shared
    @AppStorage("moddingLabEnabled") private var _moddingLabEnabled = true
    @AppStorage("smartPatchScanEnabled") private var _smartPatchScanEnabled = true
    @AppStorage("resourceOverrideEnabled") private var _resourceOverrideEnabled = true
    @AppStorage("jsBridgeEnabled") private var _jsBridgeEnabled = false
    @AppStorage("autoBackupBeforeModding") private var _autoBackupBeforeModding = true
    @AppStorage("strictSignatureVerification") private var _strictSignatureVerification = true
    @AppStorage("preferredModdingProfile") private var _preferredModdingProfile = "Balanced"

    @State private var _showingProfileAppliedAlert = false
    @State private var _appliedProfile = ""

    var body: some View {
        NBList(.localized("App Features")) {
            Section {
                Toggle(isOn: $_moddingLabEnabled) {
                    Label(.localized("Enable Modding Lab"), systemImage: "cpu")
                }
                Picker(.localized("Default modding profile"), selection: $_preferredModdingProfile) {
                    Text(.localized("Balanced")).tag("Balanced")
                    Text(.localized("Performance")).tag("Performance")
                    Text(.localized("Compatibility")).tag("Compatibility")
                    Text(.localized("Stealth")).tag("Stealth")
                }
                .disabled(!_moddingLabEnabled)
            } header: {
                Text(.localized("Modern Modding"))
            } footer: {
                Text(.localized("Unlock advanced app modding controls and quickly switch between high-performance, compatibility, and stealth-focused presets."))
            }
            Section {
                Toggle(isOn: $_smartPatchScanEnabled) {
                    Label(.localized("Smart patch scan"), systemImage: "sparkle.magnifyingglass")
                }
                .disabled(!_moddingLabEnabled)
                Toggle(isOn: $_resourceOverrideEnabled) {
                    Label(.localized("Resource override sandbox"), systemImage: "photo.stack")
                }
                .disabled(!_moddingLabEnabled)
                Toggle(isOn: $_jsBridgeEnabled) {
                    Label(.localized("Enable JavaScript hooks"), systemImage: "curlybraces.square")
                }
                .disabled(!_moddingLabEnabled)
                Toggle(isOn: $_autoBackupBeforeModding) {
                    Label(.localized("Auto backup before modding"), systemImage: "externaldrive.badge.timemachine")
                }
                .disabled(!_moddingLabEnabled)
                Toggle(isOn: $_strictSignatureVerification) {
                    Label(.localized("Strict signature verification"), systemImage: "checkmark.shield")
                }
                .disabled(!_moddingLabEnabled)
            } header: {
                Text(.localized("Advanced Engine"))
            } footer: {
                Text(.localized("These features are designed for advanced users who want safer, more powerful tweak workflows inside Ksign."))
            }
            Section {
                Button {
                    _applyModdingPreset("Performance")
                } label: {
                    Label(.localized("Apply Performance preset"), systemImage: "bolt.fill")
                }
                .disabled(!_moddingLabEnabled)

                Button {
                    _applyModdingPreset("Compatibility")
                } label: {
                    Label(.localized("Apply Compatibility preset"), systemImage: "shield.lefthalf.filled")
                }
                .disabled(!_moddingLabEnabled)

                Button {
                    _applyModdingPreset("Stealth")
                } label: {
                    Label(.localized("Apply Stealth preset"), systemImage: "eye.slash.fill")
                }
                .disabled(!_moddingLabEnabled)
            } header: {
                Text(.localized("One-Tap Profiles"))
            } footer: {
                Text(.localized("Profile presets instantly configure signing and tweak options for common app modding goals."))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.backgroundAudio) {
                    Label(.localized("Keep app running in background"), systemImage: "arrow.trianglehead.2.clockwise")
                }
            } footer: {
                Text(.localized("This will keep the app running even when you close it, helpful with download or installing ipa."))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.signingLogs) {
                    Label(.localized("Show logs when signing"), systemImage: "terminal")
                }
            } footer: {
                Text(.localized("This will show the logs of the signing process when you start signing."))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.notifications) {
                    Label(.localized("Notify when download is completed"), systemImage: "bell")
                }
                .onChange(of: _optionsManager.options.notifications) { enabled in
                    _notificationsAuthorization(enabled)
                }
            } footer: {
                Text(.localized("This will notify you when the download is completed."))
            }
            Section {
                Toggle(isOn: $_optionsManager.options.saveAppStoreDownloadsToDownloadsFolder) {
                    Label(.localized("Save App Store downloads to Downloads folder"), systemImage: "square.and.arrow.down.fill")
                }
            } footer: {
                Text(.localized("This will save the App Store downloads to the Downloads folder, turning this off will help reduce disk usage."))
            }
            Section {
                HStack {
                    Label {
                        Text(.localized("Active tweaks"))
                    } icon: {
                        Image(systemName: "puzzlepiece.extension")
                    }
                    Spacer()
                    Text("\(_optionsManager.options.injectionFiles.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: _optionsManager.options) { _ in
            _optionsManager.saveOptions()
        }
        .alert(.localized("Profile Applied"), isPresented: $_showingProfileAppliedAlert) {
            Button(.localized("OK"), role: .cancel) {}
        } message: {
            Text(String(format: .localized("%@ profile is now active for app modding."), _appliedProfile))
        }
    }

    private func _notificationsAuthorization(_ enabled: Bool) {
        guard enabled else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        if !granted {
                            _optionsManager.options.notifications = false
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    _optionsManager.options.notifications = false

                    let cancel = UIAlertAction(title: .localized("Cancel"), style: .cancel)
                    let ok = UIAlertAction(title: .localized("Open Settings"), style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    UIAlertController.showAlert(
                        title: .localized("You have denied!"),
                        message: .localized("Please open settings and grant permission to send notifications."),
                        actions: [cancel, ok]
                    )
                }
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    private func _applyModdingPreset(_ profile: String) {
        _preferredModdingProfile = profile

        switch profile {
        case "Performance":
            _optionsManager.options.proMotion = true
            _optionsManager.options.gameMode = true
            _optionsManager.options.dynamicProtection = false
            _optionsManager.options.removeWatchPlaceholder = true
            _optionsManager.options.fileSharing = false
            _smartPatchScanEnabled = true
            _resourceOverrideEnabled = true
            _jsBridgeEnabled = false
            _strictSignatureVerification = true
        case "Compatibility":
            _optionsManager.options.proMotion = false
            _optionsManager.options.gameMode = false
            _optionsManager.options.dynamicProtection = true
            _optionsManager.options.removeSupportedDevices = true
            _optionsManager.options.removeWatchPlaceholder = false
            _optionsManager.options.fileSharing = true
            _optionsManager.options.itunesFileSharing = true
            _smartPatchScanEnabled = true
            _resourceOverrideEnabled = true
            _jsBridgeEnabled = true
            _strictSignatureVerification = true
        case "Stealth":
            _optionsManager.options.removeProvisioning = true
            _optionsManager.options.removeURLScheme = true
            _optionsManager.options.dynamicProtection = true
            _optionsManager.options.changeLanguageFilesForCustomDisplayName = true
            _optionsManager.options.fileSharing = false
            _optionsManager.options.itunesFileSharing = false
            _smartPatchScanEnabled = true
            _resourceOverrideEnabled = false
            _jsBridgeEnabled = false
            _strictSignatureVerification = true
        default:
            break
        }

        _optionsManager.saveOptions()
        _appliedProfile = profile
        _showingProfileAppliedAlert = true
    }
}
