# My-Swift-Project-template

## このリポジトリについて
本リポジトリはswiftでアプリを作る際に使用するテンプレートを配置します。

## 使い方

- このテンプレートを自分のアプリ用に使う場合は、まずプレースホルダー `__APP_NAME__` を実際のアプリ名に置き換えてください。    
- アプリ用 README のひな形は `README.template.md` をコピーして使用してください。
- DMG 作成 / 公証は `.env` ベースで実行できます。`cp .env.example .env` で設定ファイルを作成し、必要な値を埋めたうえで `./Scripts/release/dmg/release_dmg.zsh` を実行してください。詳細は `docs/release/README_local_DMG.md` を参照してください。
- リリース用 DMG は既定で `dist/__APP_NAME__-<version>.dmg` に作成します。`dev` / `main` 運用と GitHub Release 作成の標準手順は `docs/release/README_dev_main_github.md` を参照してください。
- itch.io への公開は既定フローには含めません。必要なプロジェクトだけ `docs/release/README_itch_io_optional.md` の手順を取り込んでください。
- 追加の設定やビルドに必要な情報がある場合は、適宜この `README.md` に追記して運用してください。
