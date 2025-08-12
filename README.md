# Shopping List · Supabase + GitHub Pages

En lille **serverless full‑stack JS** app: statisk frontend (GitHub Pages) der taler direkte med **Supabase** (Postgres + Auth + Realtime + RLS). Login er **invite‑only**, sessions er **persistente**, og sitet kan installeres som **PWA** på mobil.

---

## Arkitektur (overblik)
```
[Browser / PWA]
   ├─ UI (index.html, vanilla JS)
   ├─ Supabase JS v2 (auth, queries, realtime)
   ├─ Persistente sessions (localStorage)
   └─ Service Worker (offline shell + asset cache)
        │
        ▼
[Supabase Backend]
   ├─ Postgres (table: public."ListItem")
   ├─ Auth (invite‑only)
   ├─ Row Level Security (RLS)
   └─ Realtime (listen på ændringer)
```

**Vigtig pointe:** Anon key er offentlig i frontend, men **RLS‑policies** beskytter data. Ingen **service_role** nøgle i frontend.

---

## Stack & filer
```
/
├─ index.html                # UI + al klientside‑logik
├─ manifest.webmanifest      # PWA manifest
├─ sw.js                     # Service Worker (cache + offline shell)
└─ icons/
   ├─ icon-192.png
   └─ icon-512.png
```

- **Responsiv** layout, mobilvenlig.
- **PWA**: Add‑to‑Home‑Screen (Android), standalone visning, basic offline (app‑shell + assets; API‑kald kræver net).
- **Redirects** ved auth bruger `window.location.href` → korrekt retur‑sti for repo‑pages (`/BRUGER/REPO/`).

---

## Datamodel
**Table:** `public."ListItem"`
```sql
create table if not exists public."ListItem" (
  id bigserial primary key,
  "itemName" text not null,
  quantity int not null default 1
);

alter table public."ListItem" enable row level security;

-- Realtime (hvis ikke allerede tilføjet):
alter publication supabase_realtime add table public."ListItem";
```

### RLS‑policy (alle verificerede brugere må alt)
```sql
drop policy if exists "all authenticated can CRUD" on public."ListItem";
create policy "all authenticated can CRUD"
on public."ListItem"
for all
to authenticated
using (true)
with check (true);
```
> Bemærk: Vi kører **invite‑only** login, så “authenticated” = inviteret + verificeret bruger.

---

## Auth (invite‑only)
1. **Slå self‑signups fra**: *Auth → General → Allow new users to sign up = Off*.
2. **Invitér brugere**: *Auth → Users → Invite user* (eller via admin SDK på en server/Edge‑function – ikke fra browseren).
3. I `index.html` bruger magic link `shouldCreateUser: false` (opretter ikke nye brugere).
4. **Redirects/URLs** (*Auth → URL Configuration*):
   - **Site URL** = `https://BRUGER.github.io/REPO/`
   - **Additional Redirect URLs** = både din Pages‑URL og lokale URL (fx `http://127.0.0.1:5500`).
5. **GitHub OAuth (valgfri)**: kan være slået til; med self‑signups off kan nye GitHub‑brugere ikke oprette konto. Provider callback = Supabase’s callback‑URL.

---

## Persistente logins
`createClient(..., { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storage: localStorage }})`
- Session overlever reloads og fornyes automatisk.
- Der lyttes på `onAuthStateChange` for at opdatere UI.

---

## PWA
**manifest.webmanifest**
```json
{
  "name": "Shopping List",
  "short_name": "Shopping",
  "start_url": "./?source=pwa",
  "scope": "./",
  "display": "standalone",
  "background_color": "#0b1020",
  "theme_color": "#0b1020",
  "icons": [
    { "src": "icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
```
**sw.js** (kort fortalt)
- Cacher `index.html`, manifest og ikoner.
- **Navigation**: network‑first, fallback til cache.
- **Assets**: cache‑first.
- **Supabase API**: aldrig cached → altid frisk data.
> Husk at bump’e `CACHE`‑navnet ved nye deploys for at invalidere gammel cache.

---

## Konfiguration (index.html)
Søg/erstat:
```js
const SUPABASE_URL = "https://YOUR-PROJECT-ref.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
```

---

## Lokal kørsel
- **VS Code Live Server** → Åbn `index.html` → *Go Live* (fx `http://127.0.0.1:5500`).
- Alternativt: `npx http-server .` eller `npx serve .`
- Tilføj din lokale URL som **Additional Redirect URL** i Supabase Auth.

### Test
- Login (magic link eller GitHub). Invite‑only er aktiv.
- Opret, opdatér og slet varer. Realtime refresher listen.

---

## Deploy til GitHub Pages
1. Opret public repo, læg filerne i roden og push.
2. **Settings → Pages**: *Deploy from a branch* (`main` / root).
3. Vent 1 minut → appen ligger på `https://BRUGER.github.io/REPO/`.
4. Opdatér **Site URL**/Redirects i Supabase til den præcise Pages‑URL.

> Repo‑sider kører under en sti (/REPO/). Koden bruger `window.location.href` i `redirectTo`, så du lander tilbage på korrekt sti efter login.

---

## Fejlsøgning
- **401/permission denied** → Tjek at RLS‑policy’en `to authenticated using (true) with check (true)` findes, og at du faktisk er logget ind.
- **Redirect virker ikke / 404 efter login** → Mangler din Pages‑URL i Auth → URL Configuration? Brug `redirectTo: window.location.href` (allerede sat).
- **GitHub OAuth fejler** → Provider callback skal være **Supabase’s callback**. Tjek Client ID/Secret i Supabase.
- **Realtime opdaterer ikke** → Tilføj tabellen til `supabase_realtime` publication.
- **Mixed‑case tabelnavn** → `ListItem` kræver citattegn i SQL. Overvej `snake_case` fremover (`list_item`).
- **PWA ikke opdaget** → Tjek at `manifest.webmanifest` og `sw.js` ligger i roden, og at `icons/` indeholder 192/512‑ikoner.

---

## Roadmap / idéer
- **Delte lister** (rollemodel eller delingsnøgler).
- **Profiler** (tabel `profiles` m. avatar/display name) og visning i UI.
- **Edge Functions** til admin‑invites/webhooks.
- **Optimistic UI** (opdater UI før netværkssvar).
- **Søgning/filtrering** og sortering.

---

## Licens
Fri brug i interne/sideprojekter. Tilpas gerne og del videre.

