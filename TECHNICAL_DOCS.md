# Technical Documentation

## Detailed Architecture
```
[Browser / PWA]
   ├─ UI (index.html, vanilla JS)
   ├─ Supabase JS v2 (auth, queries, realtime)
   ├─ Persistent sessions (localStorage)
   └─ Service Worker (offline shell + asset cache)
        │
        ▼
[Supabase Backend]
   ├─ Postgres (table: public."ListItem")
   ├─ Auth (invite-only)
   ├─ Row Level Security (RLS)
   └─ Realtime (listen for changes)
```

## Database Schema

### Table: `public."ListItem"`
```sql
create table if not exists public."ListItem" (
  id bigserial primary key,
  "itemName" text not null,
  quantity int not null default 1,
  user_id uuid references auth.users(id) on delete cascade not null
);
```

### RLS Policies
- Users can only view their own items
- Users can only create items for themselves
- Users can only update their own items
- Users can only delete their own items

### Optional: Shared Lists Table
```sql
create table if not exists public.shared_lists (
    id bigserial primary key,
    owner_id uuid references auth.users(id) on delete cascade not null,
    shared_with_email text not null,
    created_at timestamp with time zone default now(),
    unique(owner_id, shared_with_email)
);
```

## File Structure
```
/
├─ index.html                # Main UI (production)
├─ index.template.html       # Template with placeholders
├─ config.template.js        # Configuration template
├─ config.js                 # Actual configuration (not in git)
├─ build.js                  # Build script
├─ manifest.webmanifest      # PWA manifest
├─ sw.js                     # Service Worker
├─ supabase_migration.sql    # Database migration
└─ icons/
   ├─ icon-192.png
   └─ icon-512.png
```

## Security Features

### Input Validation
- HTML/script tag removal
- Character limit (100 chars)
- Dangerous character filtering
- Danish character support
- Email format validation
- Quantity range validation (1-99)

### Content Security Policy
- Restricts script sources to self and trusted CDNs
- Blocks inline scripts (except where necessary)
- Prevents framing attacks
- Forces HTTPS

### Row Level Security
- User-specific data isolation
- Auth-based access control
- Optional sharing mechanism

## Build Process

1. Configuration stored in `config.js` (gitignored)
2. Build script reads config and injects into template
3. Produces production-ready `index.html`
4. Deploy to GitHub Pages

## PWA Features

### Service Worker Strategy
- Navigation: Network-first, fallback to cache
- Assets: Cache-first
- Supabase API: Never cached (always fresh)

### Manifest Configuration
```json
{
  "name": "Shopping List",
  "short_name": "Shopping",
  "start_url": "./?source=pwa",
  "scope": "./",
  "display": "standalone"
}
```

## Supabase Configuration

### Auth Settings
- Self-signups: OFF
- Invite-only: ON
- Magic link with `shouldCreateUser: false`
- Persistent sessions via localStorage

### Realtime
```sql
alter publication supabase_realtime add table public."ListItem";
```

## API Integration

### Client Initialization
```javascript
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: window.localStorage
  }
});
```

### Realtime Subscription
```javascript
supabase.channel('realtime:ListItem')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'ListItem' }, () => loadItems())
  .subscribe();
```

## Deployment Notes

### GitHub Pages
- Repository pages run under path (/REPO/)
- Use `window.location.href` for correct redirects
- Update Site URL in Supabase after deployment

### Environment Variables
- Never commit `config.js`
- Use build script for production deployments
- Keep `index.template.html` in version control

## Troubleshooting

### Common Issues
- **401 errors**: Check RLS policies and user authentication
- **Redirect failures**: Verify URLs in Supabase Auth config
- **Realtime not updating**: Check publication settings
- **PWA not detected**: Verify manifest and service worker paths

### Debug Commands
```sql
-- Check RLS policies
select * from pg_policies where tablename = 'ListItem';

-- Check realtime subscription
select * from pg_publication_tables where pubname = 'supabase_realtime';
```

## Performance Optimizations

- Debounced realtime updates
- Cached assets via Service Worker
- Minimal dependencies (vanilla JS)
- Lazy loading for PWA resources

## Future Enhancements

- User profiles with avatars
- List categories/tags
- Search and filtering
- Export/import functionality
- Optimistic UI updates
- Push notifications for shared lists