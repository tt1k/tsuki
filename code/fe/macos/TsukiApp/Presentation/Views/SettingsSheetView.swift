import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case database
    case about
    case developer

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "circle.lefthalf.filled"
        case .database: "cylinder"
        case .developer: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }
}

private enum LanguageOption: String, CaseIterable {
    case chinese = "cn"
    case chineseTraditional = "tw"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case russian = "ru"

    var title: String {
        switch self {
        case .chinese: "中文"
        case .chineseTraditional: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "Korean"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .russian: "Russian"
        }
    }
}

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var selectedTab: SettingsTab = .general
    @State private var apiKeyInput = ""
    @State private var isEditingAPIKey = false
    @State private var hasInitializedLogs = false
    @State private var databaseEntryCount = 0
    @State private var isShowingDatabaseEditor = false
    @State private var isExportingDatabase = false
    @State private var isClearingDatabase = false
    @State private var hoveredTab: SettingsTab?
    @State private var isAPIKeyButtonHovered = false
    @State private var isNotePathButtonHovered = false
    @State private var isLogPathButtonHovered = false
    @State private var isDatabasePathButtonHovered = false
    @State private var isEditButtonHovered = false
    @State private var isExportButtonHovered = false
    @State private var isClearButtonHovered = false
    @State private var lastOpacityHapticMark = -1
    @FocusState private var focusedTab: SettingsTab?
    @FocusState private var apiKeyEditorFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private let cacheStore = SQLiteTranslationCacheStore()
    private let settingsRowHeight: CGFloat = 28
    private let settingsRowFont = Font.system(size: 13, weight: .medium, design: .monospaced)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity))

            HStack(spacing: 0) {
                sideBar
                Divider().overlay(DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity))
                detailArea
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Rectangle()
                .fill(DesignTokens.ColorToken.windowGlassBG(opacity: settingsStore.windowGlassOpacity))
                .ignoresSafeArea(.container, edges: .top)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditingAPIKey {
                endAPIKeyEditing()
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            refreshAPIKeyInput()
            lastOpacityHapticMark = Int((settingsStore.windowGlassOpacity * 100).rounded())
            DispatchQueue.main.async {
                focusedTab = .general
            }
            if !hasInitializedLogs {
                hasInitializedLogs = true
                AppEventLogger.log("Settings appeared", category: .settings)
            }
            refreshDatabaseInfo()
        }
        .onChangeCompat(of: settingsStore.provider) { _ in
            endAPIKeyEditing()
            refreshAPIKeyInput()
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: provider=\(settingsStore.provider)", category: .settings)
            }
        }
        .onChangeCompat(of: settingsStore.language) { _ in
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: language=\(settingsStore.language)", category: .settings)
            }
        }
        .onChangeCompat(of: settingsStore.useLocalBackend) { _ in
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: useLocalBackend=\(settingsStore.useLocalBackend)", category: .settings)
            }
        }
        .onChangeCompat(of: settingsStore.useLocalDictionaryData) { _ in
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: useLocalDictionaryData=\(settingsStore.useLocalDictionaryData)", category: .settings)
            }
        }
        .onChangeCompat(of: settingsStore.appearanceMode) { _ in
            (NSApp.delegate as? AppDelegate)?.applyAppearanceMode(
                settingsStore.appearanceMode,
                windowGlassOpacity: settingsStore.windowGlassOpacity
            )
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: appearanceMode=\(settingsStore.appearanceMode.rawValue)", category: .settings)
            }
        }
        .onChangeCompat(of: settingsStore.windowGlassOpacity) { _ in
            (NSApp.delegate as? AppDelegate)?.applyAppearanceMode(
                settingsStore.appearanceMode,
                windowGlassOpacity: settingsStore.windowGlassOpacity
            )
            triggerOpacityHapticIfNeeded()
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: windowGlassOpacity=\(settingsStore.windowGlassOpacity)", category: .settings)
            }
        }
        .onChangeCompat(of: settingsStore.dockIconVisible) { _ in
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: dockIconVisible=\(settingsStore.dockIconVisible)", category: .settings)
            }

            if settingsStore.dockIconVisible {
                (NSApp.delegate as? AppDelegate)?.applyDockIconVisibility(true)
            }
        }
        .onChangeCompat(of: selectedTab) { _ in
            endAPIKeyEditing()
            if hasInitializedLogs {
                AppEventLogger.log("Settings changed: selectedTab=\(selectedTab.rawValue)", category: .settings)
            }
            if selectedTab == .database {
                refreshDatabaseInfo()
            }
        }
        .onChangeCompat(of: apiKeyEditorFocused) { isFocused in
            if !isFocused {
                endAPIKeyEditing()
            }
        }
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                (NSApp.delegate as? AppDelegate)?.applyDockIconVisibility(settingsStore.dockIconVisible)
            }
        }
        .sheet(isPresented: $isShowingDatabaseEditor) {
            DatabaseEditorSheetView(
                cacheStore: cacheStore,
                language: settingsStore.language,
                onRecordsChanged: refreshDatabaseInfo
            )
        }
    }

    private var header: some View {
        ZStack {
            Text(settingsTitle)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()

                Button {
                    AppEventLogger.log("Settings closed", category: .userEvent)
                    if let window = NSApp.keyWindow {
                        window.close()
                    } else {
                        dismiss()
                    }
                } label: {
                    Circle()
                        .fill(Color(red: 1.0, green: 95 / 255, blue: 87 / 255))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help(localizedText(en: "Close", zhCN: "关闭", zhTW: "關閉", ja: "閉じる"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private func triggerOpacityHapticIfNeeded() {
        let percent = Int((settingsStore.windowGlassOpacity * 100).rounded())
        let mark = percent / 2
        guard mark != lastOpacityHapticMark / 2 else { return }
        lastOpacityHapticMark = percent
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private var sideBar: some View {
        VStack(spacing: 10) {
            ForEach(visibleTabs) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.symbol)
                            .font(settingsRowFont)
                            .frame(width: 18, alignment: .center)

                        Text(tabTitle(tab))
                            .font(settingsRowFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                        .font(settingsRowFont)
                        .foregroundStyle(selectedTab == tab ? DesignTokens.ColorToken.textMain : DesignTokens.ColorToken.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DesignTokens.ColorToken.boxHover(opacity: settingsStore.windowGlassOpacity))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity), lineWidth: 0.6)
                                    }
                            } else if hoveredTab == tab {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity), lineWidth: 0.6)
                                    }
                            }
                        }
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    hoveredTab = isHovered ? tab : (hoveredTab == tab ? nil : hoveredTab)
                }
                .focused($focusedTab, equals: tab)
            }

            Spacer()
        }
        .padding(14)
        .frame(width: 200)
    }

    private var detailArea: some View {
        contentPanel
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.clear)
    }

    private var visibleTabs: [SettingsTab] {
        SettingsTab.allCases.filter { tab in
            tab != .developer || settingsStore.developerOptionsUnlocked
        }
    }

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedTab {
        case .general:
            generalTabContent
        case .appearance:
            appearanceTabContent
        case .database:
            databaseTabContent
        case .developer:
            developerTabContent
        case .about:
            aboutTabContent
        }
    }

    private var generalTabContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text(localizedText(en: "Language", zhCN: "语言", zhTW: "語言", ja: "言語"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Picker("Language", selection: $settingsStore.language) {
                    ForEach(LanguageOption.allCases, id: \.rawValue) { option in
                        Text(languageTitle(option)).tag(option.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
                .tint(DesignTokens.ColorToken.textMain)
            }
            .frame(height: settingsRowHeight)

            HStack {
                Text(localizedText(en: "Provider", zhCN: "服务商", zhTW: "服務商", ja: "プロバイダー"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Picker("Provider", selection: $settingsStore.provider) {
                    ForEach(settingsStore.providerOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
                .tint(DesignTokens.ColorToken.textMain)
            }
            .frame(height: settingsRowHeight)

            HStack {
                Text(localizedText(en: "API Key", zhCN: "API Key", zhTW: "API Key", ja: "API キー"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                if isEditingAPIKey {
                    TextField(localizedText(en: "Enter API key", zhCN: "输入 API Key", zhTW: "輸入 API Key", ja: "API キーを入力"), text: $apiKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                        .padding(.horizontal, 10)
                        .frame(width: 260, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(apiKeyFieldBackgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity), lineWidth: 0.8)
                        )
                        .focused($apiKeyEditorFocused)
                        .onSubmit {
                            endAPIKeyEditing()
                        }
                } else {
                    Button {
                        beginAPIKeyEditing()
                    } label: {
                        HStack(spacing: 8) {
                            Text(apiKeyInput.isEmpty ? localizedText(en: "Click to enter API key", zhCN: "点击输入 API Key", zhTW: "點擊輸入 API Key", ja: "クリックして API キーを入力") : apiKeyInput)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "pencil")
                        }
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                        .padding(.horizontal, 10)
                        .frame(width: 260, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isAPIKeyButtonHovered
                                        ? DesignTokens.ColorToken.boxHover(opacity: settingsStore.windowGlassOpacity)
                                        : apiKeyFieldBackgroundColor
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    isAPIKeyButtonHovered
                                        ? DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity)
                                        : DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity),
                                    lineWidth: 0.8
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        isAPIKeyButtonHovered = isHovered
                    }
                }
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "Note Path", zhCN: "笔记路径", zhTW: "筆記路徑", ja: "ノートパス"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                if let noteDirectoryPath {
                    Button {
                        openNoteDirectoryInFinder()
                    } label: {
                        Text(noteDirectoryPath)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(isNotePathButtonHovered ? DesignTokens.ColorToken.textMain : DesignTokens.ColorToken.textDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(width: 290, alignment: .trailing)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        isNotePathButtonHovered
                                            ? DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
                                            : .clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        isNotePathButtonHovered = isHovered
                    }
                    .help(localizedText(en: "Open in Finder", zhCN: "在 Finder 中打开", zhTW: "在 Finder 中開啟", ja: "Finder で開く"))
                } else {
                    Text(notePathText)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 290, alignment: .trailing)
                }
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "Log Path", zhCN: "日志路径", zhTW: "日誌路徑", ja: "ログパス"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Button {
                    openLogDirectoryInFinder()
                } label: {
                    Text(logDirectoryPath)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(isLogPathButtonHovered ? DesignTokens.ColorToken.textMain : DesignTokens.ColorToken.textDim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 290, alignment: .trailing)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isLogPathButtonHovered
                                        ? DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
                                        : .clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isLogPathButtonHovered = isHovered
                }
                .help(localizedText(en: "Open in Finder", zhCN: "在 Finder 中打开", zhTW: "在 Finder 中開啟", ja: "Finder で開く"))
            }
            .frame(height: settingsRowHeight)

        }
    }

    private var appearanceTabContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text(localizedText(en: "App Theme", zhCN: "应用主题", zhTW: "應用主題", ja: "アプリテーマ"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Picker("Theme", selection: $settingsStore.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { option in
                        Text(appearanceModeTitle(option)).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
                .tint(DesignTokens.ColorToken.textMain)
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(opacityTitle)
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                HStack(spacing: 0) {
                    minimalOpacitySlider
                }
                .frame(width: 112, alignment: .trailing)
            }
            .frame(height: settingsRowHeight)

            HStack {
                Text(localizedText(en: "Show Dock icon", zhCN: "显示 Dock 图标", zhTW: "顯示 Dock 圖示", ja: "Dock アイコンを表示"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Toggle("", isOn: $settingsStore.dockIconVisible)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(DesignTokens.ColorToken.textDim)
            }
            .frame(height: settingsRowHeight)

        }
    }

    private var databaseTabContent: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "Entry Count", zhCN: "词库数量", zhTW: "詞庫數量", ja: "語彙数"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Text("\(databaseEntryCount)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
                    .frame(width: 260, alignment: .trailing)
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "Export Notes", zhCN: "导出笔记", zhTW: "匯出筆記", ja: "ノートを書き出す"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Button {
                    startDatabaseExport()
                } label: {
                    Text(
                        isExportingDatabase
                            ? localizedText(en: "Exporting...", zhCN: "导出中...", zhTW: "匯出中...", ja: "書き出し中...")
                            : localizedText(en: "Export", zhCN: "导出", zhTW: "匯出", ja: "書き出す")
                    )
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
                    .frame(width: 120, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isExportButtonHovered
                                    ? DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
                                    : DesignTokens.ColorToken.boxHover(opacity: settingsStore.windowGlassOpacity)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isExportButtonHovered
                                    ? DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity)
                                    : DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity),
                                lineWidth: 0.8
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isExportButtonHovered = isHovered
                }
                .disabled(isExportingDatabase || isClearingDatabase || databaseEntryCount == 0)
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "Clear Cache", zhCN: "清空缓存", zhTW: "清空快取", ja: "キャッシュを消去"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Button {
                    confirmAndClearDatabaseCache()
                } label: {
                    Text(
                        isClearingDatabase
                            ? localizedText(en: "Clearing...", zhCN: "清空中...", zhTW: "清空中...", ja: "消去中...")
                            : localizedText(en: "Clear", zhCN: "清空", zhTW: "清空", ja: "消去")
                    )
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
                    .frame(width: 120, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isClearButtonHovered
                                    ? DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
                                    : DesignTokens.ColorToken.boxHover(opacity: settingsStore.windowGlassOpacity)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isClearButtonHovered
                                    ? DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity)
                                    : DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity),
                                lineWidth: 0.8
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isClearButtonHovered = isHovered
                }
                .disabled(isExportingDatabase || isClearingDatabase || databaseEntryCount == 0)
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "Edit Records", zhCN: "编辑记录", zhTW: "編輯記錄", ja: "レコード編集"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Button {
                    AppEventLogger.log("Database editor opened", category: .userEvent)
                    isShowingDatabaseEditor = true
                } label: {
                    Text(localizedText(en: "Edit", zhCN: "编辑", zhTW: "編輯", ja: "編集"))
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                        .frame(width: 120, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isEditButtonHovered
                                        ? DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
                                        : DesignTokens.ColorToken.boxHover(opacity: settingsStore.windowGlassOpacity)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    isEditButtonHovered
                                        ? DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity)
                                        : DesignTokens.ColorToken.borderIdle(opacity: settingsStore.windowGlassOpacity),
                                    lineWidth: 0.8
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isEditButtonHovered = isHovered
                }
                .disabled(isExportingDatabase || isClearingDatabase || databaseEntryCount == 0)
            }
            .frame(height: settingsRowHeight)

            HStack(alignment: .firstTextBaseline) {
                Text(localizedText(en: "DB Path", zhCN: "数据库路径", zhTW: "資料庫路徑", ja: "DB パス"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Button {
                    openDatabaseInFinder()
                } label: {
                    Text(cacheStore.databasePath)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(isDatabasePathButtonHovered ? DesignTokens.ColorToken.textMain : DesignTokens.ColorToken.textDim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 260, alignment: .trailing)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isDatabasePathButtonHovered
                                        ? DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity)
                                        : .clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isDatabasePathButtonHovered = isHovered
                }
                .help(localizedText(en: "Open in Finder", zhCN: "在 Finder 中打开", zhTW: "在 Finder 中開啟", ja: "Finder で開く"))
            }
            .frame(height: settingsRowHeight)

        }
    }

    private var developerTabContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text(localizedText(en: "Use Local Backend", zhCN: "使用本地后端接口", zhTW: "使用本地後端介面", ja: "ローカルバックエンドを使用"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Toggle("", isOn: $settingsStore.useLocalBackend)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(DesignTokens.ColorToken.textDim)
            }
            .frame(height: settingsRowHeight)

            HStack {
                Text(localizedText(en: "Use Local Dictionary Data", zhCN: "使用本地词典数据", zhTW: "使用本地詞典資料", ja: "ローカル辞書データを使用"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)

                Spacer()

                Toggle("", isOn: $settingsStore.useLocalDictionaryData)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(DesignTokens.ColorToken.textDim)
            }
            .frame(height: settingsRowHeight)
        }
    }

    private var aboutTabContent: some View {
        VStack(spacing: 10) {
            appInfoRow
            infoRow(title: localizedText(en: "Version", zhCN: "版本", zhTW: "版本", ja: "バージョン"), value: appVersion)
            HStack {
                Text(localizedText(en: "Connect", zhCN: "联系", zhTW: "聯絡", ja: "連絡"))
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)
                Spacer()
                Link("github/tt1k", destination: URL(string: "https://github.com/tt1k")!)
                    .font(settingsRowFont)
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
            }
            .frame(height: settingsRowHeight)
        }
    }

    private var appInfoRow: some View {
        HStack {
            Text(localizedText(en: "App", zhCN: "应用", zhTW: "應用", ja: "アプリ"))
                .font(settingsRowFont)
                .foregroundStyle(DesignTokens.ColorToken.textDim)
            Spacer()
            Text(appDisplayName)
                .font(settingsRowFont)
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .onTapGesture(count: 2) {
                    unlockDeveloperTab()
                }
        }
        .frame(height: settingsRowHeight)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var appDisplayName: String {
        switch settingsStore.language {
        case "en":
            return "Tsuki Translate"
        case "cn":
            return "言叶之月"
        case "tw":
            return "言葉之月"
        default:
            return "月の言葉"
        }
    }

    private var settingsTitle: String {
        localizedText(en: "Settings", zhCN: "设置", zhTW: "設定", ja: "設定")
    }

    private var notePathText: String {
        noteDirectoryPath ?? localizedText(
            en: "Not configured",
            zhCN: "未配置",
            zhTW: "未設定",
            ja: "未設定"
        )
    }

    private var minimalOpacitySlider: some View {
        GeometryReader { proxy in
            let sliderWidth = max(proxy.size.width, 1)
            let knobDiameter: CGFloat = 10
            let progress = opacityProgress

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(DesignTokens.ColorToken.controlFill(opacity: settingsStore.windowGlassOpacity))
                    .frame(height: 4)

                Capsule(style: .continuous)
                    .fill(DesignTokens.ColorToken.borderHover(opacity: settingsStore.windowGlassOpacity))
                    .frame(width: sliderWidth * progress, height: 4)

                Circle()
                    .fill(DesignTokens.ColorToken.textMain)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .offset(x: progress * (sliderWidth - knobDiameter))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateWindowOpacity(with: value.location.x, sliderWidth: sliderWidth)
                    }
            )
        }
        .frame(width: 112, height: 18)
    }

    private var opacityProgress: CGFloat {
        let span = opacityRange.upperBound - opacityRange.lowerBound
        guard span > 0 else { return 0 }
        let raw = (settingsStore.windowGlassOpacity - opacityRange.lowerBound) / span
        return CGFloat(min(max(raw, 0), 1))
    }

    private var opacityRange: ClosedRange<Double> {
        0.70 ... 1.00
    }

    private var opacityStep: Double {
        0.01
    }

    private func updateWindowOpacity(with locationX: CGFloat, sliderWidth: CGFloat) {
        guard sliderWidth > 0 else { return }
        let progress = min(max(locationX / sliderWidth, 0), 1)
        let rawValue = opacityRange.lowerBound + Double(progress) * (opacityRange.upperBound - opacityRange.lowerBound)
        let steppedValue = (rawValue / opacityStep).rounded() * opacityStep
        settingsStore.windowGlassOpacity = min(max(steppedValue, opacityRange.lowerBound), opacityRange.upperBound)
    }

    private var opacityTitle: String {
        switch settingsStore.language {
        case "cn", "tw":
            return "透明度"
        case "ja":
            return "透明度"
        case "ko":
            return "불투명도"
        case "es":
            return "Opacidad"
        case "fr":
            return "Opacité"
        case "de":
            return "Deckkraft"
        case "ru":
            return "Прозрачность"
        default:
            return "Opacity"
        }
    }

    private var noteDirectoryPath: String? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/tsuki/note", isDirectory: true)
            .path
    }

    private var logDirectoryPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/tsuki/logs", isDirectory: true)
            .path
    }

    private func openNoteDirectoryInFinder() {
        guard let noteDirectoryPath else { return }
        let url = URL(fileURLWithPath: noteDirectoryPath, isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    private func openLogDirectoryInFinder() {
        let url = URL(fileURLWithPath: logDirectoryPath, isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    private func refreshDatabaseInfo() {
        Task {
            let count = await cacheStore.cachedEntryCount()
            await MainActor.run {
                databaseEntryCount = count
            }
        }
    }

    private func openDatabaseInFinder() {
        let dbURL = URL(fileURLWithPath: cacheStore.databasePath)
        NSWorkspace.shared.activateFileViewerSelecting([dbURL])
    }

    private func startDatabaseExport() {
        AppEventLogger.log("Database export button clicked", category: .userEvent)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = localizedText(en: "Export", zhCN: "导出", zhTW: "匯出", ja: "書き出す")
        panel.message = localizedText(
            en: "Choose a folder to save NOTE-day.md, NOTE-night.md and screenshots",
            zhCN: "选择导出目录，将生成 NOTE-day.md、NOTE-night.md 和截图",
            zhTW: "選擇匯出資料夾，將產生 NOTE-day.md、NOTE-night.md 與截圖",
            ja: "NOTE-day.md、NOTE-night.md とスクリーンショットの保存先フォルダを選択してください"
        )

        guard panel.runModal() == .OK, let destination = panel.url else {
            AppEventLogger.log("Database export cancelled: no destination selected", category: .userEvent)
            return
        }

        AppEventLogger.log("Database export destination selected: \(destination.path)", category: .database)

        isExportingDatabase = true

        Task {
            let records = await cacheStore.loadAllRecords()
            AppEventLogger.log("Database export started: records=\(records.count)", category: .database)
            do {
                let exportedDirectory = try await MainActor.run {
                    try TranslationCacheNoteExporter.export(records: records, to: destination)
                }

                await MainActor.run {
                    isExportingDatabase = false

                    let doneAlert = NSAlert()
                    doneAlert.alertStyle = .informational
                    doneAlert.messageText = localizedText(
                        en: "Export completed",
                        zhCN: "导出完成",
                        zhTW: "匯出完成",
                        ja: "書き出し完了"
                    )
                    doneAlert.informativeText = localizedText(
                        en: "Saved to \(exportedDirectory.lastPathComponent)",
                        zhCN: "已保存到 \(exportedDirectory.lastPathComponent)",
                        zhTW: "已儲存到 \(exportedDirectory.lastPathComponent)",
                        ja: "\(exportedDirectory.lastPathComponent) に保存しました"
                    )
                    doneAlert.addButton(withTitle: localizedText(en: "OK", zhCN: "确定", zhTW: "確定", ja: "OK"))
                    doneAlert.runModal()
                }

                NSWorkspace.shared.open(exportedDirectory)
                AppEventLogger.log("Cache export completed: \(exportedDirectory.path)", category: .database)
            } catch {
                await MainActor.run {
                    isExportingDatabase = false

                    let failedAlert = NSAlert()
                    failedAlert.alertStyle = .warning
                    failedAlert.messageText = localizedText(
                        en: "Export failed",
                        zhCN: "导出失败",
                        zhTW: "匯出失敗",
                        ja: "書き出し失敗"
                    )
                    failedAlert.informativeText = error.localizedDescription
                    failedAlert.addButton(withTitle: localizedText(en: "OK", zhCN: "确定", zhTW: "確定", ja: "OK"))
                    failedAlert.runModal()
                }
                AppEventLogger.log("Cache export failed: \(error.localizedDescription)", category: .database)
            }
        }
    }

    private func confirmAndClearDatabaseCache() {
        AppEventLogger.log("Database clear button clicked", category: .userEvent)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedText(
            en: "Clear cached translations",
            zhCN: "确认清空词库缓存",
            zhTW: "確認清空詞庫快取",
            ja: "翻訳キャッシュを消去"
        )
        alert.informativeText = localizedText(
            en: "Remove all cached translation records",
            zhCN: "删除全部本地缓存记录",
            zhTW: "刪除全部本地快取記錄",
            ja: "保存済み翻訳キャッシュを全件削除"
        )
        alert.addButton(withTitle: localizedText(en: "Clear", zhCN: "清空", zhTW: "清空", ja: "消去"))
        alert.addButton(withTitle: localizedText(en: "Cancel", zhCN: "取消", zhTW: "取消", ja: "キャンセル"))

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            AppEventLogger.log("Database clear cancelled by user", category: .userEvent)
            return
        }

        isClearingDatabase = true

        Task {
            let removed = await cacheStore.clearAllRecords()
            await MainActor.run {
                isClearingDatabase = false
                databaseEntryCount = 0

                let doneAlert = NSAlert()
                doneAlert.alertStyle = .informational
                doneAlert.messageText = localizedText(
                    en: "Cache cleared",
                    zhCN: "缓存已清空",
                    zhTW: "快取已清空",
                    ja: "消去完了"
                )
                doneAlert.informativeText = localizedText(
                    en: "Removed \(removed) cached entries",
                    zhCN: "已删除 \(removed) 条缓存记录",
                    zhTW: "已刪除 \(removed) 筆快取記錄",
                    ja: "\(removed) 件のキャッシュを削除しました"
                )
                doneAlert.addButton(withTitle: localizedText(en: "OK", zhCN: "确定", zhTW: "確定", ja: "OK"))
                doneAlert.runModal()
            }

            AppEventLogger.log("Database cache cleared: removed=\(removed)", category: .database)
        }
    }

    private func refreshAPIKeyInput() {
        guard !isEditingAPIKey else { return }
        let raw = settingsStore.apiKey(for: settingsStore.provider)
        apiKeyInput = maskedAPIKey(raw)
    }

    private func beginAPIKeyEditing() {
        guard !isEditingAPIKey else { return }
        isEditingAPIKey = true
        apiKeyInput = settingsStore.apiKey(for: settingsStore.provider)
        AppEventLogger.log("Settings editing API key for provider=\(settingsStore.provider)", category: .settings)
        DispatchQueue.main.async {
            apiKeyEditorFocused = true
        }
    }

    private func endAPIKeyEditing() {
        guard isEditingAPIKey else { return }
        apiKeyEditorFocused = false
        isEditingAPIKey = false
        commitAPIKeyInput()
    }

    private func commitAPIKeyInput() {
        let raw = settingsStore.apiKey(for: settingsStore.provider)
        let maskedCurrent = maskedAPIKey(raw)
        let submitted = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if submitted.isEmpty {
            settingsStore.setAPIKey("", for: settingsStore.provider)
            apiKeyInput = ""
            AppEventLogger.log("Settings changed: apiKey cleared for provider=\(settingsStore.provider)", category: .settings)
            return
        }

        if submitted == maskedCurrent {
            apiKeyInput = maskedCurrent
            return
        }

        settingsStore.setAPIKey(submitted, for: settingsStore.provider)
        apiKeyInput = maskedAPIKey(submitted)
        AppEventLogger.log("Settings changed: apiKey updated for provider=\(settingsStore.provider)", category: .settings)
    }

    private func maskedAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        let prefix = key.prefix(8)
        let maskLength = key.count - 8
        return "\(prefix)\(String(repeating: "*", count: maskLength))"
    }

    private var apiKeyFieldBackgroundColor: Color {
        if colorScheme == .light {
            return .white
        }
        return Color(red: 80 / 255, green: 80 / 255, blue: 80 / 255)
    }

    private func tabTitle(_ tab: SettingsTab) -> String {
        switch tab {
        case .general:
            return localizedText(en: "General", zhCN: "通用", zhTW: "一般", ja: "一般")
        case .appearance:
            return localizedText(en: "Appearance", zhCN: "外观", zhTW: "外觀", ja: "外観")
        case .database:
            return localizedText(en: "Database", zhCN: "数据库", zhTW: "資料庫", ja: "データベース")
        case .developer:
            return localizedText(en: "Developer", zhCN: "开发者选项", zhTW: "開發者選項", ja: "開発者オプション")
        case .about:
            return localizedText(en: "About", zhCN: "关于", zhTW: "關於", ja: "アプリについて")
        }
    }

    private func unlockDeveloperTab() {
        guard !settingsStore.developerOptionsUnlocked else {
            selectedTab = .developer
            return
        }

        settingsStore.developerOptionsUnlocked = true
        selectedTab = .developer
        AppEventLogger.log("Developer settings tab unlocked", category: .settings)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func languageTitle(_ option: LanguageOption) -> String {
        switch settingsStore.language {
        case "cn":
            switch option {
            case .chinese: return "中文"
            case .chineseTraditional: return "繁體中文"
            case .english: return "英语"
            case .japanese: return "日语"
            case .korean: return "韩语"
            case .spanish: return "西班牙语"
            case .french: return "法语"
            case .german: return "德语"
            case .russian: return "俄语"
            }
        case "tw":
            switch option {
            case .chinese: return "簡體中文"
            case .chineseTraditional: return "繁體中文"
            case .english: return "英語"
            case .japanese: return "日語"
            case .korean: return "韓語"
            case .spanish: return "西班牙語"
            case .french: return "法語"
            case .german: return "德語"
            case .russian: return "俄語"
            }
        case "ja":
            switch option {
            case .chinese: return "簡体字中国語"
            case .chineseTraditional: return "繁体字中国語"
            case .english: return "英語"
            case .japanese: return "日本語"
            case .korean: return "韓国語"
            case .spanish: return "スペイン語"
            case .french: return "フランス語"
            case .german: return "ドイツ語"
            case .russian: return "ロシア語"
            }
        default:
            return option.title
        }
    }

    private func appearanceModeTitle(_ option: AppearanceMode) -> String {
        switch settingsStore.language {
        case "cn":
            switch option {
            case .dark: return "深色"
            case .light: return "浅色"
            case .auto: return "跟随系统"
            }
        case "tw":
            switch option {
            case .dark: return "深色"
            case .light: return "淺色"
            case .auto: return "跟隨系統"
            }
        case "ja":
            switch option {
            case .dark: return "ダーク"
            case .light: return "ライト"
            case .auto: return "システム"
            }
        default:
            switch option {
            case .dark: return "Dark"
            case .light: return "Light"
            case .auto: return "Auto"
            }
        }
    }

    private func localizedText(en: String, zhCN: String, zhTW: String, ja: String) -> String {
        switch settingsStore.language {
        case "cn": return zhCN
        case "tw": return zhTW
        case "ja": return ja
        default: return en
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(settingsRowFont)
                .foregroundStyle(DesignTokens.ColorToken.textDim)
            Spacer()
            Text(value)
                .font(settingsRowFont)
                .foregroundStyle(DesignTokens.ColorToken.textMain)
        }
        .frame(height: settingsRowHeight)
    }
}

struct TsukiAboutWindowView: View {
    @ObservedObject var settingsStore: SettingsStore
    var onOK: () -> Void
    var onCopy: (String) -> Void

    private let settingsRowHeight: CGFloat = 28
    private let settingsRowFont = Font.system(size: 13, weight: .medium, design: .monospaced)

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 74, height: 74)
                .accessibilityHidden(true)

            Text(appDisplayName)
                .font(.system(size: 19, weight: .semibold, design: .default))
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                infoRow(title: localizedText(en: "Version", zhCN: "版本", zhTW: "版本", ja: "バージョン"), value: appVersion)
                HStack {
                    Text("\(localizedText(en: "Connect", zhCN: "联系", zhTW: "聯絡", ja: "連絡")):")
                        .font(settingsRowFont)
                        .foregroundStyle(DesignTokens.ColorToken.textDim)
                    Link("github/tt1k", destination: URL(string: "https://github.com/tt1k")!)
                        .font(settingsRowFont)
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                }
                .frame(height: settingsRowHeight)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                Button {
                    onOK()
                } label: {
                    Text("OK")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button {
                    onCopy(aboutCopyText)
                } label: {
                    Text("Copy")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var appDisplayName: String {
        switch settingsStore.language {
        case "en":
            return "Tsuki Translate"
        case "cn":
            return "言叶之月"
        case "tw":
            return "言葉之月"
        default:
            return "月の言葉"
        }
    }

    private var aboutCopyText: String {
        """
        \(appDisplayName)
        Version: \(appVersion)
        Connect: github/tt1k
        https://github.com/tt1k
        """
    }

    private func localizedText(en: String, zhCN: String, zhTW: String, ja: String) -> String {
        switch settingsStore.language {
        case "cn": return zhCN
        case "tw": return zhTW
        case "ja": return ja
        default: return en
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text("\(title):")
                .font(settingsRowFont)
                .foregroundStyle(DesignTokens.ColorToken.textDim)
            Text(value)
                .font(settingsRowFont)
                .foregroundStyle(DesignTokens.ColorToken.textMain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: settingsRowHeight)
    }
}
