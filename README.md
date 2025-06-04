# 🦢 TinySwallow Second Me

個人のメモ・検索履歴・思考パターンを学習し、自分らしい対話ができるプライベートAI

## 📊 現在の状況

- ✅ **Phase 0**: 環境構築・検証完了
- 🚧 **Phase 1**: MVP開発中（SwiftUI + Python連携）

## 🏗️ プロジェクト構成

```
TinySwallow-SecondMe/
├── 📱 ios-app/           # SwiftUI Mac アプリ（開発予定）
├── 🐍 python-backend/    # MLX/AI バックエンド
│   ├── venv/            # Python仮想環境
│   └── Phase0_MLX_Test.py  # MLX動作確認済み
├── 📚 shared/docs/       # 要件定義・ロードマップ
└── Makefile             # 開発コマンド
```

## 🛠️ 技術スタック

- **AI Model**: TinySwallow-1.5B-Instruct (MLX形式)
- **UI**: SwiftUI (Mac アプリ)
- **AI Framework**: MLX (M4最適化)
- **Backend**: Python 3.12 + FastAPI (予定)
- **Database**: SQLite + ChromaDB (Phase 3予定)
- **開発環境**: M4 MacBook Air 16GB

## 🚀 セットアップ & 動作確認

### 前提条件
- macOS 13.5以上
- Python 3.12 (pyenvでインストール推奨)
- Xcode 15.0以上
- 16GB以上のメモリ

### セットアップ
```bash
# リポジトリクローン
git clone [your-repo-url]
cd TinySwallow-SecondMe

# Python環境セットアップ
make setup

# MLX動作確認
make test
```

### 期待される結果
```
✅ TinySwallow-1.5B MLX版が正常に動作しています
📊 推論速度: 60+ tokens/sec
📊 メモリ使用量: 1GB未満
✅ 次のステップ: Phase 1 MVP開発に進むことができます
```

## 📋 開発フェーズ

### Phase 0: 環境構築・検証 ✅
- [x] TinySwallow-1.5B MLX版動作確認
- [x] M4 MacBook Airでの性能検証
- [x] プロジェクト構造設計
- [x] 開発環境整備

### Phase 1: MVP開発 🚧
- [ ] SwiftUI基本チャットUI
- [ ] Python-Swift IPC通信
- [ ] テキストファイル読み込み
- [ ] 会話履歴保存
- [ ] メニューバー常駐

### Phase 2-4: 順次開発予定
詳細は `shared/docs/開発ロードマップ_ver1.0.pdf` 参照

## 💻 開発コマンド

```bash
make help        # 利用可能なコマンド表示
make setup       # Python環境セットアップ
make test        # MLX動作テスト
make dev         # 開発環境起動方法表示
make clean       # 一時ファイル削除
```

## 🎯 パフォーマンス実績

**M4 MacBook Air 16GBでの測定結果：**
- プロンプト処理: 737+ tokens/sec
- テキスト生成: 86+ tokens/sec
- メモリ使用量: 0.97GB (Peak)
- レスポンス時間: 0.2-2.0秒

## 📚 ドキュメント

- [要件定義](shared/docs/要件定義_ver1.0.pdf)
- [開発ロードマップ](shared/docs/開発ロードマップ_ver1.0.pdf)

## 🔧 トラブルシューティング

### SentencePiece インストールエラー
```bash
# Python 3.13を使用している場合
pyenv install 3.12.10
pyenv local 3.12.10
```

### MLX エラー
```bash
# アーキテクチャ確認（armである必要あり）
python -c "import platform; print(platform.processor())"
```

## 🎉 Phase 0 達成内容

1. **技術スタック検証**: TinySwallow + MLX + M4の完璧な動作確認
2. **パフォーマンス評価**: 期待を上回る推論速度を達成
3. **開発環境整備**: スムーズな開発継続のための基盤構築
4. **アーキテクチャ設計**: モノレポ構成での効率的な開発体制

---

**次のステップ**: Phase 1でSwiftUIアプリケーション開発を開始します 🚀