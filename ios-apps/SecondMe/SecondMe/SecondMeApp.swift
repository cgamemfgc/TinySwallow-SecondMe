//
//  SecondMeApp.swift
//  SecondMe
//
//  Created by Takeshi Sakamoto on 2025/06/05.
//

import SwiftUI

@main
struct SecondMeApp: App {
    // アプリの状態管理
    @State private var isMenuPresented = false
    
    var body: some Scene {
        // メニューバーアプリとしてMenuBarExtraを使用
        MenuBarExtra("Second Me", systemImage: "brain.head.profile") {
            // メニューバーから表示されるチャット画面
            ChatContentView()
                .frame(width: 350, height: 450)
        }
        .menuBarExtraStyle(.window) // ポップオーバースタイル
        
        // 設定ウィンドウ（必要時のみ表示）
        WindowGroup {
            SettingsView()
                .frame(width: 400, height: 300)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "Settings"))
        .defaultSize(width: 400, height: 300)
    }
}

// MARK: - メインチャット画面
struct ChatContentView: View {
    // APIクライアント
    @StateObject private var apiClient = APIClient.shared
    // チャットの状態管理
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var hasAddedWelcomeMessage = false // 重複防止フラグ
    @State private var showConnectionStatus = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー（接続状態を追加）
            HeaderView(
                isConnected: apiClient.isConnected,
                onConnectionTap: { showConnectionStatus.toggle()}
            )
            
            Divider()
            
            // 接続状態表示（オプション）
            if showConnectionStatus {
                ConnectionStatusView(apiClient: apiClient)
                    .transition(.slide)
                Divider()
            }
            
            // メッセージ表示エリア
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            EmptyStateView()
                        } else {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        // 処理中インジケーター
                        if isProcessing {
                            ProcessingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(.windowBackground)
                .onChange(of: messages.count) { _, _ in
                    // 新しいメッセージが追加されたら自動スクロール
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // 入力エリア
            InputArea(
                messageText: $messageText,
                isProcessing: $isProcessing,
                onSendMessage: sendMessage
            )
        }
        .background(.windowBackground)
        .onAppear {
            // 初期表示メソッド
            setupInitialState()
        }
    }
    
    // MARK: - Private Methods
    
    // 初期状態のセットアップ
    private func setupInitialState() {
        // ウェルカムメッセージ追加
        if !hasAddedWelcomeMessage {
            addWelcomeMessage()
            hasAddedWelcomeMessage = true
        }
        
        // サーバー接続テスト
        Task {
            let isConnected = await apiClient.testConnection()
            if isConnected {
                print("TinySwallow サーバー接続成功")
            } else {
                print("TinySwallow サーバー接続失敗")
            }
        }
    }
    
    // メッセージ送信処理(API呼び出し)
    private func sendMessage() {
        guard !messageText.trim().isEmpty && !isProcessing else { return }
        
        let userMessage = ChatMessage.user(messageText)
        messages.append(userMessage)
        
        let currentMessage = messageText
        messageText = ""
        isProcessing = true
        
        // TinySwalow　APIにリクエスト
        Task {
            do {
                let response = try await apiClient.sendMessage(currentMessage)
                let aiMessage = ChatMessage.assistant(response)
                
                await MainActor.run {
                    messages.append(aiMessage)
                    isProcessing = false
                }
            } catch {
                // エラー時のフォールバック
                let errorMessage = ChatMessage.assistant(
                    "申し訳ありません。現在TinySwallowサーバーに接続できません。\n\nエラー: \(error.localizedDescription)\n\n接続状態を確認してください。"
                )
                await MainActor.run {
                    messages.append(errorMessage)
                    isProcessing = false
                }
                
                print("APIエラー: \(error)")
            }
        }
    }
    
    //初期ウェルカムメッセージ
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage.assistant(
            "こんにちは！私はあなたの「第二の自分」AIです。\nメモの内容を参照しながら、自然な会話ができます。\n\n何か聞きたいことはありますか？",
        )
        messages.append(welcomeMessage)
    }

// MARK: - ヘッダービュー
struct HeaderView: View {
    // 接続状態パラメータ
    let isConnected: Bool
    let onConnectionTap: () -> Void
    
    var body: some View {
        HStack {
            // アプリアイコン
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text("Second Me")
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            // 接続状態インジケーター
            Button(action: onConnectionTap) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "接続済み" : "未接続")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("サーバー接続状態")
            
            // 設定ボタン
            Button(action: openSettings) {
                Image(systemName: "gearShape")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("設定を開く")
            
            // 終了ボタン
            Button(action: quitApp) {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("アプリを終了")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
    }
    
    private func openSettings() {
        // TODO: 設定ウィンドウを開く
        if let url = URL(string:"secondme://settings") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - 接続状態管理
struct ConnectionStatusView: View {
    @ObservedObject var apiClient: APIClient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("サーバー接続状態")
                    .font(.headline)
                
                Spacer()
                
                Button("再接続テスト") {
                    Task {
                        await apiClient.testConnection()
                    }
                }
                .font(.caption)
            }
            Text(apiClient.connectionStatusText)
                .font(.subheadline)
                .foregroundColor(apiClient.isConnected ? .primary : .red)
            
            if apiClient.isConnected, !apiClient.serverSummary.isEmpty {
                Text(apiClient.serverSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}
    
//// MARK: - メッセージデータモデル
//struct ChatMessage: Identifiable, Equatable {
//    let id = UUID()
//    let content: String
//    let isUser: Bool
//    let timestamp: Date
//    var referencedFiles: [String] = []
//}

// MARK: - メッセージバブル
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == "user" ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                message.role == "user" ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1
                            )
                    )
                
                // 現在時刻表示
                Text(Date(), style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if message.role != "user" {
                Spacer(minLength: 50)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.content)
    }
}
// MARK: - 空の状態表示

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.and.waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("TinySwallowをの会話を始めましょう")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("下のメッセージ欄に質問や話したいことを入力してください。\nMLXで最適化されたTinySwallow-1.5Bが応答します。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - 処理中インジケーター
struct ProcessingIndicator: View {
    @State private var animationOffset: CGFloat = -50
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("考え中...")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.accentColor.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: animationOffset)
                .clipped()
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationOffset = 100
            }
        }
    }
}

// MARK: -入力エリア
struct InputArea: View {
    @Binding var messageText: String
    @Binding var isProcessing: Bool
    let onSendMessage: () -> Void
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 音声入力ボタン(Phase2で実装予定)
            Button(action: {}) {
                Image(systemName: "mic")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(true) //　Phase2で有効化
            .help("音声入力（Phase2で実装予定）")
            
            TextField("メッセージを入力...", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .lineLimit(1...4)
                .onSubmit {
                    if !isProcessing {
                        onSendMessage()
                    }
                }
                .disabled(isProcessing)
            
            // ファイル添付ボタン（Phase2で実装予定）
            Button(action: {}) {
                Image(systemName: "paperclip")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(true) // Phase2で有効化
            .help("ファイル添付（Phase2で実装予定）")
            
            // 送信ボタン
            Button(action: onSendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help("メッセージを送信")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .onAppear {
            isInputFocused = true
        }
    }
    private var canSend: Bool {
        !messageText.trim().isEmpty && !isProcessing
    }
}

//MARK: - 設定画面
struct SettingsView: View {
    @StateObject private var apiClient = APIClient.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Second Me 設定")
                .font(.largeTitle)
                .padding()
            
            GroupBox("サーバー接続") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("状態")
                        Spacer()
                        Text(apiClient.connectionStatusText)
                            .foregroundColor(apiClient.isConnected ? .green : .red)
                    }
                    
                    if apiClient.isConnected {
                        Text(apiClient.serverSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("接続テスト") {
                        Task {
                            await apiClient.testConnection()
                        }
                    }
                }
                .padding()
            }
                
            GroupBox("Phase1 MVP") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("☑️SwiftUI チャットUI")
                    Text("☑️TinySwallow MLX統合")
                    Text("☑️FastAPIサーバー")
                    Text("ファイル連携（Phase1.8実装予定）")
                    Text("音声入力（Phase2で実装予定）")
                }
                .padding()
            }
            Spacer()
            
            Text("Phase1.7: Python連携完成！")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
        .onAppear {
            Task {
                await apiClient.testConnection()
            }
        }
    }
}

// MARK: - 文字列拡張
extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
