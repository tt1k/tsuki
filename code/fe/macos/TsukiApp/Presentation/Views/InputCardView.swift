import AppKit
import SwiftUI

struct InputCardView: View {
    private let actionInset: CGFloat = 10
    private let inputActionGap: CGFloat = 10
    private let maxInputCharacters: Int = 25

    @Binding var inputText: String
    let isTranslating: Bool
    let onTranslate: () -> Void
    let isWindowPinned: Bool
    let onToggleWindowPinned: () -> Void
    let onSettings: () -> Void
    let onInputOverflow: () -> Void
    let onInputWithinLimit: () -> Void

    @FocusState private var focused: Bool
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var isHovered = false
    @State private var inputLocked = false
    @State private var isSettingsWindowOpen = false
    @State private var shouldMoveCaretOnFocus = false

    var body: some View {
        ZStack(alignment: .trailing) {
            cardBackground

            TextField("", text: limitedInputBinding)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(DesignTokens.FontToken.mono)
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .tint(DesignTokens.ColorToken.gray)
                .frame(height: DesignTokens.Size.editorHeight)
                .padding(.leading, 12)
                .padding(.trailing, inputTrailingInset)
                .focused($focused)
                .disabled(inputLocked)

            if inputLocked {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .padding(.leading, 12)
                    .padding(.trailing, inputTrailingInset)
                    .onTapGesture {
                        guard !isTranslating else { return }
                        unlockAndFocusInput(moveCaretToEnd: false)
                    }
            }

            HStack(spacing: 8) {
                translateButton
                settingsButton
                pinButton
            }
            .padding(.trailing, actionInset)
        }
        .frame(height: (DesignTokens.Size.editorHeight + actionInset * 2))
        .onHover { hovering in
            withAnimation(DesignTokens.Motion.hover) {
                isHovered = hovering
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusInput)) { _ in
            unlockAndFocusInput(moveCaretToEnd: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerTranslate)) { _ in
            lockAndDefocusInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsWindowVisibilityChanged)) { notification in
            guard let isOpen = notification.object as? Bool else { return }
            isSettingsWindowOpen = isOpen
        }
        .onChangeCompat(of: focused) { isFocused in
            guard isFocused, shouldMoveCaretOnFocus else { return }
            DispatchQueue.main.async {
                moveCaretToEndIfNeeded()
                shouldMoveCaretOnFocus = false
            }
        }
        .onChangeCompat(of: isTranslating) { translating in
            guard translating else { return }
            lockAndDefocusInput()
        }
        .onAppear {
            DispatchQueue.main.async {
                unlockAndFocusInput(moveCaretToEnd: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                moveCaretToEndIfNeeded()
            }
        }
    }

    private var limitedInputBinding: Binding<String> {
        Binding(
            get: { inputText },
            set: { newValue in
                let singleLine = normalizedSingleLine(newValue)
                if singleLine != inputText {
                    inputText = singleLine
                }

                if singleLine.count > maxInputCharacters {
                    onInputOverflow()
                } else {
                    onInputWithinLimit()
                }
            }
        )
    }

    private func normalizedSingleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private var inputTrailingInset: CGFloat {
        actionInset + actionButtonsWidth + inputActionGap
    }

    private var actionButtonsWidth: CGFloat {
        (24 * 3) + (8 * 2)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Size.cardRadius, style: .continuous)
            .fill(
                isHovered
                    ? DesignTokens.ColorToken.boxHover(opacity: settingsStore.windowGlassOpacity)
                    : DesignTokens.ColorToken.boxIdle(opacity: settingsStore.windowGlassOpacity)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Size.cardRadius, style: .continuous)
                    .stroke(
                        isHovered
                            ? DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity)
                            : DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity),
                        lineWidth: DesignTokens.Size.cardBorder
                    )
            }
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: isSettingsWindowOpen ? "gear.circle.fill" : "gear.circle")
                .font(DesignTokens.FontToken.icon)
                .foregroundStyle(isSettingsWindowOpen ? DesignTokens.ColorToken.textMain : DesignTokens.ColorToken.textDim)
                .frame(width: 24, height: 24)
                .background(
                    DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings")
        .accessibilityValue(isSettingsWindowOpen ? "Open" : "Closed")
    }

    private var translateButton: some View {
        Button(action: handleTranslateTapped) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity))

                if isTranslating {
                    LoadingRotateIcon()
                } else {
                    Image(systemName: "moon.stars.circle")
                        .font(DesignTokens.FontToken.icon)
                        .foregroundStyle(DesignTokens.ColorToken.textDim)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(isTranslating)
        .opacity(1)
        .accessibilityLabel(isTranslating ? "Translating" : "Translate")
    }

    private var pinButton: some View {
        Button(action: onToggleWindowPinned) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(pinButtonFill)

                Image(systemName: isWindowPinned ? "pin.circle.fill" : "pin.circle")
                    .font(DesignTokens.FontToken.icon)
                    .foregroundStyle(isWindowPinned ? DesignTokens.ColorToken.textMain : DesignTokens.ColorToken.textDim)
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isWindowPinned ? "Unpin window" : "Pin window")
        .accessibilityValue(isWindowPinned ? "Pinned" : "Not pinned")
    }

    private var pinButtonFill: Color {
        if isWindowPinned {
            return DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity)
        }

        return DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
    }

    private func handleTranslateTapped() {
        lockAndDefocusInput()
        onTranslate()
    }

    private func lockAndDefocusInput() {
        if !inputLocked {
            inputLocked = true
        }

        if focused {
            focused = false
        }
    }

    private func unlockAndFocusInput(moveCaretToEnd: Bool) {
        if inputLocked {
            inputLocked = false
        }

        shouldMoveCaretOnFocus = moveCaretToEnd

        if !focused {
            focused = true
        }
    }

    private func moveCaretToEndIfNeeded() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return
        }

        let length = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: length, length: 0))
    }
}

private struct LoadingRotateIcon: View {
    @State private var isRotating = false

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DesignTokens.ColorToken.textMain)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                isRotating = true
            }
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isRotating)
    }
}
