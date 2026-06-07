# Sparkle appcast / FTP deploy を opt-in する場合

Sparkle appcast 生成と FTP deploy はテンプレートの標準必須フローには含めません。標準フローは、ローカルで署名・公証済み DMG を作成し、その検証済み DMG を GitHub Release asset として公開するところまでです。

Sparkle による更新通知や独自 FTP 配信が必要なプロジェクトだけ、この optional 手順を取り込みます。

## 1. appcast を生成する

`project.yml` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` を読み取り、informational update の appcast を生成します。

```sh
SPARKLE_RELEASE_URL="https://github.com/<owner>/<repo>/releases/latest" \
  ./Scripts/release/sparkle/generate_appcast.zsh
```

出力先は既定で `dist/sparkle/appcast.xml` です。変更する場合:

```sh
./Scripts/release/sparkle/generate_appcast.zsh \
  --output dist/sparkle/appcast.xml \
  --release-url "https://github.com/<owner>/<repo>/releases/latest"
```

## 2. FTP deploy を preflight する

FTP deploy には `lftp` を使います。

```sh
brew install lftp
```

`.env` または GitHub Actions secrets / variables に次を設定します。

```sh
FTP_HOST="<ftp-host>"
FTP_USERNAME="<ftp-user>"
FTP_PASSWORD="<ftp-password>"
FTP_REMOTE_DIR="<remote-public-dir>"
FTP_PORT="21"
SPARKLE_APPCAST_URL="https://example.com/appcast.xml"
```

実ファイルを置き換える前に、書き込み・rename・削除ができることを確認します。

```sh
./Scripts/release/sparkle/deploy_appcast_ftp.zsh --preflight dist/sparkle/appcast.xml
```

## 3. FTP deploy する

```sh
./Scripts/release/sparkle/deploy_appcast_ftp.zsh dist/sparkle/appcast.xml
```

`SPARKLE_APPCAST_URL` が設定されている場合は、アップロード後に公開 URL から appcast を取得して検証します。

## GitHub Actions に組み込む場合

Sparkle / FTP は標準 workflow には接続しません。必要なプロジェクトだけ、GitHub Release asset の作成と同じ検証済み DMG を正として、追加 step を明示的に挿入してください。

```yaml
      - name: Generate Sparkle appcast
        env:
          SPARKLE_RELEASE_URL: ${{ vars.SPARKLE_RELEASE_URL }}
        run: ./Scripts/release/sparkle/generate_appcast.zsh

      - name: Preflight Sparkle FTP deploy
        env:
          FTP_HOST: ${{ secrets.FTP_HOST }}
          FTP_USERNAME: ${{ secrets.FTP_USERNAME }}
          FTP_PASSWORD: ${{ secrets.FTP_PASSWORD }}
          FTP_REMOTE_DIR: ${{ secrets.FTP_REMOTE_DIR }}
          FTP_PORT: ${{ vars.FTP_PORT || '21' }}
          SPARKLE_APPCAST_URL: ${{ vars.SPARKLE_APPCAST_URL }}
        run: ./Scripts/release/sparkle/deploy_appcast_ftp.zsh --preflight dist/sparkle/appcast.xml

      - name: Deploy Sparkle appcast
        env:
          FTP_HOST: ${{ secrets.FTP_HOST }}
          FTP_USERNAME: ${{ secrets.FTP_USERNAME }}
          FTP_PASSWORD: ${{ secrets.FTP_PASSWORD }}
          FTP_REMOTE_DIR: ${{ secrets.FTP_REMOTE_DIR }}
          FTP_PORT: ${{ vars.FTP_PORT || '21' }}
          SPARKLE_APPCAST_URL: ${{ vars.SPARKLE_APPCAST_URL }}
        run: ./Scripts/release/sparkle/deploy_appcast_ftp.zsh dist/sparkle/appcast.xml
```

外部 FTP と GitHub Release は単一トランザクションではありません。FTP deploy を GitHub Release より前に置く場合、後続の GitHub Release 作成が失敗して FTP だけ更新される可能性があります。運用では、再実行可能な同一 DMG を `dist/` に残し、tag / GitHub Release / appcast の整合性を確認してください。
