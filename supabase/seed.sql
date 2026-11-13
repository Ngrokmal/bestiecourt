-- ============================================================================
-- Safe, non-secret seed data (question bank + harmless punishment catalogue).
-- Idempotent: safe to run more than once.
-- ============================================================================

insert into public.game_questions (game_type, prompt, category, locale, enabled)
values
  ('daily_roast', 'কে বেশি অজুহাত দেয়?', 'habits', 'bn', true),
  ('daily_roast', 'কে ৫ ঘণ্টা পরে reply দেয়?', 'habits', 'bn', true),
  ('daily_roast', 'কে খাবার চুরি করে?', 'food', 'bn', true),
  ('daily_roast', 'কে সবচেয়ে বেশি নাটক করে?', 'drama', 'bn', true),
  ('daily_roast', 'শেষ পিৎজা স্লাইস কে খেয়েছে?', 'food', 'bn', true),
  ('daily_roast', 'কে অ্যালার্ম বন্ধ করে আবার ঘুমায়?', 'habits', 'bn', true),
  ('daily_roast', 'কে ছবি তুলতে গিয়ে পোজ বেশি দেয়?', 'gentle', 'bn', true),
  ('daily_roast', 'কে প্ল্যান করে কখনো আসে না?', 'drama', 'bn', true),
  ('daily_roast', 'কে সব সময় "আমি তো বলেছিলাম" বলে?', 'habits', 'bn', true),
  ('daily_roast', 'কে বিল দেওয়ার সময় বাথরুমে যায়?', 'everyday', 'bn', true),
  ('daily_roast', 'কে সবচেয়ে বেশি মিম পাঠায়?', 'everyday', 'bn', true),
  ('daily_roast', 'কে গ্রুপ চ্যাটে শুধু seen করে?', 'habits', 'bn', true)
on conflict (game_type, locale, prompt) do nothing;

insert into public.punishments (code, display_text, category, coin_cost, enabled)
values
  (
    'silly_nickname',
    'এক রাউন্ডের জন্য বন্ধুকে একটি মজার ডাকনাম দিন।',
    'fun', 15, true
  ),
  (
    'emoji_only',
    '৫ মিনিট শুধু ইমোজি দিয়ে কথা বলুন (নিজে মেনে চলুন)।',
    'fun', 15, true
  ),
  (
    'funny_title',
    'নিজের প্রোফাইলে একটি মজার টাইটেল বেছে নিন।',
    'cosmetic', 15, true
  ),
  (
    'compliment_burst',
    'বন্ধুকে তিনটি সত্যিকারের প্রশংসা লিখে পাঠান।',
    'gentle', 15, true
  ),
  (
    'sticker_dare',
    'সবচেয়ে অদ্ভুত স্টিকারটি চ্যাটে পাঠান।',
    'fun', 15, true
  ),
  (
    'pizza_confession',
    'শেষ পিৎজা স্লাইসের সত্যিকারের কাহিনি স্বীকার করুন।',
    'food', 15, true
  )
on conflict (code) do nothing;

-- Title catalogue (earned titles are granted server-side in fn_resolve_match).
insert into public.title_catalog (code, label, description, emoji, enabled)
values
  ('reply_ghost', 'Reply Ghost', 'একটি ম্যাচ শেষ করেছেন', '👻', true),
  ('drama_queen', 'Drama Queen', '৫টি ম্যাচ খেলেছেন', '🎭', true),
  ('roast_champion', 'Roast Champion', '৩টি ম্যাচ জিতেছেন', '🏆', true)
on conflict (code) do nothing;

-- Friendship contract templates (always entertainment-only).
insert into public.contract_templates (code, title, clauses, enabled)
values
  (
    'fries_pact',
    'Fries শান্তি চুক্তি',
    '["বন্ধুর fries অনুমতি ছাড়া খাওয়া যাবে না।",
      "শেষ bite ভাগ করে খেতে হবে।",
      "ভাঙলে একটি মজার ইমোজি পাঠাতে হবে।"]'::jsonb,
    true
  ),
  (
    'reply_pact',
    'Reply শান্তি চুক্তি',
    '["seen করে পালানো যাবে না।",
      "৫ ঘণ্টার বেশি দেরি হলে একটি দুঃখিত স্টিকার বাধ্যতামূলক।",
      "জরিমানা শুধু মজার কসমেটিক, আসল কিছু নয়।"]'::jsonb,
    true
  ),
  (
    'bestie_pact',
    'Bestie চিরকালের চুক্তি',
    '["একজনের দুঃসময়ে অন্যজন থাকবে।",
      "গোপন কথা কারো সাথে শেয়ার হবে না।",
      "প্রতি সপ্তাহে অন্তত একটি মজার ম্যাচ খেলতে হবে।"]'::jsonb,
    true
  )
on conflict (code) do nothing;

-- Extra harmless punishments for the wheel.
insert into public.punishments (code, display_text, category, coin_cost, enabled)
values
  ('emoji_story', 'তিনটি ইমোজি দিয়ে আজকের দিনের গল্প বলুন।', 'fun', 15, true),
  ('silly_walk', 'ঘরে পাঁচ পা হাঁটুন "বেস্টি স্টাইল"-এ।', 'fun', 15, true),
  ('voice_note', 'বন্ধুকে একটি মজার কণ্ঠবার্তা পাঠান।', 'fun', 15, true)
on conflict (code) do nothing;
