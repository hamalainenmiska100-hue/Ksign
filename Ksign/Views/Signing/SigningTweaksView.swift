//
//  SigningTweaksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	@State private var _tweaksInDirectory: [URL] = []
	@State private var _enabledTweaks: Set<URL> = []
    @State private var _searchQuery = ""
    @State private var _sortMode: SortMode = .name

	@Binding var options: Options

    private enum SortMode: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case newest = "Newest"
    }

	// MARK: Body
	var body: some View {
		List {
			if !_filteredEnabledTweaks.isEmpty {
				Section(header: Text("Added Tweaks").font(.subheadline)) {
					ForEach(_filteredEnabledTweaks, id: \.absoluteString) { tweak in
						_file(tweak: tweak, isFromOptions: true)
					}
				}
			}
			if !_filteredAvailableTweaks.isEmpty {
				Section(header: Text("Available Tweaks").font(.subheadline)) {
					ForEach(_filteredAvailableTweaks, id: \.absoluteString) { tweak in
						_file(tweak: tweak, isFromOptions: false)
					}
				}
			}
		}
		.overlay(alignment: .center) {
			if options.injectionFiles.isEmpty && _tweaksInDirectory.isEmpty {
				if #available(iOS 17, *) {
					ContentUnavailableView {
						Label(.localized("No Tweaks"), systemImage: "gear.badge.questionmark")
					} description: {
						Text(.localized("Importing your .dylib, .deb or .framework files \n These will also be automatically added to Tweaks folder"))
                    } actions: {
						Button {
							_isAddingPresenting = true
						} label: {
							Text("Import").bg()
						}
					}
				} else {
					Text(.localized("Importing your .dylib, .deb or .framework files \n These will also be automatically added to Tweaks folder"))
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity, alignment: .center)
						.padding()
				}
			}
		}
		.navigationTitle(.localized("Tweaks"))
		.listStyle(.plain)
		.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort By", selection: $_sortMode) {
                        ForEach(SortMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Divider()

                    Button {
                        _enableAllTweaks()
                    } label: {
                        Label("Enable all", systemImage: "checkmark.circle")
                    }

                    Button {
                        _disableAllTweaks()
                    } label: {
                        Label("Disable all", systemImage: "circle")
                    }

                    Button(role: .destructive) {
                        _removeDisabledTweaks()
                    } label: {
                        Label("Remove disabled files", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }

			NBToolbarButton(
				systemImage: "plus",
				style: .icon,
				placement: .topBarTrailing
			) {
				_isAddingPresenting = true
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.item],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					_importTweaks(urls: urls)
				}
			)
		}
		.animation(.smooth, value: options.injectionFiles)
		.animation(.smooth, value: _tweaksInDirectory)
        .searchable(text: $_searchQuery, prompt: .localized("Search tweaks and mods"))
		.onAppear(perform: _loadTweaks)
	}

	private func _loadTweaks() {
		let tweaksDir = FileManager.default.tweaks
		guard let files = try? FileManager.default.contentsOfDirectory(
			at: tweaksDir,
			includingPropertiesForKeys: nil
		) else { return }

		_tweaksInDirectory = files.filter { url in
			let ext = url.pathExtension.lowercased()
			return ext == "dylib" || ext == "deb" || ext == "framework"
		}

		_enabledTweaks = Set(options.injectionFiles)
	}

    private var _filteredEnabledTweaks: [URL] {
        _sorted(_filter(options.injectionFiles))
    }

    private var _filteredAvailableTweaks: [URL] {
        _sorted(_filter(_tweaksInDirectory.filter { !options.injectionFiles.contains($0) }))
    }

    private func _filter(_ tweaks: [URL]) -> [URL] {
        guard !_searchQuery.isEmpty else { return tweaks }
        return tweaks.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(_searchQuery) }
    }

    private func _sorted(_ tweaks: [URL]) -> [URL] {
        switch _sortMode {
        case .name:
            return tweaks.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        case .type:
            return tweaks.sorted { lhs, rhs in
                let lhsType = lhs.pathExtension.lowercased()
                let rhsType = rhs.pathExtension.lowercased()
                if lhsType == rhsType {
                    return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
                }
                return lhsType < rhsType
            }
        case .newest:
            return tweaks.sorted {
                let leftDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rightDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return leftDate > rightDate
            }
        }
    }

    private func _enableAllTweaks() {
        for tweak in _tweaksInDirectory where !options.injectionFiles.contains(tweak) {
            options.injectionFiles.append(tweak)
        }
        _enabledTweaks = Set(options.injectionFiles)
    }

    private func _disableAllTweaks() {
        options.injectionFiles.removeAll()
        _enabledTweaks.removeAll()
    }

    private func _removeDisabledTweaks() {
        let disabled = _tweaksInDirectory.filter { !options.injectionFiles.contains($0) }
        for tweak in disabled {
            try? FileManager.default.removeItem(at: tweak)
        }
        _loadTweaks()
    }

    private func _importTweaks(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let tweaksDir = FileManager.default.tweaks

        do {
            try FileManager.default.createDirectoryIfNeeded(at: tweaksDir)
        } catch {
            print("Error creating tweaks directory: \(error)")
            return
        }

        let allowedExtensions = Set(["dylib", "deb", "framework"])

        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }

            let destinationURL = tweaksDir.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                if !options.injectionFiles.contains(destinationURL) {
                    options.injectionFiles.append(destinationURL)
                }
            } catch {
                print("Error copying tweak file: \(error)")
            }
        }

        _loadTweaks()
    }
}

// MARK: - Extension: View
extension SigningTweaksView {
	@ViewBuilder
	private func _file(tweak: URL, isFromOptions: Bool) -> some View {
		HStack {
			Text(tweak.lastPathComponent)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)

			if !isFromOptions {
				Toggle("", isOn: Binding(
					get: { _enabledTweaks.contains(tweak) },
					set: { newValue in
						if newValue {
							_enabledTweaks.insert(tweak)
							if !options.injectionFiles.contains(tweak) {
								options.injectionFiles.append(tweak)
							}
						} else {
							_enabledTweaks.remove(tweak)
							if let index = options.injectionFiles.firstIndex(of: tweak) {
								options.injectionFiles.remove(at: index)
							}
						}
					}
				))
				.labelsHidden()
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			Button(role: .destructive) {
				if isFromOptions {
					FileManager.default.deleteStored(tweak) { url in
						if let index = options.injectionFiles.firstIndex(where: { $0 == url }) {
							options.injectionFiles.remove(at: index)
						}
						_loadTweaks()
					}
				} else {
					do {
						try FileManager.default.removeItem(at: tweak)
						if let index = options.injectionFiles.firstIndex(of: tweak) {
							options.injectionFiles.remove(at: index)
						}
						_enabledTweaks.remove(tweak)
						_loadTweaks()
					} catch {
						print("Error deleting tweak: \(error)")
					}
				}
			} label: {
				Label(.localized("Delete"), systemImage: "trash")
			}
		}
	}
}
