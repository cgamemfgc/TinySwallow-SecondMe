#!/usr/bin/env python3
"""
TinySwallow Second Me - FastAPI サーバー
Phase 1.6: Python バックエンド実装
"""

import asyncio
import time
import traceback
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional, Union

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field


# =============================================================================
# データモデル定義
# =============================================================================

class ChatMessage(BaseModel):
    """チャットメッセージモデル"""
    role: str = Field(..., description="メッセージの役割 (user/assistant)")
    content: str = Field(..., description="メッセージ内容")

class ChatCompletionRequest(BaseModel):
    """チャット完了リクエスト"""
    messages: List[ChatMessage] = Field(..., description="会話履歴")
    context_files: Optional[List[str]] = Field(default=[], description="参照ファイル")
    stream: bool = Field(default=False, description="ストリーミングレスポンス")
    max_tokens: int = Field(default=200, description="最大トークン数")
    temperature: float = Field(default=0.7, description="生成温度")

class ChatCompletionMessage(BaseModel):
    """チャット完了メッセージ"""
    role: str
    content: str
    referenced_files: Optional[List[str]] = None

class ChatCompletionChoice(BaseModel):
    """チャット完了選択肢"""
    message: ChatCompletionMessage
    finish_reason: str = "stop"

class ChatCompletionUsage(BaseModel):
    """トークン使用量"""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int

class ChatCompletionResponse(BaseModel):
    """チャット完了レスポンス"""
    id: str
    choices: List[ChatCompletionChoice]
    usage: ChatCompletionUsage
    model: str = "TinySwallow-1.5B-Instruct"

class HealthResponse(BaseModel):
    """ヘルスチェックレスポンス"""
    status: str
    model_loaded: bool
    memory_usage_gb: float
    uptime_seconds: float

class ErrorResponse(BaseModel):
    """エラーレスポンス"""
    error: str
    detail: str
    timestamp: str


# =============================================================================
# MLXモデル管理クラス
# =============================================================================

class TinySwallowMLX:
    """TinySwallow MLX モデル管理"""
    
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_name = "mlx-community/TinySwallow-1.5B-Instruct-4bit"
        self.is_loaded = False
        self.load_time = None
        
    async def load_model(self):
        """モデルの非同期ロード"""
        if self.is_loaded:
            return
        
        try:
            print(f"📥 モデルロード開始: {self.model_name}")
            start_time = time.time()
            
            # MLXライブラリの動的インポート
            from mlx_lm import load
            
            # メインスレッドでモデルロード（MLXの制約）
            loop = asyncio.get_event_loop()
            self.model, self.tokenizer = await loop.run_in_executor(
                None, load, self.model_name
            )
            
            self.load_time = time.time() - start_time
            self.is_loaded = True
            
            print(f"✅ モデルロード完了: {self.load_time:.2f}秒")
            
        except ImportError as e:
            error_msg = "MLX ライブラリが見つかりません。'pip install mlx-lm' を実行してください。"
            print(f"❌ インポートエラー: {error_msg}")
            raise HTTPException(status_code=500, detail=error_msg)
        except Exception as e:
            error_msg = f"モデルロードエラー: {str(e)}"
            print(f"❌ {error_msg}")
            raise HTTPException(status_code=500, detail=error_msg)
    
    async def generate_response(
        self, 
        messages: List[ChatMessage], 
        context_files: List[str] = None,
        max_tokens: int = 200,
        temperature: float = 0.7
    ) -> str:
        """応答生成"""
        if not self.is_loaded:
            await self.load_model()
        
        try:
            # プロンプト構築
            prompt = self._build_prompt(messages, context_files)
            
            # MLX生成実行
            from mlx_lm import generate
            
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                self._sync_generate,
                prompt,
                max_tokens
            )
            
            return response.strip()
            
        except Exception as e:
            error_msg = f"生成エラー: {str(e)}"
            print(f"❌ {error_msg}")
            raise HTTPException(status_code=500, detail=error_msg)
    
    def _sync_generate(self, prompt: str, max_tokens: int) -> str:
        """同期的な生成実行（エグゼキューター用）"""
        from mlx_lm import generate
        
        return generate(
            self.model,
            self.tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
            verbose=False
        )
    
    def _build_prompt(self, messages: List[ChatMessage], context_files: List[str] = None) -> str:
        """プロンプト構築"""
        # コンテキストファイル処理（Phase 1.7で実装予定）
        context_content = ""
        if context_files:
            context_content = f"\n参考情報: {', '.join(context_files)}\n"
        
        # チャットテンプレート適用
        if hasattr(self.tokenizer, 'chat_template') and self.tokenizer.chat_template:
            # Hugging Face Chat Template形式
            formatted_messages = [{"role": msg.role, "content": msg.content} for msg in messages]
            prompt = self.tokenizer.apply_chat_template(
                formatted_messages,
                add_generation_prompt=True,
                tokenize=False
            )
        else:
            # フォールバック: シンプルな形式
            conversation = context_content
            for msg in messages:
                if msg.role == "user":
                    conversation += f"ユーザー: {msg.content}\n"
                elif msg.role == "assistant":
                    conversation += f"アシスタント: {msg.content}\n"
            conversation += "アシスタント: "
            prompt = conversation
        
        return prompt


# =============================================================================
# アプリケーション設定
# =============================================================================

# グローバルモデルインスタンス
ml_model = TinySwallowMLX()
app_start_time = time.time()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションライフサイクル管理"""
    print("🚀 Second Me サーバー起動中...")
    
    # 起動時：モデルロード
    try:
        await ml_model.load_model()
        print("✅ サーバー起動完了")
    except Exception as e:
        print(f"⚠️ モデルロードに失敗しましたが、サーバーは起動します: {e}")
    
    yield
    
    # 終了時：クリーンアップ
    print("🛑 Second Me サーバー終了中...")


# FastAPIアプリケーション作成
app = FastAPI(
    title="TinySwallow Second Me API",
    description="個人の第二の自分AI - TinySwallow powered by MLX",
    version="1.0.0",
    lifespan=lifespan
)

# CORS設定（SwiftUIアプリからのアクセス許可）
origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8080",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8080",
    # macOS ローカル開発用
    "capacitor://localhost",
    "ionic://localhost",
    "http://localhost:*",  # ポート番号を動的に許可
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


# =============================================================================
# API エンドポイント
# =============================================================================

@app.get("/", response_model=Dict[str, Any])
async def root():
    """ルートエンドポイント"""
    return {
        "message": "TinySwallow Second Me API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """ヘルスチェック"""
    import psutil
    
    # メモリ使用量取得
    memory = psutil.virtual_memory()
    memory_usage_gb = (memory.total - memory.available) / (1024**3)
    
    # アップタイム計算
    uptime_seconds = time.time() - app_start_time
    
    return HealthResponse(
        status="healthy",
        model_loaded=ml_model.is_loaded,
        memory_usage_gb=round(memory_usage_gb, 2),
        uptime_seconds=round(uptime_seconds, 2)
    )

@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def chat_completions(request: ChatCompletionRequest):
    """チャット完了エンドポイント（OpenAI互換）"""
    try:
        # リクエストバリデーション
        if not request.messages:
            raise HTTPException(status_code=400, detail="メッセージが空です")
        
        # 最後のメッセージがユーザーからのものか確認
        last_message = request.messages[-1]
        if last_message.role != "user":
            raise HTTPException(status_code=400, detail="最後のメッセージはuserである必要があります")
        
        # 応答生成
        start_time = time.time()
        response_content = await ml_model.generate_response(
            messages=request.messages,
            context_files=request.context_files,
            max_tokens=request.max_tokens,
            temperature=request.temperature
        )
        
        generation_time = time.time() - start_time
        
        # トークン数推定（日本語対応）
        prompt_tokens = sum(len(msg.content) // 2 for msg in request.messages)
        completion_tokens = len(response_content) // 2
        
        # レスポンス構築
        chat_response = ChatCompletionResponse(
            id=f"chat-{int(time.time())}-{hash(response_content) % 10000}",
            choices=[
                ChatCompletionChoice(
                    message=ChatCompletionMessage(
                        role="assistant",
                        content=response_content,
                        referenced_files=request.context_files if request.context_files else None
                    )
                )
            ],
            usage=ChatCompletionUsage(
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=prompt_tokens + completion_tokens
            )
        )
        
        print(f"✅ チャット完了: {generation_time:.2f}秒, {completion_tokens}トークン")
        return chat_response
        
    except HTTPException:
        raise
    except Exception as e:
        error_msg = f"チャット処理エラー: {str(e)}"
        print(f"❌ {error_msg}")
        print(f"トレースバック: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=error_msg)

@app.get("/v1/models")
async def list_models():
    """利用可能なモデル一覧"""
    return {
        "object": "list",
        "data": [
            {
                "id": "TinySwallow-1.5B-Instruct",
                "object": "model",
                "created": int(time.time()),
                "owned_by": "SakanaAI",
                "permission": [],
                "root": "TinySwallow-1.5B-Instruct",
                "parent": None,
            }
        ]
    }


# =============================================================================
# エラーハンドリング
# =============================================================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """HTTP例外ハンドラー"""
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=f"HTTP {exc.status_code}",
            detail=str(exc.detail),
            timestamp=time.strftime("%Y-%m-%d %H:%M:%S")
        ).dict()
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """一般例外ハンドラー"""
    error_msg = f"Internal server error: {str(exc)}"
    print(f"❌ 予期しないエラー: {error_msg}")
    print(f"トレースバック: {traceback.format_exc()}")
    
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal Server Error",
            detail=error_msg,
            timestamp=time.strftime("%Y-%m-%d %H:%M:%S")
        ).dict()
    )


# =============================================================================
# 開発サーバー起動
# =============================================================================

if __name__ == "__main__":
    print("🦢 TinySwallow Second Me - FastAPI Server")
    print("=" * 50)
    print("📝 Phase 1.6: Python バックエンド")
    print("🔧 開発モードで起動中...")
    
    uvicorn.run(
        "server:app",
        host="127.0.0.1",
        port=8000,
        reload=True,
        log_level="info",
        reload_dirs=["./"]
    )