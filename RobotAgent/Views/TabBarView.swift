// Nebius SF Robotics Hackathon 2026
// TabBarView.swift

import SwiftUI

struct TabBarView: View {
    @Bindable var appViewModel: AppViewModel

    @State private var dropTargetID: UUID? = nil

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(appViewModel.sessions) { session in
                        TabItemView(
                            session: session,
                            isSelected: session.id == appViewModel.selectedSessionID,
                            isDropTarget: dropTargetID == session.id,
                            canClose: appViewModel.sessions.count > 1
                        ) {
                            appViewModel.selectedSessionID = session.id
                        } onClose: {
                            appViewModel.closeSession(id: session.id)
                        }
                        .draggable(session.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let idString = items.first,
                                  let fromID = UUID(uuidString: idString),
                                  let fromIndex = appViewModel.sessions.firstIndex(where: { $0.id == fromID }),
                                  let toIndex = appViewModel.sessions.firstIndex(where: { $0.id == session.id }),
                                  fromIndex != toIndex
                            else { return false }
                            withAnimation {
                                appViewModel.sessions.move(
                                    fromOffsets: IndexSet(integer: fromIndex),
                                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                                )
                            }
                            appViewModel.save()
                            return true
                        } isTargeted: { targeted in
                            dropTargetID = targeted ? session.id : nil
                        }
                    }
                }
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            Button {
                appViewModel.addSession()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("New Tab")
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct TabItemView: View {
    let session: ChatSession
    let isSelected: Bool
    let isDropTarget: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isEditing = false
    @State private var editingName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isEditing {
                TextField("", text: $editingName)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 120)
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused && isEditing { commit() }
                    }
                    .onKeyPress(.escape) {
                        cancel()
                        return .handled
                    }
            } else {
                Text(session.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
            }

            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 16, height: 16)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(isSelected ? Color.secondary.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingName = session.name
            isEditing = true
            fieldFocused = true
        }
        .onTapGesture(perform: onSelect)
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .overlay(alignment: .leading) {
            if isDropTarget {
                Rectangle()
                    .frame(width: 2)
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 6)
            }
        }
    }

    private func commit() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            session.name = trimmed
        }
        isEditing = false
    }

    private func cancel() {
        isEditing = false
    }
}
