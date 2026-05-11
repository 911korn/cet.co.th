# Deploy & Domain Setup — cet.co.th

## Current setup

- **GitHub repo:** https://github.com/911korn/cet.co.th
- **Vercel project:** `911korns-projects/cet.co.th`
- **Vercel preview alias:** https://cetcoth.vercel.app
- **Auto-deploy:** every push to `main` triggers a production deploy on Vercel.

## Connect `cet.co.th` via Cloudflare (when domain is active)

Add these records in the **Cloudflare DNS** dashboard for the `cet.co.th` zone:

| Type  | Name | Content                  | Proxy status      | TTL  |
|-------|------|--------------------------|-------------------|------|
| A     | `@`  | `76.76.21.21`            | **DNS only (gray cloud)** | Auto |
| CNAME | `www`| `cname.vercel-dns.com`   | **DNS only (gray cloud)** | Auto |

> Important: keep the Cloudflare proxy **off** (gray cloud, "DNS only") on both records. Vercel must issue and serve its own SSL certificate; proxying via Cloudflare causes double-proxy / certificate issues.

### Cloudflare SSL/TLS mode

Set **SSL/TLS → Overview** to **Full (strict)**. Vercel serves a valid public certificate, so Full (strict) works correctly.

### Verify after DNS propagates

```bash
dig +short cet.co.th
# expected: 76.76.21.21

dig +short www.cet.co.th
# expected: cname.vercel-dns.com.

curl -sS -o /dev/null -w "%{http_code}\n" https://cet.co.th
# expected: 200
```

Vercel automatically detects valid DNS and issues an SSL certificate within a few minutes.

## Local development

```bash
python3 -m http.server 5173
# open http://localhost:5173
```

## Manual redeploy

```bash
vercel deploy --prod
```

Or simply `git push` — Vercel auto-deploys from the connected GitHub repo.
