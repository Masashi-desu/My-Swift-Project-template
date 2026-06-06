# dev/main と GitHub Release 運用

このテンプレートでは `dev` をリリース準備ブランチ、`main` を公開済みブランチとして扱います。`main` に存在しないリリースが `dev` に 1 つだけある状態で、検証済み DMG を `main` へ fast-forward し、GitHub Actions が Git tag と GitHub Release を作成します。

## 前提

- `project.yml` の `settings.base.MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` をリリースバージョンの正本にする
- `CURRENT_PROJECT_VERSION` は `main` より大きい整数にする
- リリースタグは `v<MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>)` 形式にする
- GitHub Actions の repository setting で `Workflow permissions` を `Read and write permissions` にする
- テンプレート初期状態では `.github/workflows/release.yml` の release job は safety switch で無効化されているため、実プロジェクトで有効化する場合だけ workflow 内の先頭 boolean literal を `false` から `true` に変える
- 実プロジェクトの DMG 名が `__APP_NAME__-<MARKETING_VERSION>.dmg` 以外になる場合は、Repository variables の `RELEASE_APP_NAME` で上書きする

## 1. ブランチ差分を確認する

```sh
git fetch origin --tags
BASE_REF=origin/main HEAD_REF=origin/dev ./Scripts/release/github/check_release_branch_policy.sh
```

`Release branch policy OK` が出ることを確認します。このチェックは次を検証します。

- `dev` が `main` から fast-forward 可能であること
- `dev` と `main` の間にリリースバージョン変更が 1 回だけあること
- `CURRENT_PROJECT_VERSION` が `main` より増えていること

## 2. DMG を dist に作成する

```sh
./Scripts/release/dmg/release_dmg.zsh --output-dir dist
```

署名、公証、DMG 作成まで完了すると `dist/__APP_NAME__-<MARKETING_VERSION>.dmg` が作成されます。DMG 作成と公証の詳細は `docs/release/README_local_DMG.md` を参照してください。

## 3. 検証済み DMG を dev に含める

`main` push 時の GitHub Actions は CI 上で DMG を再ビルドしません。ローカルで署名・公証・実機検証まで終えた同一ファイルを GitHub Release asset として公開します。

`dist/` は通常 `.gitignore` 対象なので、リリース対象の DMG だけを `-f` で追加します。

```sh
git add -f dist/__APP_NAME__-<MARKETING_VERSION>.dmg
git commit -m "Add tested <MARKETING_VERSION> DMG"
```

## 4. main へ反映する

```sh
git push origin dev
git push origin dev:main
```

`.github/workflows/release.yml` は `main` への push を検知し、次を実行します。

テンプレート初期状態では release job が `if: ${{ false && github.repository != '' }}` で無効化されています。実プロジェクトでリリースを開始するまでは、`main` に push しても公開処理は走りません。

1. push 後の `main` が `origin/dev` と同じコミットであることを検証する
2. branch policy とバージョン差分を検証する
3. `dist/__APP_NAME__-<MARKETING_VERSION>.dmg` が Git 管理されていることを検証する
4. DMG の SHA-256 を計算し、Actions artifact として保存する
5. `v<MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>)` の tag を作成する
6. GitHub Release を作成し、同じ DMG を Release asset として配置する

## 手動実行

GitHub Actions の `workflow_dispatch` から手動実行する場合は、通常は既定値のままで構いません。

- `base_ref`: `origin/main`
- `head_ref`: `origin/dev`

特定コミットを検証したい場合だけ SHA や tag を指定します。

## 失敗時の基本方針

tag または GitHub Release の作成途中で失敗した場合、workflow は作成済みの release/tag を削除しようとします。外部状態が残った場合は、GitHub の Releases と Tags を確認し、同じ `v<MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>)` が残っていない状態に戻してから再実行してください。
