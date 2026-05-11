# cet.co.th — CET (Thailand) Co., Ltd.

A simple bilingual (TH/EN) one-page company website for **CET (Thailand) Company Limited**, used as the official corporate site for App Store / Google Play Store identity verification.

## Stack

Plain **HTML + CSS + vanilla JavaScript**. No build step required.

```
.
├── index.html
├── assets/
│   ├── style.css
│   ├── script.js     # i18n + lang switch
│   ├── logo.svg
│   └── favicon.svg
├── robots.txt
├── sitemap.xml
└── README.md
```

## Run locally

Any static file server works. For example:

```bash
# from the project root
python3 -m http.server 5173
# then open http://localhost:5173
```

Or with Node:

```bash
npx serve .
```

## Deploy

Since this is fully static, you can deploy it to:

- **Netlify** — drag-and-drop the folder, or connect the Git repo.
- **Vercel** — `vercel deploy` from the project root.
- **Cloudflare Pages** — connect the repo, no build command, output dir `/`.
- **GitHub Pages** — push to `gh-pages` branch.
- **Any traditional host / cPanel** — upload all files to the public web root.

After deploying, point the `cet.co.th` domain at the hosting provider's nameservers or A/CNAME records.

## Editing content

- Text is bilingual via `assets/script.js` (`I18N.en` / `I18N.th`). Update those dictionaries to change copy in either language.
- Static elements (legal entity name, registration number, email, phone, address) are in `index.html`.

## Company info reflected on the site

- **Legal Entity:** CET (Thailand) Company Limited
- **Local Name:** บริษัท ซีอีที (ไทยแลนด์) จำกัด
- **Registration No.:** 0105560145831
- **Founded:** 30 August 2017
- **Registered Capital:** 1,000,000 THB
- **Address:** 559/101 Soi Suea Yai Uthit, Chatuchak, Bangkok 10900, Thailand
- **Phone:** +66 86 327 3566
- **Apple Team ID:** MR3FF57WDB
- **Products:** easysub.io (live), easysub mobile app (launching on App Store & Google Play)
