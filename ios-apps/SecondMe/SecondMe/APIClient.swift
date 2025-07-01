//
//  APIClient.swift
//  SecondMe
//
//  Created by Takeshi Sakamoto on 2025/06/20.
//
//  Phase 1.7: Swift HTTPクライアント実装
//  TinySwallow FastAPI連携
//
//  使用方法:
//  1. SecondMeApp.swiftでAPIClient.sharedを初期化
//  2. ChatContentViewでAPIClient.shared.sendMessage()を呼び出し
//  3. ヘルスチェックでサーバー状態を確認

import Foundation

// MARK: - Data Models(FastAPI互換)

// チャットメッセージモデル
struct ChatMessage: Codable, Identifiable, Equatable {
    let id = UUID()
    let role: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
    
    /// ユーザーメッセージ作成
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: "user", content: content)
    }
    
    /// アシスタントメッセージ作成
    static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: "assistant", content: content)
    }
}

/// チャット完了リクエスト
struct ChatCompletionRequest: Codable {
    let messages: [ChatMessage]
    let contextFiles: [String]
    let stream: Bool
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case messages
        case contextFiles = "context_files"
        case stream
        case maxTokens = "max_tokens"
        case temperature
    }
    
    init(
        messages: [ChatMessage],
        contextFiles: [String] = [],
        stream: Bool = false,
        maxTokens: Int = 200,
        temperature: Double = 0.7
    ) {
        self.messages = messages
        self.contextFiles = contextFiles
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

/// チャット完了レスポンスのメッセージ
struct ChatCompletionMessage: Codable {
    let role: String
    let content: String
    let referencedfiles: [String]?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case referencedfiles = "referenced_files"
    }
}

/// チャット完了の選択肢
struct ChatCompletionChoices: Codable {
    let message: ChatCompletionMessage
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finished_reason"
    }
}

/// トークン使用量
struct ChatCompletionUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// チャット完了レスポンス
struct ChatCompletionResponse: Codable {
    let id: String
    let choices: [ChatCompletionChoices]
    let usage: ChatCompletionUsage
    let model: String
}

/// ヘルスチェックレスポンス
struct HealthResponse: Codable {
    let status: String
    let modelLoaded: Bool
    let memoryUsageGB: Double
    let uptimeSeconds: Double
    
    enum CodingKeys: String, CodingKey {
        case status
        case modelLoaded = "model_loaded"
        case memoryUsageGB = "memory_usage_gb"
        case uptimeSeconds = "uptime_seconds"
    }
}

/// APIエラーレスポンス
struct APIErrorResponse: Codable {
    let error: String
    let detail: String
    let timestamp: String
}

// MARK: - Custom Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(Int, String)
    case networkError(Error)
    case servrerError(APIErrorResponse)
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なエラーです"
        case .noData:
            return "データを受信できませんでした"
        case .decodingError(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTPエラー \((code)): \(message)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .servrerError(let response):
            return "サーバーエラー: \(response.detail)"
        case .timeout:
            return "リクエストがタイムアウトしました"
        case .cancelled:
            return "リクエストがキャンセルされました"
        }
    }
}

// MARK: - HTTP Client

/// TinySwallow FastAPIクライアント
@MainActor
class APIClient: ObservableObject {
    // MARK: - Properties
    static let shaerd = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // 接続状態
    @Published var isConnected: Bool = false
    @Published var lastHealthCheck: HealthResponse?
    @Published var connectionError: APIError?
    
    // MARK: - Initialization
    
    init(baseURL: String = "http://127.0.0.1:8000") {
        self.baseURL = baseURL
        
        // URLSessionの設定
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        
        // JSON処理設定
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // 日付フォーマット設定（必要に応じて）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
    }
    
    // MARK: - Public Methods
    
    /// ヘルスチェック
    func checkHealth() async throws -> HealthResponse {
        do {
            let health: HealthResponse = try await performRequest(
                endpoint: "/health"
                method: .GET
            )
            
            await MainActor.run {
                self.isConnected = true
                self.lastHealthCheck = health
                self.connectionError = nil
            }
            
            return health
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.connectionError = error as? APIError ?? .networkError(error)
            }
            throw error
        }
    }
    
    /// チャット完了リクエスト
    func chatComletion(
        message: [ChatMessage],
        contextFiles: [String] = [],
        maxTokens: Int = 200,
        temperature: Double = 0.7
    ) async throws -> ChatCompletionResponse {
        
        let request = ChatCompletionRequest(
            messages: messages,
            contextFiles: contextFiles,
            maxtokens: maxTokens,
            temperature: temperature
        )
        
        return try await performRequest(
            endpoint: "/v1/chat/completions",
            Method: .POST,
            body: request
        )
    }
    
    /// 簡単な会話送信（ヘルパーメソッド）
    func sendMeaasge(_ content: String) async throws -> String {
        let message = ChatMessage.user(content)
        let response = try await chatCompletion(messages: [message])
        
        guard let firstChoice = response.choices.first else {
            throw APIError.noData
        }
        return firstChoice.message.content
    }
    
    /// 利用可能なモデル一覧取得
    func listModels() async throw -> [String: Any] {
        return try await performRequest(
            endpoint : "/v1/models"
            Method: .GET
        )
    }
    
    // MARK: - Private Methods
    
    // HTTP メソッド
    private enum HTTPMethods: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
    }
    
    // 汎用リクエスト実行
    private func performRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: HTTPMethods,
        body: T? = nil
    ) async throws -> U {
        
        // URL構築
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        // リクエスト構築
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // リクエストボディ設定
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.decodingError(error)
            }
        }
        
        // リクエスト実行
        do {
            let (data, response) = try await session.data(for: request)
            
            // HPPTレスポンス確認
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    // エラーレスポンス処理
                    if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                        throw APIError.servrerError(errorResponse)
                    } else {
                        let errorMesssage = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw APIError.httpError(httpResponse.statusCode, errorMesssage)
                    }
                }
            }
            
            // JSONデコード
            do {
                return try decoder.decode(U.self, from: data)
            } catch {
                print("デコードエラー詳細:")
                print("受信データ: \(String(data: data, encoding: .utf8) ?? "nil")")
                print("デコードエラー: \(error)")
                throw APIError.decodingError(error)
            }
        } catch {
        // URLErrorのハンドリング
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw APIError.timeout
                case .cancelled:
                    throw APIError.cancelled
                default:
                    throw APIError.networkError(urlError)
                }
            }
            
            // その他のエラーはそのまま再スロー
            throw error
        }
    }
    // voidレスポンス用のリクエスト実行
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethods,
        body: T? = nil
    ) async throws {
        
        let _: EmptyResponse = try await performRequest(
            endpoint: endpoint,
            method: method,
            body: body
        )
    }
}

// MARK: - Helper Types

/// 空のレスポンス用
private struct EmptyResponse: Codable {}

// MARK: - Convenirnce Extensions

extension APIClient {
    
    /// 接続テスト
    func testConnection() async -> Bool {
        do {
            _ = try await checkHealth()
            return true
        } catch {
            print("接続テスト失敗: \(error)")
            return false
        }
    }
    
    /// 接続状態の文字列表現
    var connectionStatusText: String {
        if isConnected {
            return "接続済み"
        } else if let error = connectionError {
            return "エラー: \(error.localizedDescription)"
        } else {
            return "未接続"
        }
    }
    
    /// サーバー情報の要約
    var serverSummary: String {
        guard let health = lastHealthCheck else {
            return "サーバー情報なし"
        }
        
        let modelStatus = health.modelLoaded ? "ロード済み" : "未ロード"
        let memoryUsage = String(format: "%.1f GB", health.memoryUsageGB)
        let uptime = String(format: "%.0f秒", health.uptimeSeconds)
        
        return """
        モデル: \(modelStatus)
        メモリ: \(memoryUsage)
        稼働時間: \(uptime)
        """
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension APIClient {
    
    /// デバッグ用のモックレスポンス
    static func createMockResponse() -> ChatCompletionResponse {
        ChatCompletionResponse(
            id: "mock-chat-123",
            choices: [
                ChatCompletionChoice(
                    message: ChatCompletionMessage(
                        role: "assistant",
                        content: "これはモックレスポンスです。実際のTinySwallowとの接続をテストしてください。",
                        referencedFiles: nil
                    ),
                    finishReason: "stop"
                )
            ],
            usage: ChatCompletionUsage(
                promptTokens: 10,
                completionTokens: 20,
                totalTokens: 30
            ),
            model: "TinySwallow-1.5B-Instruct"
        )
    }
    
    /// デバッグ用のログ出力
    func enableDebugLogging() {
        print("🔍 APIClient デバッグモード有効")
        print("BaseURL: \(baseURL)")
        print("Timeout: \(session.configuration.timeoutIntervalForRequest)秒")
    }
}
#endif
