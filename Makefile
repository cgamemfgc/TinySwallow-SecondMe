.PHONY: help setup test clean

# ヘルプ（デフォルト）
help:
	@echo "🦢 TinySwallow Second Me - 開発コマンド"
	@echo ""
	@echo "利用可能なコマンド:"
	@echo "  make setup     - Python環境をセットアップ"
	@echo "  make test      - MLXテストを実行"
	@echo "  make dev       - 開発サーバー起動"
	@echo "  make clean     - 一時ファイルを削除"

# Python環境セットアップ
setup:
	@echo "🔧 Python環境セットアップ中..."
	cd python-backend && source venv/bin/activate && pip install -r requirements.txt
	@echo "✅ セットアップ完了"

# テスト実行
test:
	@echo "🧪 MLX動作テスト実行中..."
	cd python-backend && source venv/bin/activate && python Phase0_MLX_Test.py

# 開発モード
dev:
	@echo "🚀 開発環境の起動方法:"
	@echo "1. ターミナル1: cd python-backend && source venv/bin/activate && python [サーバーファイル]"
	@echo "2. ターミナル2: cd ios-app && open [Xcodeプロジェクト]"

# クリーンアップ
clean:
	@echo "🧹 一時ファイル削除中..."
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	find . -name ".DS_Store" -delete
	@echo "✅ クリーンアップ完了"