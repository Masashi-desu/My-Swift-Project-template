# **__APP_NAME__** 公証付き DMG 作成手順

__APP_NAME__ をローカル環境でビルドし、公証済み DMG を得るまでの必須コマンドを順番に記載します。`README.md` と記述を揃え、以下のコマンド列を上から順に実行すれば DMG 作成が完了します。

## 前提条件

- macOS 13 以降で Xcode（Command Line Tools を含む）がインストール済み
- Apple Developer Program に加入し、Developer ID Application 証明書をキーチェーンに追加済み
- Apple ID 用のアプリ用パスワードを取得済み（notarytool の Apple ID 認証に使用）
- Homebrew が導入済み（`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` で導入可）

## STEP0: 依存ツールと環境変数

1. create-dmg を導入（既に導入済みでもそのまま実行可）
   ```bash
   brew install create-dmg
   ```
2. 以降のコマンドで使う環境変数を定義（<> を自身の値に置き換え）
   ```bash
   export PROJECT_ROOT="/Users/workSpace/__APP_NAME__"
   export APP_NAME="__APP_NAME__"
   export BUILD_DIR="$PROJECT_ROOT/build"
   export APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
   export DIST_DIR="$PROJECT_ROOT/dist"
   export DEVELOPER_IDENTITY="Developer ID Application: <YOUR NAME> (<TEAM ID>)"
   export TEAM_ID="<TEAM ID>"
   export NOTARY_APPLE_ID="<apple-id@example.com>"
   export NOTARY_APP_PASSWORD="<app-specific-password>"
   export NOTARY_TEAM_ID="$TEAM_ID"
   ```
   任意で `export NOTARY_KEYCHAIN_PROFILE="__APP_NAME__Notary"` を定義しておくと、後段で keychain profile 版のコマンドに流用できます。

## STEP1: プロジェクトを整える

```bash
cd "$PROJECT_ROOT"
xcodegen generate
```
`xcodegen generate` は既存の `__APP_NAME__.xcodeproj` があっても安全に再実行できます。

## STEP2: Release ビルドを作成

```bash
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="$DEVELOPER_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp"
```
成功すると `build/Build/Products/Release/__APP_NAME__.app` が生成されます。

## STEP3: Developer ID 署名と検証

```bash
codesign --force --deep --options runtime --timestamp \
  --sign "$DEVELOPER_IDENTITY" \
  "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
```
署名後に `tccutil reset Accessibility com.__APP_NAME__.app` を実行すると、テスト端末でアクセシビリティ権限を付け直せます。

## STEP4: DMG を生成

```bash
mkdir -p "$DIST_DIR"
export VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString)
export DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_PATH"  # 既存 DMG があれば削除
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 540 360 \
  --icon-size 128 \
  --app-drop-link 400 200 \
  "$DMG_PATH" \
  "$APP_PATH"
```
`rm -f "$DMG_PATH"` で同名ファイルを先に削除したうえで `create-dmg` を実行することで、`--overwrite` オプションが無い環境でも確実に再生成できます。背景画像や配置を変更したい場合は `create-dmg` のオプションを調整してください。

## STEP5: notarytool で公証

Apple ID 認証を直接使う場合は下記を実行します。

```bash
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$NOTARY_APPLE_ID" \
  --team-id "$NOTARY_TEAM_ID" \
  --password "$NOTARY_APP_PASSWORD" \
  --wait
```

keychain profile を利用したい場合は、最初に1回だけ資格情報を保存します。

```bash
xcrun notarytool store-credentials "$NOTARY_KEYCHAIN_PROFILE" \
  --apple-id "$NOTARY_APPLE_ID" \
  --team-id "$NOTARY_TEAM_ID" \
  --password "$NOTARY_APP_PASSWORD"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait
```
`store-credentials` を一度完了させれば、次回以降は下記 1 コマンドだけで提出できます。

```bash
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait
```

`Status: Accepted` が表示されれば公証完了です。失敗した場合はログ内の `id:` を `xcrun notarytool log <RequestID>` で調査します。

## STEP6: ステープルと Gatekeeper 評価

```bash
xcrun stapler staple "$DMG_PATH" && \
spctl --assess --type open --context context:primary-signature "$DMG_PATH"
```
`&&` で連結しているため、ステープル成功後に直ちに Gatekeeper 評価が走ります。`source=Notarized Developer ID` が表示されれば DMG そのものに公証チケットが埋め込まれ、公証済みであることが確認できます。

`spctl` が `rejected`/`Insufficient Context` を返す場合は、DMG に問題があるとは限りません。以下のいずれかで DMG への公証チケットが有効であることを確認できます。

```bash
xcrun stapler validate "$DMG_PATH"
```

`The validate action worked!` と表示されれば DMG へのステープル（公証チケット埋め込み）が有効であることを確認できます。

もしくは、DMG をマウントしてアプリ本体を検証します。

```bash
hdiutil attach "$DMG_PATH" -nobrowse && \
spctl --assess --type open --context context:primary-signature -v "/Volumes/$APP_NAME/$APP_NAME.app" && \
hdiutil detach "/Volumes/$APP_NAME"
```
`xcrun stapler validate` で `The validate action worked!` が表示される、またはマウント後の `spctl` で `source=Notarized Developer ID` が得られれば、DMG 内アプリにも公証が適用されており DMG の公証チケットも有効です。

## STEP7: 出力確認

```bash
ls -lh "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
export INFO_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.txt"
{
  echo "DMG Path: $DMG_PATH"
  echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  ls -lh "$DMG_PATH"
  shasum -a 256 "$DMG_PATH"
} | tee "$INFO_PATH"
```
`ls`/`shasum` の結果を表示すると同時に、`dist/${APP_NAME}-${VERSION}.txt` にも保存しておくと配布後の検証が容易になります。

## STEP8: GitHub リリースへアップロード

1. GitHub CLI (`gh`) が未導入の場合は `brew install gh` で導入し、`gh auth login` で GitHub アカウントへサインインします。
2. タグとリリース名を設定してリリースを作成し、DMG とメタ情報テキストを添付します。

   ```bash
   export TAG_NAME="v${VERSION}"
   export RELEASE_TITLE="__APP_NAME__ ${VERSION}"
   gh release create "$TAG_NAME" \
     "$DMG_PATH" "$INFO_PATH" \
     --title "$RELEASE_TITLE" \
     --notes "Release notes for ${RELEASE_TITLE}"
   ```

   既存タグを使う場合は `--draft` で一度下書きを作成し、リリースノートを整備してから公開してください。Web UI でアップロードする場合も、`dist` 配下に生成された DMG と TXT をそのまま添付すれば同等です。

## 公証をスキップせざるを得ない場合

Apple Developer Program に未加入などで公証できない場合でも、上記 STEP4 までを実行して署名付き `.app`/DMG を作成し、テスターへ Gatekeeper の警告（「Apple は悪質なソフトウェアがないことを確認できません」）と回避手順（右クリック→「開く」）を必ず共有してください。

## AI アシスタントに依頼する際の指示テンプレート

1. `cd /Users/workSpace/__APP_NAME__` でリポジトリ直下に移動させる。  
2. `xcodegen generate` → `xcodebuild ...` → `create-dmg ...` → `xcrun notarytool ...` → `xcrun stapler ...` を順番に実行させ、各ステップのログと生成物を報告させる。  
3. 公証を省略する場合は理由と回避手順を明記させる。  
4. 生成された DMG のパス・サイズ・ハッシュの提示も依頼する。
