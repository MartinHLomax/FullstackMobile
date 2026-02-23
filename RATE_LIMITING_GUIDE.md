# Rate Limiting Guide for Supabase

## Hvorfor Rate Limiting?
Rate limiting beskytter din applikation mod:
- DDoS angreb
- Brute force angreb
- API misbrug
- Uventede omkostninger

## Implementering i Supabase

### 1. Database-niveau Rate Limiting

Opret en rate limiting funktion i SQL Editor:

```sql
-- Rate limiting table
CREATE TABLE IF NOT EXISTS public.rate_limits (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    count INT DEFAULT 1,
    window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, action)
);

-- Function to check rate limit
CREATE OR REPLACE FUNCTION check_rate_limit(
    p_user_id UUID,
    p_action TEXT,
    p_max_requests INT,
    p_window_minutes INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_count INT;
    v_window_start TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get current count and window start
    SELECT count, window_start INTO v_count, v_window_start
    FROM rate_limits
    WHERE user_id = p_user_id AND action = p_action;

    -- If no record exists or window has expired, reset
    IF v_window_start IS NULL OR
       v_window_start < NOW() - INTERVAL '1 minute' * p_window_minutes THEN
        INSERT INTO rate_limits (user_id, action, count, window_start)
        VALUES (p_user_id, p_action, 1, NOW())
        ON CONFLICT (user_id, action)
        DO UPDATE SET count = 1, window_start = NOW();
        RETURN TRUE;
    END IF;

    -- Check if limit exceeded
    IF v_count >= p_max_requests THEN
        RETURN FALSE;
    END IF;

    -- Increment counter
    UPDATE rate_limits
    SET count = count + 1
    WHERE user_id = p_user_id AND action = p_action;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Example: Rate limit for creating items (max 30 per 5 minutes)
CREATE OR REPLACE FUNCTION rate_limited_insert_item()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT check_rate_limit(NEW.user_id, 'create_item', 30, 5) THEN
        RAISE EXCEPTION 'Rate limit exceeded. Max 30 items per 5 minutes.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to ListItem table
CREATE TRIGGER enforce_rate_limit
BEFORE INSERT ON public."ListItem"
FOR EACH ROW
EXECUTE FUNCTION rate_limited_insert_item();
```

### 2. API Rate Limiting med Edge Functions

Opret en Edge Function for rate limiting:

```typescript
// supabase/functions/rate-limiter/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RATE_LIMIT_WINDOW = 60000 // 1 minute in ms
const MAX_REQUESTS = 60 // Max requests per window

const rateLimitMap = new Map()

serve(async (req) => {
  const ip = req.headers.get('x-forwarded-for') || 'unknown'
  const now = Date.now()

  // Clean old entries
  for (const [key, data] of rateLimitMap.entries()) {
    if (now - data.windowStart > RATE_LIMIT_WINDOW) {
      rateLimitMap.delete(key)
    }
  }

  // Check rate limit
  const userData = rateLimitMap.get(ip) || { count: 0, windowStart: now }

  if (now - userData.windowStart > RATE_LIMIT_WINDOW) {
    // New window
    userData.count = 1
    userData.windowStart = now
  } else if (userData.count >= MAX_REQUESTS) {
    // Rate limit exceeded
    return new Response(
      JSON.stringify({ error: 'Rate limit exceeded' }),
      { status: 429, headers: { 'Content-Type': 'application/json' } }
    )
  } else {
    // Increment counter
    userData.count++
  }

  rateLimitMap.set(ip, userData)

  // Continue with request...
  return new Response(
    JSON.stringify({ success: true, remaining: MAX_REQUESTS - userData.count }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
```

### 3. Frontend Rate Limiting

Tilføj rate limiting i frontend:

```javascript
// Rate limiter class
class RateLimiter {
  constructor(maxRequests = 10, windowMs = 60000) {
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
    this.requests = [];
  }

  canMakeRequest() {
    const now = Date.now();
    // Remove old requests outside window
    this.requests = this.requests.filter(time => now - time < this.windowMs);

    if (this.requests.length >= this.maxRequests) {
      return false;
    }

    this.requests.push(now);
    return true;
  }

  getRemainingRequests() {
    const now = Date.now();
    this.requests = this.requests.filter(time => now - time < this.windowMs);
    return Math.max(0, this.maxRequests - this.requests.length);
  }
}

// Usage in your app
const itemCreateLimiter = new RateLimiter(30, 300000); // 30 requests per 5 minutes

async function addItem(name) {
  if (!itemCreateLimiter.canMakeRequest()) {
    alert(`Rate limit: Vent venligst. Du har ${itemCreateLimiter.getRemainingRequests()} forsøg tilbage.`);
    return;
  }

  // Continue with normal addItem logic...
}
```

### 4. Supabase Dashboard Rate Limiting

I Supabase Dashboard:

1. **Database → Settings → Connection Pooling**
   - Aktiver connection pooling
   - Sæt pool size baseret på dit behov

2. **Authentication → Settings → Rate Limits**
   - Email sending: Max 4 per time
   - SMS sending: Konfigurer efter behov

3. **API Settings**
   - Aktiver API rate limiting
   - Sæt reasonable limits baseret på din plan

## Anbefalede Rate Limits

### For Shopping List App:

| Action | Limit | Window | Niveau |
|--------|-------|--------|--------|
| Create Item | 30 | 5 min | Database |
| Update Item | 60 | 5 min | Database |
| Delete Item | 20 | 5 min | Database |
| Login Attempts | 5 | 15 min | Auth |
| API Calls | 1000 | 1 hour | API |

## Monitoring

### SQL Query for at tjekke rate limits:
```sql
-- Se aktuelle rate limits
SELECT
    u.email,
    r.action,
    r.count,
    r.window_start,
    NOW() - r.window_start as age
FROM rate_limits r
JOIN auth.users u ON u.id = r.user_id
ORDER BY r.count DESC;

-- Ryd gamle rate limit records
DELETE FROM rate_limits
WHERE window_start < NOW() - INTERVAL '1 hour';
```

## Testing Rate Limits

Test script til at verificere rate limiting virker:

```javascript
// Test rate limiting
async function testRateLimits() {
  const results = [];

  for (let i = 0; i < 35; i++) {
    try {
      const response = await supabase
        .from('ListItem')
        .insert({ itemName: `Test ${i}`, quantity: 1 });

      results.push({ attempt: i + 1, success: !response.error });
    } catch (error) {
      results.push({ attempt: i + 1, success: false, error: error.message });
    }

    // Small delay between requests
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  console.table(results);
  console.log(`Successful: ${results.filter(r => r.success).length}/35`);
}
```

## Best Practices

1. **Gradvis implementering**: Start med høje limits og juster ned
2. **Brugervenlig feedback**: Vis tydeligt når limits nås
3. **Differentierede limits**: Forskellige limits for forskellige handlinger
4. **Monitoring**: Log og overvåg rate limit hits
5. **Graceful degradation**: App skal stadig fungere ved rate limits

## Fejlfinding

### Problem: Rate limits rammer for hurtigt
- Øg window størrelse
- Øg max requests
- Implementer caching

### Problem: Rate limits virker ikke
- Tjek trigger er oprettet korrekt
- Verificer user_id bliver sat
- Tjek function permissions

### Problem: Performance issues
- Tilføj index på rate_limits table
- Implementer automatisk cleanup
- Overvej Redis for high-traffic

## Links
- [Supabase Rate Limiting Docs](https://supabase.com/docs/guides/platform/rate-limits)
- [PostgreSQL Triggers](https://www.postgresql.org/docs/current/sql-createtrigger.html)
- [Edge Functions Guide](https://supabase.com/docs/guides/functions)