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
    // チャットの状態管理
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HeaderView()
            
            Divider()
            
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
                .background(Color(.windowBackground))
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
        .background(Color(.windowBackground))
        .onAppear {
            // アプリ起動時の初期メッセージ
            addWelcomeMessage()
        }
    }
    
    // メッセージ送信処理
    private func sendMessage() {
        guard !messageText.trim().isEmpty && !isProcessing else { return }
        
        let userMessage = ChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let currentMessage = messageText
        messageText = ""
        isProcessing = true
        
        // TODO: Phase1完了後にPython連携を実装
        // 現在は仮のレスポンス
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let respons = generateMockResponse(for: currentMessage)
            let aiMessage = ChatMessage(
                content: response,
                isUser: false,
                timestamp: Date()
            )
            messages.append(aiMessage)
            isProcessing = false
        }
    }
    
    //初期ウェルカムメッセージ
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "こんにちは！私はあなたの「第二の自分」AIです。\nメモの内容を参照しながら、自然な会話ができます。\n\n何か聞きたいことはありますか？",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    // 仮のレスポンス生成（Phase1用）
    private func generateMockResponse(for input: String) -> String {
        let responses = [
            "なるほど、「\(input)」について考えてみますね。\n\nまだTinySwallowとの連携は実装中ですが、Phase 1では基本的なUI動作を確認しています。",
           "「\(input)」というご質問ですね。\n\nPhase 2で実装予定のメモ検索機能があれば、より具体的な回答ができるようになります。",
           "興味深い質問です！\n\n現在はUIの動作確認段階ですが、将来的にはあなたのメモや過去の会話から学習して、より個人化された回答ができるようになります。"
       ]
        return responses.randomElement() ?? "申し訳ありません。現在は開発中です。"
    }
}

// MARK: - ヘッダービュー
struct HeaderView: View {
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

// MARK: - メッセージデータモデル
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var referencedFiles: [String] = []
}

// MARK: - メッセージバブル
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                message.isUser ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1
                            )
                    )
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if !message.isUser {
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
            
            Text("会話を始めましょう")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("下のメッセージ欄に質問や話したいことを入力してください")
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
            
            Text("考え中")
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
    var body: some View {
        VStack {
            Text("設定")
                .font(.largeTitle)
                .padding()
            
            Text("Phase2で詳細な設定画面を実装予定")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackground))
    }
}

// MARK: - 文字列拡張
extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
