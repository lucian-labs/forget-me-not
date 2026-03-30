import SwiftUI
import UIKit

struct FontPickerView: View {
    let title: String
    @Binding var selection: String?
    let defaultFont: String
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showAll = false

    private var families: [String] {
        let source = showAll ? SystemFonts.allFamilies : SystemFonts.recommended
        if search.isEmpty { return source }
        return source.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private var activeFont: String {
        selection ?? defaultFont
    }

    var body: some View {
        List {
            Section {
                // "Theme default" option
                fontRow(family: defaultFont, label: "\(defaultFont) (theme default)", isDefault: true)
            }

            Section(showAll ? "All fonts" : "Recommended") {
                ForEach(families, id: \.self) { family in
                    fontRow(family: family, label: family, isDefault: false)
                }
            }
        }
        .searchable(text: $search, prompt: "Search fonts")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .bottomBar) {
                Toggle(showAll ? "Showing all" : "Showing recommended", isOn: $showAll)
                    .toggleStyle(.switch)
                    .font(.caption)
            }
        }
    }

    private func fontRow(family: String, label: String, isDefault: Bool) -> some View {
        Button {
            selection = isDefault ? nil : family
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom(family, size: 16))
                        .foregroundStyle(store.theme.text)
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(.custom(family, size: 12))
                        .foregroundStyle(store.theme.dim)
                        .lineLimit(1)
                }

                Spacer()

                if (isDefault && selection == nil) || (!isDefault && selection == family) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(store.theme.accent)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
