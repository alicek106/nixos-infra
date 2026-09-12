# Cloudflare 개념 & 우리 구성 정리

siori.dev 블로그를 Cloudflare Tunnel 로 노출하는 구조의 개념 설명.
(Cloudflare 처음 쓰는 사람 기준. 리소스 정의는 `main.tf`, 실행법은 `README.md`.)

## 1. Cloudflare 가 뭔가

당신 도메인 **앞에 서는 거대한 프록시 + CDN**. 방문자는 당신 서버가 아니라 Cloudflare 에 먼저 접속하고,
Cloudflare 가 대신 당신 서버로 연결한다. 그 과정에서 **HTTPS 인증서 · 캐시 · DDoS 방어 · IP 숨김**을 무료로 해준다.
핵심 전제: **siori.dev 의 DNS·트래픽을 Cloudflare 에 맡긴다** (= siori.dev 를 Cloudflare 에 zone 으로 등록).

## 2. 요청 흐름 (방문자가 siori.dev 를 열 때)

```
방문자 브라우저
   │ ① https://siori.dev DNS 조회 → Cloudflare IP (집 IP 아님!)
   ▼
Cloudflare 엣지 (서울 icn06 등)
   │ ② HTTPS 종단 (Universal SSL 인증서로 siori.dev 제공)
   │ ③ "siori.dev origin 은 터널이네" → 터널로 라우팅
   ▼ (cloudflared 가 미리 열어둔 아웃바운드 터널로 밀어넣음)
cloudflared (서버의 데몬, systemd: cloudflared-blog)
   │ ④ ingress 규칙: siori.dev → http://127.0.0.1:8080
   ▼
로컬 nginx :8080 → /var/www/blog/current (Hugo 블로그)
```

**IP 가 숨는 이유**: `cloudflared` 가 서버에서 **바깥으로(아웃바운드)** Cloudflare 에 연결을 걸어둔다.
Cloudflare 는 그 연결로 요청을 되민다. 그래서 **집에 열어둔 포트가 없고**, 방문자는 Cloudflare IP 만 본다.
(`curl -sI https://siori.dev` → `server: cloudflare` 가 그 증거.)

## 3. Cloudflare 웹이 두 개다 (초보 함정)

- **`dash.cloudflare.com`** — 도메인 / DNS / SSL 등 (일반)
- **`one.dash.cloudflare.com`** — **Zero Trust** (Tunnel 은 여기!)

## 4. 우리가 만든 리소스 (역할 + 설정 + 웹 위치)

| 리소스 (main.tf) | 역할 | 적용된 설정 | 웹에서 보는 곳 |
|---|---|---|---|
| **Zone** (siori.dev) | DNS·프록시를 CF 가 관리하는 "그릇" | 상태 Active | dash → siori.dev → Overview (우측 API 박스에 Zone/Account ID) |
| **Tunnel** `cloudflare_zero_trust_tunnel_cloudflared` | CF ↔ 서버를 잇는 파이프 자체 | 이름 `siori-blog` + secret | Zero Trust → Networks → Tunnels → `siori-blog` (HEALTHY, connector=icn06) |
| **Tunnel config (ingress)** `..._config` | 어떤 호스트를 어디로 보낼지 | `siori.dev → http://127.0.0.1:8080`, 그 외 404 | 같은 터널 클릭 → Public Hostname 탭 |
| **DNS record** `cloudflare_dns_record` | siori.dev 를 터널로 연결 | CNAME `→ <터널ID>.cfargotunnel.com`, **Proxied(주황 구름)** | siori.dev → DNS → Records |
| **DNSSEC** `cloudflare_zone_dnssec` | DNS 위조 방지(서명) | 활성화, DS 레코드 생성 | siori.dev → DNS → Settings → DNSSEC |
| **token** `data..._token` | cloudflared 접속 토큰 읽기 | agenix `TUNNEL_TOKEN` 로 저장됨 | (웹에 리소스로 안 보임) |

### 주황 구름 vs 회색 구름 (DNS record의 Proxy status)
- **주황(Proxied)** = 트래픽이 Cloudflare 를 통과 → IP 숨김 + SSL + CDN + 방어. ← 우리 것
- **회색(DNS only)** = Cloudflare 는 DNS 응답만, 실제 IP 노출.

## 5. 자동으로 켜진 것 (우리가 안 만듦)

- **Universal SSL** — siori.dev 엣지 인증서를 CF 가 무료·자동 발급. ACME 없이 https 됨 (.dev HTTPS 강제 요건 충족).
  - 위치: siori.dev → SSL/TLS → Edge Certificates.

## 한 줄 정리

- **Cloudflare = 도메인 앞의 프록시.** siori.dev 를 zone 으로 맡기면 방문자는 CF 에만 접속, 집 IP 안 보임.
- **Tunnel + cloudflared = 포트 안 열고 아웃바운드로 잇는 파이프.** DNS(주황 구름)가 siori.dev 를 터널로,
  ingress 규칙이 로컬 nginx:8080 으로 전달.
- **볼 곳**: 터널은 Zero Trust(one.dash), DNS·SSL·DNSSEC 는 일반 dash.
