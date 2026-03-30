import SwiftUI

struct PanelView: View {
    @Environment(TaskStore.self) private var store
    @State private var groupByCategory = false
    @State private var showCreate = false
    @State private var showSettings = false

    private var activeTasks: [FMNTask] {
        store.tasks.filter(\.isActive).sorted { $0.urgencyRatio > $1.urgencyRatio }
    }

    var body: some View {
        let _ = store.tick

        ScrollView {
            LazyVStack(spacing: store.theme.spacing) {
                panelHeader

                if activeTasks.isEmpty {
                    emptyState
                } else if groupByCategory {
                    ForEach(categoryGroups, id: \.0) { category, tasks in
                        sectionHeader(category)
                        ForEach(tasks) { task in
                            NavigationLink(value: task.id) {
                                TaskCardView(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    let recurring = activeTasks.filter(\.recurring)
                    let oneTime = activeTasks.filter { !$0.recurring }

                    if !recurring.isEmpty {
                        sectionHeader("Recurring")
                        ForEach(recurring) { task in
                            NavigationLink(value: task.id) {
                                TaskCardView(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !oneTime.isEmpty {
                        sectionHeader("Tasks")
                        ForEach(oneTime) { task in
                            NavigationLink(value: task.id) {
                                TaskCardView(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(store.theme.bg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateTaskView()
            }
            .environment(store)
            .tint(store.theme.accent)
            .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
            .environment(store)
            .tint(store.theme.accent)
            .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
    }

    // MARK: - Header (matches web: [title][+]  ...  [categorize][sounds][*])

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: title + create button
            HStack(spacing: 8) {
                Text(store.displayName)
                    .font(store.theme.header(size: 18))
                    .foregroundStyle(store.theme.accent)
                    .tracking(-0.5)

                Button { showCreate = true } label: {
                    Text("+")
                        .font(store.theme.header(size: 16, weight: .bold))
                        .foregroundStyle(store.theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(store.theme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right: categorize toggle, sounds toggle, settings button
            HStack(spacing: 10) {
                miniToggle("categorize", isOn: $groupByCategory)

                miniToggle("sounds", isOn: Binding(
                    get: { store.settings.soundEnabled },
                    set: { val in store.updateSettings { $0.soundEnabled = val } }
                ))

                Button { showSettings = true } label: {
                    Text("*")
                        .font(store.theme.header(size: 18, weight: .bold))
                        .foregroundStyle(store.theme.dim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(store.theme.border)
                .frame(height: 1)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Mini toggle (matches web's small toggle + label)

    private func miniToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 5) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.55)
                .frame(width: 36, height: 22)
                .labelsHidden()

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(store.theme.dim)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 80)
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(store.theme.dim)
            Text("No tasks yet. Hit + to create one.")
                .font(store.theme.body(size: 14))
                .foregroundStyle(store.theme.dim)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private var categoryGroups: [(String, [FMNTask])] {
        var groups: [String: [FMNTask]] = [:]
        for task in activeTasks {
            let cat = task.domain.isEmpty ? "uncategorized" : task.domain
            groups[cat, default: []].append(task)
        }
        return groups.sorted { $0.key < $1.key }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(store.theme.header(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(store.theme.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}
