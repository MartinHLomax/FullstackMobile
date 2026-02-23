-- Migration script to add user-specific data isolation
-- Run this in your Supabase SQL Editor

-- Step 1: Add user_id column to ListItem table
ALTER TABLE public."ListItem"
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 2: Update existing rows to associate with current users (if any)
-- WARNING: This will assign ALL existing items to the first admin user
-- You may want to handle this differently based on your needs
UPDATE public."ListItem"
SET user_id = (SELECT id FROM auth.users LIMIT 1)
WHERE user_id IS NULL;

-- Step 3: Make user_id NOT NULL after migration
ALTER TABLE public."ListItem"
ALTER COLUMN user_id SET NOT NULL;

-- Step 4: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_listitem_user_id ON public."ListItem"(user_id);

-- Step 5: Drop the old overly permissive RLS policy
DROP POLICY IF EXISTS "all authenticated can CRUD" ON public."ListItem";

-- Step 6: Create new user-specific RLS policies

-- Policy for SELECT: Users can only see their own items
CREATE POLICY "Users can view own items"
ON public."ListItem"
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Policy for INSERT: Users can only create items for themselves
CREATE POLICY "Users can create own items"
ON public."ListItem"
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy for UPDATE: Users can only update their own items
CREATE POLICY "Users can update own items"
ON public."ListItem"
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy for DELETE: Users can only delete their own items
CREATE POLICY "Users can delete own items"
ON public."ListItem"
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Step 7: Ensure RLS is enabled (should already be enabled)
ALTER TABLE public."ListItem" ENABLE ROW LEVEL SECURITY;

-- Step 8: Grant necessary permissions
GRANT ALL ON public."ListItem" TO authenticated;
GRANT USAGE ON SEQUENCE public."ListItem_id_seq" TO authenticated;

-- Optional: Create a shared list feature (for future use)
-- This creates a table for sharing lists between users
CREATE TABLE IF NOT EXISTS public.shared_lists (
    id BIGSERIAL PRIMARY KEY,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    shared_with_email TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(owner_id, shared_with_email)
);

-- RLS for shared_lists table
ALTER TABLE public.shared_lists ENABLE ROW LEVEL SECURITY;

-- Users can see shares they own or are shared with
CREATE POLICY "Users can view relevant shares"
ON public.shared_lists
FOR SELECT
TO authenticated
USING (
    owner_id = auth.uid()
    OR
    shared_with_email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

-- Only owners can create/delete shares
CREATE POLICY "Owners can manage shares"
ON public.shared_lists
FOR ALL
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- Update the ListItem RLS to include shared access (optional enhancement)
DROP POLICY IF EXISTS "Users can view own items" ON public."ListItem";

CREATE POLICY "Users can view own and shared items"
ON public."ListItem"
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR
    EXISTS (
        SELECT 1 FROM public.shared_lists
        WHERE owner_id = public."ListItem".user_id
        AND shared_with_email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
);

-- Add realtime for shared_lists table (optional)
ALTER PUBLICATION supabase_realtime ADD TABLE public.shared_lists;

COMMENT ON COLUMN public."ListItem".user_id IS 'Owner of this list item';
COMMENT ON TABLE public.shared_lists IS 'Table for managing shared shopping lists between users';

-- =============================================================
-- Connection Log: tracks site visits and auth events
-- =============================================================

-- Create the connection_log table
CREATE TABLE IF NOT EXISTS public.connection_log (
    id         BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Who (nullable: if user is deleted, we keep the log)
    user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    email      TEXT,

    -- What happened
    event_type TEXT NOT NULL,  -- 'page_load', 'SIGNED_IN', 'SIGNED_OUT'

    -- Browser / device info
    user_agent TEXT,
    language   TEXT,
    platform   TEXT,
    screen_w   INT,
    screen_h   INT,
    viewport_w INT,
    viewport_h INT,
    referrer   TEXT,
    page_url   TEXT,

    -- PWA detection
    is_pwa     BOOLEAN NOT NULL DEFAULT FALSE,

    -- Connection info (experimental API, may be null)
    connection_type TEXT,
    is_online  BOOLEAN NOT NULL DEFAULT TRUE
);

-- Indexes for querying by user and time
CREATE INDEX IF NOT EXISTS idx_connection_log_user_id ON public.connection_log(user_id);
CREATE INDEX IF NOT EXISTS idx_connection_log_created_at ON public.connection_log(created_at DESC);

-- Enable RLS
ALTER TABLE public.connection_log ENABLE ROW LEVEL SECURITY;

-- INSERT: authenticated users can log their own entries
CREATE POLICY "Authenticated users can insert connection logs"
ON public.connection_log
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- SELECT: all authenticated users can read all logs (invite-only, trusted)
CREATE POLICY "Authenticated users can read all connection logs"
ON public.connection_log
FOR SELECT
TO authenticated
USING (true);

-- No UPDATE or DELETE policies: logs are immutable from client side

-- Grant permissions
GRANT INSERT, SELECT ON public.connection_log TO authenticated;
GRANT USAGE ON SEQUENCE public.connection_log_id_seq TO authenticated;

COMMENT ON TABLE public.connection_log IS 'Tracks site visits and auth events for auditing';

-- =============================================================
-- Tab support: Add list_id column to ListItem
-- =============================================================

-- Add list_id column (existing items default to 'shopping')
ALTER TABLE public."ListItem"
ADD COLUMN IF NOT EXISTS list_id TEXT NOT NULL DEFAULT 'shopping';

-- Only allow known list IDs
ALTER TABLE public."ListItem"
ADD CONSTRAINT chk_list_id CHECK (list_id IN ('shopping', 'memo'));

-- Composite index for per-user per-list queries
CREATE INDEX IF NOT EXISTS idx_listitem_user_list
ON public."ListItem"(user_id, list_id);