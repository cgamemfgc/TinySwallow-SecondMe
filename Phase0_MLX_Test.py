#!/usr/bin/env python3
"""
Phase 0: TinySwallow-1.5B MLX版の動作確認スクリプト
M4 MacBook Air 16GB での推論テスト
"""

import time
import psutil
import sys
from pathlib import Path

def check_system():
    """システム情報確認"""
    print("🔍 システム情報確認")
    print(f"Python版本: {sys.version}")
    print(f"プラットフォーム: {sys.platform}")
    
    # メモリ情報
    memory = psutil.virtual_memory()
    print(f"総メモリ: {memory.total / (1024**3):.1f} GB")
    print(f"利用可能メモリ: {memory.available / (1024**3):.1f} GB")
    print("-" * 50)

def test_mlx_installation():
    """MLXライブラリのインストール確認"""
    print("📦 MLXライブラリ確認")
    try:
        import mlx.core as mx
        print("✅ MLX core: OK")
        
        # 簡単な動作テスト（浮動小数点型を使用）
        a = mx.array([1.0, 2.0, 3.0, 4.0])  # float型に変更
        b = mx.array([5.0, 6.0, 7.0, 8.0])  # float型に変更
        
        # MLXでは@演算子またはmatmulを使用（float型のみサポート）
        c = a @ b  # または mx.matmul(a, b)
        print(f"✅ MLX基本動作テスト (内積): {c.item()}")
        
        # 他の基本演算もテスト（整数型はsum等では問題なし）
        a_int = mx.array([1, 2, 3, 4])
        d = mx.sum(a_int)
        print(f"✅ MLX sum テスト: {d.item()}")
        
        # 行列演算のテスト（浮動小数点型）
        matrix_a = mx.array([[1.0, 2.0], [3.0, 4.0]])
        matrix_b = mx.array([[5.0, 6.0], [7.0, 8.0]])
        matrix_c = matrix_a @ matrix_b
        print(f"✅ MLX行列乗算テスト: 正常動作")
        print(f"   結果例: {matrix_c[0, 0].item()}")
        
    except ImportError as e:
        print(f"❌ MLX core インポートエラー: {e}")
        return False
        
    try:
        from mlx_lm import load, generate
        print("✅ MLX-LM: OK")
        return True
    except ImportError as e:
        print(f"❌ MLX-LM インポートエラー: {e}")
        return False

def download_and_test_tinyswallow():
    """TinySwallow-1.5B MLX版のダウンロードとテスト"""
    print("\n🦢 TinySwallow-1.5B-Instruct MLX版テスト")
    
    try:
        from mlx_lm import load, generate
        
        # MLX形式のTinySwallow-1.5B-Instructモデルをロード
        print("📥 モデルをダウンロード中...")
        model_name = "mlx-community/TinySwallow-1.5B-Instruct-4bit"
        
        start_time = time.time()
        model, tokenizer = load(model_name)
        load_time = time.time() - start_time
        
        print(f"✅ モデルロード完了: {load_time:.2f}秒")
        
        # メモリ使用量確認
        memory = psutil.virtual_memory()
        used_memory = (memory.total - memory.available) / (1024**3)
        print(f"📊 モデルロード後メモリ使用量: {used_memory:.1f} GB")
        
        return model, tokenizer
        
    except Exception as e:
        print(f"❌ モデルロードエラー: {e}")
        return None, None

def test_conversation(model, tokenizer):
    """実際の会話テスト"""
    if model is None or tokenizer is None:
        print("❌ モデルが利用できません")
        return
        
    print("\n💬 会話テスト開始")
    
    test_prompts = [
        "こんにちは！あなたは誰ですか？",
        "私の趣味は読書です。おすすめの本を教えてください。",
        "今日は天気が良いですね。"
    ]
    
    for i, prompt in enumerate(test_prompts, 1):
        print(f"\n--- テスト {i} ---")
        print(f"👤 質問: {prompt}")
        
        try:
            # MLX-LM 最新API使用（シンプル版）
            from mlx_lm import generate
            
            # チャットテンプレート適用
            if hasattr(tokenizer, 'chat_template') and tokenizer.chat_template is not None:
                messages = [{"role": "user", "content": prompt}]
                formatted_prompt = tokenizer.apply_chat_template(
                    messages, 
                    add_generation_prompt=True,
                    tokenize=False
                )
            else:
                formatted_prompt = prompt
            
            # 推論実行（基本パラメータのみ）
            start_time = time.time()
            response = generate(
                model, 
                tokenizer, 
                prompt=formatted_prompt, 
                verbose=False,
                max_tokens=100
                # 温度パラメータは現在サポートされていません
            )
            inference_time = time.time() - start_time
            
            print(f"🤖 回答: {response}")
            print(f"⏱️  推論時間: {inference_time:.2f}秒")
            
        except Exception as e:
            print(f"❌ 推論エラー: {e}")
            # デバッグ情報
            print(f"   デバッグ: model type = {type(model)}")
            print(f"   デバッグ: tokenizer type = {type(tokenizer)}")

def benchmark_performance(model, tokenizer):
    """パフォーマンステスト"""
    if model is None or tokenizer is None:
        return
        
    print("\n⚡ パフォーマンステスト")
    
    prompt = "人工知能の未来について教えてください。"
    
    # チャットテンプレート適用
    if hasattr(tokenizer, 'chat_template') and tokenizer.chat_template is not None:
        messages = [{"role": "user", "content": prompt}]
        formatted_prompt = tokenizer.apply_chat_template(
            messages, 
            add_generation_prompt=True,
            tokenize=False
        )
    else:
        formatted_prompt = prompt
    
    try:
        from mlx_lm import generate
        
        start_time = time.time()
        response = generate(
            model, 
            tokenizer, 
            prompt=formatted_prompt, 
            verbose=True,  # トークン生成速度を表示
            max_tokens=200
            # 温度パラメータは現在サポートされていません
        )
        total_time = time.time() - start_time
        
        # 概算のトークン数（日本語は複雑なので概算）
        estimated_tokens = len(response) // 2  # 日本語の平均的な見積もり
        tokens_per_second = estimated_tokens / total_time if total_time > 0 else 0
        
        print(f"\n📊 パフォーマンス結果:")
        print(f"総処理時間: {total_time:.2f}秒")
        print(f"推定トークン数: {estimated_tokens}")
        print(f"推定速度: {tokens_per_second:.1f} tokens/sec")
        
        # メモリ使用量
        memory = psutil.virtual_memory()
        used_memory = (memory.total - memory.available) / (1024**3)
        print(f"メモリ使用量: {used_memory:.1f} GB")
        
    except Exception as e:
        print(f"❌ ベンチマークエラー: {e}")
        print(f"   現在のMLX-LMでは温度パラメータをサポートしていません")

def main():
    """メイン実行関数"""
    print("🚀 TinySwallow-1.5B MLX 動作確認スクリプト")
    print("=" * 60)
    
    # システム確認
    check_system()
    
    # MLXインストール確認
    if not test_mlx_installation():
        print("\n❌ MLXライブラリのインストールを確認してください")
        print("実行コマンド: pip install mlx mlx-lm")
        return
    
    # TinySwallowダウンロード・テスト
    model, tokenizer = download_and_test_tinyswallow()
    
    if model is not None:
        # 会話テスト
        test_conversation(model, tokenizer)
        
        # パフォーマンステスト
        benchmark_performance(model, tokenizer)
        
        print("\n🎉 Phase 0 環境構築・検証完了！")
        print("✅ TinySwallow-1.5B MLX版が正常に動作しています")
        print("✅ 次のステップ: Phase 1 MVP開発に進むことができます")
    else:
        print("\n❌ 環境構築に問題があります。エラーを確認してください。")

if __name__ == "__main__":
    main()