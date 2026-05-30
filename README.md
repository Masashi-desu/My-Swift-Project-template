# My-Swift-Project-template

## このリポジトリについて
本リポジトリはswiftでアプリを作る際に使用するテンプレートを配置します。

## 使い方

- このテンプレートを自分のアプリ用に使う場合は、まずプレースホルダー `__APP_NAME__` を実際のアプリ名に置き換えてください。    
- DMG 作成 / 公証は `.env` ベースで実行できます。`cp .env.example .env` で設定ファイルを作成し、必要な値を埋めたうえで `./Scripts/release_dmg.zsh` を実行してください。詳細は `docs/release/README_local_DMG.md` を参照してください。
- 追加の設定やビルドに必要な情報がある場合は、適宜この `README.md` に追記して運用してください。
