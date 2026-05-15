import AppKit
import SwiftUI
import StandLockCore

struct DisciplineLevelPicker: View {
    @Binding var selection: DisciplineLevel
    @State private var checker = PermissionChecker()
    @State private var showPermissionAlert = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(DisciplineLevel.allCases, id: \.self) { level in
                LevelCard(
                    level: level,
                    isSelected: selection == level,
                    isDisabled: level == .strict && !checker.accessibilityGranted
                )
                .onTapGesture {
                    if level == .strict && !checker.accessibilityGranted {
                        showPermissionAlert = true
                    } else {
                        selection = level
                    }
                }
            }
        }
        .alert("Accessibility Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                for url in PermissionType.accessibility.settingsURLs {
                    if NSWorkspace.shared.open(url) { break }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Strict mode requires Accessibility permission to block input during breaks.")
        }
        .task { await checker.pollContinuously() }
    }
}

private struct LevelCard: View {
    let level: DisciplineLevel
    let isSelected: Bool
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(level.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)

            Text(level.description)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? accentColor : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var iconName: String {
        switch level {
        case .gentle: "hand.raised"
        case .firm: "timer"
        case .strict: "lock.shield"
        }
    }

    private var accentColor: Color {
        switch level {
        case .gentle: .green
        case .firm: .orange
        case .strict: .red
        }
    }
}
