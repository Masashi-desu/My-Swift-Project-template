# itch.io 公開を opt-in する場合

itch.io への公開はテンプレートの既定 GitHub Release flow には含めません。必要なプロジェクトだけ、明示的にこの手順を取り込みます。

## ローカルから公開する

`butler` をインストールします。

```sh
./Scripts/release/itch/install_butler.zsh /tmp/butler-bin
export PATH="/tmp/butler-bin:$PATH"
```

`.env` または実行環境に次を設定します。

```sh
ITCHIO_TARGET="<itch-user>/<itch-project>:osx-dmg"
BUTLER_API_KEY="<itch.io API key>"
```

先に dry-run で対象を確認します。

```sh
./Scripts/release/itch/publish_itch_io.zsh --dry-run --dmg dist/__APP_NAME__-<MARKETING_VERSION>.dmg
```

問題なければ公開します。

```sh
./Scripts/release/itch/publish_itch_io.zsh --dmg dist/__APP_NAME__-<MARKETING_VERSION>.dmg
```

`--dmg` を省略した場合は、`project.yml` の `MARKETING_VERSION` と一致する最新の `dist/*.dmg` を選びます。

## GitHub Actions に組み込む場合

Repository secrets に `ITCHIO_API_KEY` を登録し、Repository variables に `ITCHIO_TARGET` を登録します。

```yaml
      - name: Install butler
        run: |
          ./Scripts/release/itch/install_butler.zsh "${RUNNER_TEMP}/butler"

      - name: Publish to itch.io
        env:
          BUTLER_API_KEY: ${{ secrets.ITCHIO_API_KEY }}
          ITCHIO_TARGET: ${{ vars.ITCHIO_TARGET }}
        run: ./Scripts/release/itch/publish_itch_io.zsh --dmg "${{ steps.dmg.outputs.path }}"
```

GitHub Release より前に itch.io 公開を置く場合、itch.io 側だけ成功して後続の GitHub Release 作成が失敗する可能性があります。厳密な rollback API はないため、失敗時に再実行できるよう、同じ検証済み DMG を `dist/` に残しておく運用にしてください。
