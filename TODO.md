# TODO & Changelog

## Seneste Sikkerhedsopdatering (2025-09-19)

### Hvad der skulle fikses:
- **KRITISK**: Eksponeret Supabase API nøgle uden data isolation
- **KRITISK**: Manglende .gitignore fil
- **HØJ**: Svag Row Level Security - alle brugere kunne se/redigere alles data
- **MEDIUM**: Ingen input validering (XSS risiko)
- **MEDIUM**: Manglende Content Security Policy
- **LAV**: For detaljeret teknisk dokumentation i public repo

### Hvad der blev gjort:

#### Database ændringer:
- ✅ Tilføjet `user_id` kolonne til ListItem tabel
- ✅ Implementeret user-specifik RLS (brugere ser kun egne items)
- ✅ Oprettet migration script (`supabase_migration.sql`)

#### Frontend ændringer:
- ✅ Tilføjet Content Security Policy header
- ✅ Input validering og sanitering (HTML tags, max 100 chars)
- ✅ Email format validering
- ✅ Antal validering (1-99)
- ✅ Auto-tilføjelse af user_id ved nye items

#### Build system:
- ✅ Environment variable håndtering via config.js
- ✅ Build script til at injicere credentials
- ✅ Template system (index.template.html)

#### Dokumentation:
- ✅ Forenklet README.md
- ✅ Tekniske detaljer flyttet til TECHNICAL_DOCS.md
- ✅ Rate limiting guide tilføjet
- ✅ .gitignore fil oprettet

### Potentielle problemer efter opdatering:

#### 1. **Eksisterende data forsvinder**
- **Årsag**: Migration tildeler alle items til første bruger
- **Løsning**: Manuelt opdater user_id i databasen eller redistribuer items

#### 2. **Login virker ikke**
- **Årsag**: RLS policies er for restriktive
- **Løsning**: Verificer at migration kørte korrekt, check RLS policies

#### 3. **Kan ikke oprette nye items**
- **Årsag**: Manglende user_id eller input validering fejler
- **Løsning**: Check browser console, verificer user er logget ind

#### 4. **CSP blokerer scripts/styles**
- **Årsag**: Content Security Policy er for streng
- **Løsning**: Check console for CSP violations, juster policy hvis nødvendigt

#### 5. **Build fejler**
- **Årsag**: config.js mangler eller har forkerte værdier
- **Løsning**: Kopier config.template.js til config.js og udfyld værdier

### Deployment checklist:
- [ ] Kør database migration i Supabase SQL Editor
- [ ] Opret config.js fra template
- [ ] Kør `node build.js`
- [ ] Test lokalt at alt virker
- [ ] Commit og push ændringer

### Næste mulige forbedringer:
- [ ] Implementer rate limiting (se RATE_LIMITING_GUIDE.md)
- [ ] Tilføj delt liste funktionalitet
- [ ] Implementer optimistic UI updates
- [ ] Tilføj bruger profiler med avatars
- [ ] Implementer søgning og filtrering
- [ ] Tilføj kategorier til items
- [ ] Export/import funktionalitet

### Rollback procedure:
Hvis noget går galt:
1. Gendan original RLS policy (se backup i SECURITY_UPDATES.md)
2. Fjern user_id kolonne requirement: `ALTER TABLE public."ListItem" ALTER COLUMN user_id DROP NOT NULL;`
3. Checkout tidligere version: `git checkout HEAD~1 index.html`
4. Fjern CSP header midlertidigt

### Support:
Ved problemer, check:
1. Browser console for JavaScript fejl
2. Network tab for 401/403 fejl (RLS issues)
3. Supabase logs for database fejl
4. SECURITY_UPDATES.md for detaljeret dokumentation