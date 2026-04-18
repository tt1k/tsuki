import AppKit
import SwiftUI

struct DatabaseEditorSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let cacheStore: SQLiteTranslationCacheStore
    let language: String
    let onRecordsChanged: () -> Void

    @State private var records: [SQLiteTranslationCacheStore.CachedRecord] = []
    @State private var selectedRecordIDs: Set<Int64> = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isDeleting = false

    private var filteredRecords: [SQLiteTranslationCacheStore.CachedRecord] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return records }

        return records.filter { record in
            record.queryText.localizedCaseInsensitiveContains(trimmedQuery)
                || record.result.headwordKanji.localizedCaseInsensitiveContains(trimmedQuery)
                || record.result.meaning.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(localizedText(en: "Database Editor", zhCN: "数据库编辑", zhTW: "資料庫編輯", ja: "データベース編集"))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Circle()
                        .fill(Color(red: 1.0, green: 95 / 255, blue: 87 / 255))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .help(localizedText(en: "Close", zhCN: "关闭", zhTW: "關閉", ja: "閉じる"))
            }

            HStack(spacing: 8) {
                TextField(localizedText(en: "Search", zhCN: "搜索", zhTW: "搜尋", ja: "検索"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))

                Button(localizedText(en: "Delete Selected", zhCN: "删除选中", zhTW: "刪除選中", ja: "選択を削除")) {
                    confirmDeleteSelectedRecords()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DesignTokens.ColorToken.boxHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(DesignTokens.ColorToken.borderIdle, lineWidth: 0.8)
                )
                .disabled(isLoading || isDeleting || selectedRecordIDs.isEmpty)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredRecords, id: \.id) { record in
                        recordRow(record)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)

            HStack {
                Text(localizedText(en: "Total", zhCN: "总数", zhTW: "總數", ja: "合計") + ": \(records.count)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textDim)
                Spacer()
                if isLoading || isDeleting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 780, minHeight: 480)
        .background(DesignTokens.ColorToken.windowBG)
        .onAppear {
            reloadRecords()
        }
    }

    @ViewBuilder
    private func recordRow(_ record: SQLiteTranslationCacheStore.CachedRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                toggleSelection(for: record.id)
            } label: {
                Image(systemName: selectedRecordIDs.contains(record.id) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(record.result.headwordKanji)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                        .lineLimit(1)

                    Text(record.result.headwordKana)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textDim)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(Self.dateFormatter.string(from: record.updatedAt))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(DesignTokens.ColorToken.textDim)
                        .lineLimit(1)
                }

                Text(displaySentence(record.result.sentence))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textDim)
                    .lineLimit(1)

                Text(record.result.meaning)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textDim)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.ColorToken.boxHover)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selectedRecordIDs.contains(record.id) ? DesignTokens.ColorToken.borderHover : DesignTokens.ColorToken.borderIdle, lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            toggleSelection(for: record.id)
        }
        .contextMenu {
            Button(localizedText(en: "Delete", zhCN: "删除", zhTW: "刪除", ja: "削除")) {
                confirmDeleteSingleRecord(recordID: record.id)
            }
            Button(localizedText(en: "Copy Row", zhCN: "复制整行", zhTW: "複製整行", ja: "行をコピー")) {
                copyRecordRow(record)
            }
        }
    }

    private func toggleSelection(for recordID: Int64) {
        if selectedRecordIDs.contains(recordID) {
            selectedRecordIDs.remove(recordID)
        } else {
            selectedRecordIDs.insert(recordID)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func reloadRecords() {
        isLoading = true
        Task {
            let records = await cacheStore.loadAllRecords()
            await MainActor.run {
                self.records = records
                self.selectedRecordIDs = self.selectedRecordIDs.intersection(Set(records.map(\.id)))
                isLoading = false
            }
        }
    }

    private func confirmDeleteSelectedRecords() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedText(
            en: "Delete selected records",
            zhCN: "删除选中记录",
            zhTW: "刪除選中記錄",
            ja: "選択レコードを削除"
        )
        alert.informativeText = localizedText(
            en: "This will remove \(selectedRecordIDs.count) record(s)",
            zhCN: "将删除 \(selectedRecordIDs.count) 条记录",
            zhTW: "將刪除 \(selectedRecordIDs.count) 筆記錄",
            ja: "\(selectedRecordIDs.count) 件のレコードを削除します"
        )
        alert.addButton(withTitle: localizedText(en: "Delete", zhCN: "删除", zhTW: "刪除", ja: "削除"))
        alert.addButton(withTitle: localizedText(en: "Cancel", zhCN: "取消", zhTW: "取消", ja: "キャンセル"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        delete(recordIDs: Array(selectedRecordIDs))
    }

    private func confirmDeleteSingleRecord(recordID: Int64) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedText(
            en: "Delete this record",
            zhCN: "删除这条记录",
            zhTW: "刪除這筆記錄",
            ja: "このレコードを削除"
        )
        alert.informativeText = localizedText(
            en: "This action cannot be undone",
            zhCN: "此操作无法撤销",
            zhTW: "此操作無法復原",
            ja: "この操作は元に戻せません"
        )
        alert.addButton(withTitle: localizedText(en: "Delete", zhCN: "删除", zhTW: "刪除", ja: "削除"))
        alert.addButton(withTitle: localizedText(en: "Cancel", zhCN: "取消", zhTW: "取消", ja: "キャンセル"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        delete(recordIDs: [recordID])
    }

    private func delete(recordIDs: [Int64]) {
        guard !recordIDs.isEmpty else { return }
        isDeleting = true

        Task {
            let removedCount = await cacheStore.deleteRecords(ids: recordIDs)
            AppEventLogger.log("Database editor deleted records: requested=\(recordIDs.count) removed=\(removedCount)")

            let records = await cacheStore.loadAllRecords()
            await MainActor.run {
                self.records = records
                selectedRecordIDs.subtract(recordIDs)
                isDeleting = false
                onRecordsChanged()
            }
        }
    }

    private func copyRecordRow(_ record: SQLiteTranslationCacheStore.CachedRecord) {
        let rowText = [
            record.result.headwordKanji,
            record.result.headwordKana,
            Self.dateFormatter.string(from: record.updatedAt),
            displaySentence(record.result.sentence),
            record.result.meaning
        ].joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rowText, forType: .string)
        AppEventLogger.log("Database editor copied row: id=\(record.id)")
    }

    private func displaySentence(_ sentence: String) -> String {
        guard let last = sentence.last, last == "." || last == "。" || last == "．" else {
            return sentence
        }
        return String(sentence.dropLast())
    }

    private func localizedText(en: String, zhCN: String, zhTW: String, ja: String) -> String {
        switch language {
        case "zh-CN": return zhCN
        case "zh-TW": return zhTW
        case "ja": return ja
        default: return en
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
