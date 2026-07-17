-- Extension 4: Meal Planning
-- Complete meal planning system with RLS for shared household access

-- Recipe collection
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    cuisine TEXT,
    prep_time_minutes INTEGER,
    cook_time_minutes INTEGER,
    servings INTEGER,
    ingredients JSONB NOT NULL DEFAULT '[]', -- array of {name, quantity, unit}
    instructions JSONB NOT NULL DEFAULT '[]', -- array of step strings
    tags TEXT[] DEFAULT '{}',
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Weekly meal planning
CREATE TABLE meal_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    week_start DATE NOT NULL, -- should be a Monday
    day_of_week TEXT NOT NULL, -- 'monday', 'tuesday', etc.
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    recipe_id UUID REFERENCES recipes,
    custom_meal TEXT, -- for meals without a recipe
    servings INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-generated or manual grocery lists
CREATE TABLE shopping_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    week_start DATE NOT NULL,
    items JSONB NOT NULL DEFAULT '[]', -- array of {name, quantity, unit, purchased: bool, recipe_id}
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX idx_recipes_user_cuisine ON recipes(user_id, cuisine);
CREATE INDEX idx_recipes_user_tags ON recipes USING GIN (tags);
CREATE INDEX idx_meal_plans_user_week ON meal_plans(user_id, week_start);
CREATE INDEX idx_shopping_lists_user_week ON shopping_lists(user_id, week_start);

-- The household_member role
--
-- The policies below grant household access on the condition
--   auth.jwt() ->> 'role' = 'household_member'
-- which can only ever be true if `household_member` exists as a real Postgres
-- role: Supabase mints every secret key from a JWT template, and PostgREST
-- switches into the role named in that template's `role` claim. Without this
-- block the policies are unreachable and the shared server has no working key.
--
-- Do NOT reach for an ordinary secret key instead. Every one is minted from the
-- default template {"role": "service_role"}, which BYPASSES RLS -- the shared
-- server would work while holding your entire database, the opposite of what it
-- is for. Mint its key from a {"role": "household_member"} template.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'household_member') THEN
        -- NOLOGIN: only ever entered through PostgREST's SET ROLE.
        -- NOINHERIT: matches how Supabase defines anon/authenticated.
        -- Deliberately NOT BYPASSRLS -- that flag would void every policy below.
        CREATE ROLE household_member NOLOGIN NOINHERIT;
    END IF;
END
$$;

-- PostgREST connects as `authenticator` and switches roles. Without this grant
-- the request fails before any policy is consulted.
GRANT household_member TO authenticator;

GRANT USAGE ON SCHEMA public TO household_member;

-- Least privilege, and the first of two independent limits: a household member
-- cannot touch any table not named here -- not because a policy forbids it, but
-- because the grant was never made. RLS below then decides which rows.
GRANT SELECT ON recipes    TO household_member;
GRANT SELECT ON meal_plans TO household_member;

-- SELECT as well as UPDATE: mark_item_purchased reads the list, flips one item,
-- and writes it back. No INSERT or DELETE -- a household member may tick items
-- off, never add or destroy a list.
GRANT SELECT, UPDATE ON shopping_lists TO household_member;

-- Enable Row Level Security
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_lists ENABLE ROW LEVEL SECURITY;

-- RLS Policies for recipes
CREATE POLICY "Users can CRUD their own recipes"
    ON recipes
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Household members can view recipes"
    ON recipes
    FOR SELECT
    USING (
        auth.jwt() ->> 'role' = 'household_member'
        OR auth.uid() = user_id
    );

-- RLS Policies for meal_plans
CREATE POLICY "Users can CRUD their own meal plans"
    ON meal_plans
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Household members can view meal plans"
    ON meal_plans
    FOR SELECT
    USING (
        auth.jwt() ->> 'role' = 'household_member'
        OR auth.uid() = user_id
    );

-- RLS Policies for shopping_lists
CREATE POLICY "Users can CRUD their own shopping lists"
    ON shopping_lists
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Household members can view shopping lists"
    ON shopping_lists
    FOR SELECT
    USING (
        auth.jwt() ->> 'role' = 'household_member'
        OR auth.uid() = user_id
    );

CREATE POLICY "Household members can update shopping lists"
    ON shopping_lists
    FOR UPDATE
    USING (
        auth.jwt() ->> 'role' = 'household_member'
        OR auth.uid() = user_id
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'household_member'
        OR auth.uid() = user_id
    );
