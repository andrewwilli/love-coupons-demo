-- ─────────────────────────────────────────────────────────────────
-- Love Coupons (Demo / friend-friendly edition) — Supabase Schema
-- Run this in the Supabase SQL Editor of a NEW, SEPARATE project.
-- Do NOT run it against the private project — the coupon set differs.
-- ─────────────────────────────────────────────────────────────────

-- ── app_state ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_state (
  id         INT PRIMARY KEY DEFAULT 1,
  kisses     INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);

-- Seed with a demo balance so the app looks alive when shown to friends
INSERT INTO app_state (id, kisses) VALUES (1, 18)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE OR REPLACE TRIGGER app_state_updated_at
BEFORE UPDATE ON app_state
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ── coupons ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coupons (
  id           TEXT PRIMARY KEY,
  emoji        TEXT NOT NULL DEFAULT '💋',
  title        TEXT NOT NULL,
  kisses       INT  NOT NULL DEFAULT 5,
  teaser       TEXT NOT NULL DEFAULT '',
  description  TEXT NOT NULL DEFAULT '',
  note         TEXT,
  inputs       JSONB NOT NULL DEFAULT '[]',
  status       TEXT NOT NULL DEFAULT 'active'
               CHECK (status IN ('active', 'pending', 'rejected')),
  suggested_by TEXT NOT NULL DEFAULT 'admin'
               CHECK (suggested_by IN ('admin', 'user')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed friend-friendly coupons (idempotent).
-- Costs are spread across the three visual tiers:
--   Tier 1 (Sweet,   ≤10) · Tier 2 (Romantic, 11–20) · Tier 3 (21+)
INSERT INTO coupons (id, emoji, title, kisses, teaser, description, note, inputs) VALUES
(
  'massage', '💆‍♀️', 'Full Body Massage with Oil', 7,
  'You relax — management does all the work',
  'You can relax/sleep, pick the music (if you like) and management (me) does the work. Duration: until management''s hands are cramped or you fully fall asleep like a cat.',
  'You can tick options and focus, or leave them blank → management (me) will decide for you.',
  '[{"id":"style","type":"pills","label":"Style (choose one)","max":1,"options":["Firm massage","Relax massage","Mmmh-don''t-know"]},{"id":"focus","type":"pills","label":"Focus — max 2","max":2,"options":["Feet","Hands","Back","Neck","Legs","Shoulders"]}]'
),
(
  'breakfast', '🍳', 'Breakfast in Bed', 6,
  'Wake up — food comes to you',
  'You stay in bed, I make breakfast and bring it to you. Coffee/tea included. You choose what you are in the mood for.',
  NULL,
  '[{"id":"craving","type":"pills","label":"What are you craving?","max":2,"options":["Sweet","Savory","Pancakes","Eggs","Fruit","Surprise me"]}]'
),
(
  'movienight', '🎬', 'Movie Night — You Pick', 5,
  'Your movie, your snacks, zero complaints',
  'You choose the movie (yes, even that one). I make the snacks and I am not allowed to complain — not even once.',
  '→ Blanket fort optional but encouraged.',
  '[{"id":"snacks","type":"pills","label":"Snacks","max":2,"options":["Popcorn","Chocolate","Chips","Ice cream","Tea"]}]'
),
(
  'royalty', '👑', 'Royalty Treatment', 8,
  'You are officially Queen — command at will',
  'You are officially Queen for the day. You can command while the crown is on your head. I will do everything that is reasonably possible to serve Her Majesty.',
  '→ No crown, no royalty treatment.',
  '[]'
),
(
  'compliments', '💌', 'Full Day of Compliments & Love Notes', 12,
  'A whole day of love, notes & compliments',
  'Fill in the date — for the time we are awake, this effect takes place! You cannot eye-roll. Notes are hidden around during the day (and if possible the day before).',
  NULL,
  '[{"id":"date","type":"date","label":"Choose your day","countdown":true}]'
),
(
  'tshirt', '👕', 'T-Shirt of Your Choice', 15,
  'Pick any shirt — it is yours',
  'You get to choose one t-shirt and it is yours to keep. No hoodie, only t-shirt! Bonus points if you model it for a quick photo.',
  NULL,
  '[]'
),
(
  'bake', '🧁', 'Bake Something Together', 14,
  'We bake — you lick the spoon',
  'We pick a recipe and bake it together. You are on official spoon-licking and taste-testing duty. I handle the dishes afterwards.',
  NULL,
  '[{"id":"treat","type":"pills","label":"What should we bake?","max":1,"options":["Cookies","Brownies","Cake","Muffins","You decide"]}]'
),
(
  'datenight', '🌙', 'Date Night Planner', 30,
  'Management plans & executes a perfect date',
  'Management (me) will plan and execute a full date night — surprise included. The exact date will be discussed. If food is involved, chef accepts "fein" and thank-yous as payment.',
  NULL,
  '[{"id":"date","type":"date","label":"Preferred date (to be confirmed with management)","countdown":true}]'
),
(
  'adventure', '🚗', 'Surprise Adventure Day', 25,
  'You show up — I handle the rest',
  'A full surprise day out. You do not get to know where we are going until we get there. Just show up with comfy shoes and good vibes.',
  '→ Destination revealed on arrival only.',
  '[{"id":"vibe","type":"pills","label":"Todays vibe (optional)","max":1,"options":["Chill","Active","Foodie","Surprise me"]}]'
)
ON CONFLICT (id) DO NOTHING;

-- ── coupon_inputs ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coupon_inputs (
  id         BIGSERIAL PRIMARY KEY,
  coupon_id  TEXT NOT NULL UNIQUE,
  inputs     JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE TRIGGER coupon_inputs_updated_at
BEFORE UPDATE ON coupon_inputs
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ── redemptions ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS redemptions (
  id            BIGSERIAL PRIMARY KEY,
  coupon_id     TEXT NOT NULL,
  redeemed_date TEXT NOT NULL,
  ts            BIGINT NOT NULL,
  inputs        JSONB NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS redemptions_coupon_id_idx ON redemptions (coupon_id);
CREATE INDEX IF NOT EXISTS redemptions_ts_idx        ON redemptions (ts DESC);

-- ── activity_log ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_log (
  id         BIGSERIAL PRIMARY KEY,
  type       TEXT NOT NULL CHECK (type IN ('credit', 'redeem')),
  amount     INT NOT NULL,
  note       TEXT,
  coupon_id  TEXT,
  ts         BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS activity_log_ts_idx ON activity_log (ts DESC);

-- ─────────────────────────────────────────────────────────────────
-- Row Level Security — anon key is the only auth layer (PIN in frontend)
-- ─────────────────────────────────────────────────────────────────
ALTER TABLE app_state     ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons       ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE redemptions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon read app_state"   ON app_state FOR SELECT TO anon USING (true);
CREATE POLICY "anon update app_state" ON app_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon all coupons"       ON coupons       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon all coupon_inputs" ON coupon_inputs FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon all redemptions"   ON redemptions   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon all activity_log"  ON activity_log  FOR ALL TO anon USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────
-- Realtime
-- ─────────────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE app_state;
ALTER PUBLICATION supabase_realtime ADD TABLE coupons;
