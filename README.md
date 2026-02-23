# Shopping List · Supabase + GitHub Pages

En serverless full-stack shopping list app med realtime sync mellem brugere.

## Features
- 🔐 Invite-only login system
- 📱 PWA - kan installeres på mobil
- 🔄 Realtime opdateringer
- 💾 Persistent login
- 📱 Mobil-venlig design

## Demo
Live demo: `https://[dit-brugernavn].github.io/[repo-navn]/`

## Opsætning

### 1. Fork dette repository

### 2. Konfigurer Supabase
- Opret et projekt på [Supabase](https://supabase.com)
- Kør migration scriptet (`supabase_migration.sql`) i SQL Editor
- Konfigurer authentication (se Authentication Guide nedenfor)

### 3. Konfigurer applikationen
1. Kopier `config.template.js` til `config.js`
2. Indtast dine Supabase credentials i `config.js`
3. Kør build scriptet: `node build.js`

### 4. Deploy til GitHub Pages
- Push dine ændringer
- Aktiver GitHub Pages i repository settings
- Din app er nu live!

## Authentication Guide

### Invite-Only Setup
1. Gå til **Auth → General** i Supabase
2. Slå **Allow new users to sign up** fra
3. Inviter brugere via **Auth → Users → Invite user**

### URL Configuration
Sæt følgende i **Auth → URL Configuration**:
- **Site URL**: `https://[brugernavn].github.io/[repo]/`
- **Additional Redirect URLs**: Din lokale test URL

## Lokal udvikling
```bash
# Installer dependencies (hvis du vil bruge build script)
npm install

# Start lokal server
npx serve .
# eller brug VS Code Live Server
```

## Scripts
- `node build.js` - Injicerer environment variabler fra config.js

## Sikkerhed
- ✅ User data isolation via Row Level Security
- ✅ Input validation og sanitering
- ✅ Content Security Policy
- ✅ Environment variable håndtering

Se `SECURITY_UPDATES.md` for detaljer om sikkerhedsforbedringer.

## Support
For hjælp, opret et issue i dette repository.

## License
Open source - brug frit i egne projekter.