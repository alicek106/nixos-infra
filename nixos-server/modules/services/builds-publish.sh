# fcgiwrap이 POST /publish/<app key>/<publish ID> 요청이 올 때마다 실행하는 cgi 스크립트.
#
# request payload에는 4개 파일이 들어 있는 tar가 들어온다.
#
# 1. index.html: 아래 형태 링크처럼, 특정 빌드의 manifest.plist 로 가서 다운로드를 하라는 링크 버튼이 있음.
#   -> itms-services://?action=download-manifest&url=https://builds.alicek106.com/whatseat/releases/20261031-000530-9e05a0e-qa-debug/manifest.plist
#
# 2. manifest.plist: ipa를 내려받을 주소를 담고 있음.
#   -> https://builds.alicek106.com/whatseat/releases/20261031-000530-9e05a0e-qa-debug/WhatsEat-debug.ipa 형태
#
# 3. release.json: 목록 페이지에 보여 줄 빌드 정보 (name, version, build, kind, commit, built, bundle_id)
#
# 4. <app name>.ipa: 실제 앱 설치 파일
#
# nginx 서버가 tar 파일 업로드를 받으면 /<app key>/releases/<publish ID>/ 에 tar를 풀고,
# /<app key>/current 를 해당 publish ID 디렉터리로 symlink를 건다.
# 그리고 /<app key>/index.html (그 앱의 빌드 목록)과 /index.html (앱 목록)을 다시 만든다.
# 그래서, 클라가 builds.alicek106.com 으로 들어오면 앱 목록을 보고, 앱을 고르면 그 앱의 빌드 목록을 본다.
# 빌드의 index.html은 빌드 다운로드 버튼을 보여주고, 그 버튼은 manifest.plist를 받게 하고, manifest.plist는 ipa 주소를 클라에게 전달하는 식임.

# 0. reuqest payload 정보 읽기
# nginx가 넘긴 fastcgi 변수들
method=${REQUEST_METHOD:-}
path=${DOCUMENT_URI:-}
path=${path#/publish/}
app=${path%%/*}
id=${path#"$app"}
id=${id#/}
from=${REMOTE_ADDR:-}
length=${CONTENT_LENGTH:-}
# slack 메시지에 넣을 <app key>/<publish ID>
safe_id=$(printf '%s' "$path" | tr -cd 'A-Za-z0-9._/-' | cut -c1-120)

# common functions
# http response를 stdout에 write 하는 함수
# $1: response code 및 메시지, $2는 response body
respond() {
  printf 'Status: %s\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n%s\n' "$1" "$2"
}

# slack webhook으로 메시지 보내는 함수. webhook 주소는 agenix에서 가져옴.
slack() {
  local url payload
  url=$(sed -n 's/^SLACK_WEBHOOK_URL=//p' "$WEBHOOK_FILE" | head -n 1)
  url=${url#\"}
  url=${url%\"}
  [ -n "$url" ] || return 1
  payload=$(jq -cn --arg t "[builds] $1" '{text: $t}')
  # ps 출력에 url을 남기지 않게 하기 위해서 stdin으로 웹훅 url을 넘긴다고 한다 (by claude)
  printf 'url = "%s"\n' "$url" |
    curl -fsS --max-time 10 -K - -H 'Content-Type: application/json' --data "$payload" -o /dev/null
}

# 아직 읽지 않은 request body를 버릴 때 쓰는 함수. body를 남긴채 커넥션을 abort하지 않으려고 실패를 응답하기 전에 사용한다.
drain() {
  cat >/dev/null 2>&1 || true
}

# 실패 처리 함수
fail() {
  drain
  slack ":x: publish failed: id=$safe_id ($1) $2" || true
  respond "$1" "$2"
  exit 0
}

# 1. Slack 알람 처리
if ! slack ":inbox_tray: publish request: id=$safe_id from=$from method=$method bytes=${length:-none}"; then
  drain
  respond "503 Service Unavailable" "Slack notification failed; nothing was published"
  exit 0
fi
# 예상치 못한 실패를 만나게 될 때도 slack 알람을 보낸다.
trap 'fail "500 Internal Server Error" "unexpected error at line $LINENO"' ERR

# 2. request 검사
# method 타입 검사, publish ID 포맷 검사 등.
[ "$method" = POST ] || fail "405 Method Not Allowed" "method must be POST"
# app key rule matches the fastlane app_config check; publish and index.html would collide with the site's own paths.
[[ $app =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] && [ "$app" != publish ] && [ "$app" != index.html ] ||
  fail "400 Bad Request" "path must be /publish/<app key>/<publish id>, app key like whatseat"
[[ $id =~ ^[0-9]{8}-[0-9]{6}-[0-9a-f]{7,40}-[a-z][a-z0-9-]{0,31}$ ]] ||
  fail "400 Bad Request" "publish id must look like 20261031-000530-9e05a0e-qa-debug"
[[ $length =~ ^[0-9]+$ ]] || fail "411 Length Required" "Content-Length is required"

# 3. concurrent 요청에 대한 lock 처리
# publish 요청이 동시에 두개가 들어오면 flock을 써서 하나씩만 처리하도록 보장한다.
# 똑같은 publish ID가 이미 있을 경우 에러 처리 반환.
cd "$BUILDS_ROOT"
# 놀라운 문법: 9> 는 fd 9번을 .incoming/lock 에 여는 것이라고 함.. 이렇게 하고 flock을 fd 9에 대고서 걸면 스크립트가 끝날 때 fd가 사라지면서 flock도 풀린다.
# flock은 기본적으로 명령어 하나에 대해서민 잠그기 때문에, 이 스크립트 실행 전체에 대해서 lock을 걸기 위한 방법이라고 함. 놀랍다!
exec 9>.incoming/lock
flock -w 300 9 || fail "503 Service Unavailable" "another publish is still running"
[ ! -e "$app/releases/$id" ] || fail "409 Conflict" "release $app/$id already exists"

# 4. tar 파일 저장
# .incoming 이하에 임시 디렉터리를 만들고 (웹에 노출되지 않는다고 함, 실제로 확인하진 않음..)
# 스크립트가 종료되면 모주두 삭제하도록 만든다.
# tar 크기가 content-length와 다를 경우 뭔가 이상한걸로 간주하고 실패처리.
work=$(mktemp -d ".incoming/$id.XXXXXX")
trap 'rm -rf "$BUILDS_ROOT/$work"' EXIT
cat >"$work/upload.tar"
[ "$(stat -c %s "$work/upload.tar")" = "$length" ] ||
  fail "400 Bad Request" "body is shorter than Content-Length"

# 5. tar 내부 파일 검사.
# 최상위에 index.html, manifest.plist, .ipa 1개만 있어야 함.
# 그 외에 이상한 파일들이 섞여있으면 실패처리.
list=$(tar --warning=no-unknown-keyword -tf "$work/upload.tar" 2>/dev/null) ||
  fail "400 Bad Request" "body is not a tar archive"
ipa=$(printf '%s\n' "$list" | grep -E '^[A-Za-z0-9._-]+\.ipa$' || true)
expected=$(printf '%s\n' index.html manifest.plist release.json "$ipa" | sort)
[ -n "$ipa" ] && [ "$(printf '%s\n' "$list" | sort)" = "$expected" ] ||
  fail "400 Bad Request" "tar must hold exactly index.html, manifest.plist, release.json and one .ipa at the top level"

# 6. tar 풀기 및 파일 검사
# nginx가 읽을 수 있도록 권한을 디렉터리 755, 파일 644로 설정.
mkdir "$work/release"
tar --warning=no-unknown-keyword --no-same-owner --no-same-permissions \
  -xf "$work/upload.tar" -C "$work/release"
[ -z "$(find "$work/release" -mindepth 1 ! -type f)" ] ||
  fail "400 Bad Request" "tar members must be regular files"
chmod 0755 "$work/release"
chmod 0644 "$work/release"/*
jq -e 'type == "object" and ([.name, .version, .build, .kind, .commit, .built] | all(type == "string"))' \
  "$work/release/release.json" >/dev/null 2>&1 ||
  fail "400 Bad Request" "release.json must be an object with string name, version, build, kind, commit, built"

# 7. publish: tar 파일 푼 것을 <app key>/releases/<publish ID>로 옮기고 <app key>/current symlink를 교체한다.
# 참고: -T는 target path를 dir로 보지 않고 그냥 파일로 보는 옵션. 새 current symlink를 기존 current 디렉터리 하위로 옮기는게 아닌, 새로운 current로 만들기 위함.
mkdir -p "$app/releases"
mv -T "$work/release" "$app/releases/$id"
ln -s "releases/$id" "$work/current"
mv -T "$work/current" "$app/current"

# 8. stale한 publish들 GC clean up
# 앱마다 최근 KEEP_RELEASES개만 남김.
current=$(readlink "$app/current")
find "$app/releases" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -r | tail -n "+$((KEEP_RELEASES + 1))" |
  while read -r old; do
    [ "releases/$old" = "$current" ] || rm -rf "${app:?}/releases/$old"
  done

# 9. 목록 페이지 다시 만들기: /<app key>/index.html (빌드 목록), /index.html (앱 목록)
# One line per build from its release.json, HTML-escaped.
label() {
  jq -r '@html "\(.name) \(.version) (\(.build)) \(.kind), \(.built), \(.commit)"' "$1/release.json" 2>/dev/null ||
    printf '%s' "${1##*/}"
}
page() {
  printf '<!doctype html>\n<html lang="ko">\n<head>\n<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n<title>%s</title>\n' "$1"
  printf '<style>body { font-family: -apple-system, sans-serif; margin: 24px; line-height: 1.6; }</style>\n'
  printf '</head>\n<body>\n<h1>%s</h1>\n' "$1"
  cat
  printf '</body>\n</html>\n'
}
name=$(jq -r '.name | @html' "$app/current/release.json")
{
  printf '<p><a href="current/">최신 빌드</a> · <a href="/">앱 목록</a></p>\n<ul>\n'
  find "$app/releases" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -r | while read -r rel; do
    mark=
    if [ "releases/$rel" = "$current" ]; then mark=' (current)'; fi
    printf '<li><a href="releases/%s/">%s</a>%s</li>\n' "$rel" "$(label "$app/releases/$rel")" "$mark"
  done
  printf '</ul>\n'
} | page "$name ($app)" >"$work/app.html"
chmod 0644 "$work/app.html"
mv -T "$work/app.html" "$app/index.html"
{
  printf '<ul>\n'
  for dir in */; do
    dir=${dir%/}
    [ -L "$dir/current" ] || continue
    printf '<li><a href="/%s/">%s (%s)</a>: 최신 %s</li>\n' "$dir" \
      "$(jq -r '.name | @html' "$dir/current/release.json" 2>/dev/null || printf '%s' "$dir")" "$dir" "$(label "$dir/current")"
  done
  printf '</ul>\n'
} | page "iOS builds" >"$work/index.html"
chmod 0644 "$work/index.html"
mv -T "$work/index.html" index.html

# 10. slack 알람 보내기
slack ":white_check_mark: published $app/$id: $PUBLIC_URL/$app/releases/$id/" || true
respond "201 Created" "$PUBLIC_URL/$app/releases/$id/"
