import { z } from "astro/zod";

import type { Database } from "@/db/database.types";
import type { TypedSupabaseClient } from "@/lib/supabase";

/**
 * Warstwa dostępu do tabeli `public.flashcards` (F-01).
 *
 * Funkcje przyjmują już utworzonego, typowanego klienta Supabase — wywołujący sprawdza `null`
 * z `createClient()`; moduł nie dotyka `astro:env/server` i nie tworzy klienta.
 * Izolację per właściciel egzekwuje RLS w bazie (`user_id` ustawia `default auth.uid()`),
 * dlatego żadna funkcja nie przyjmuje ani nie ustawia `user_id`.
 * Limity treści odpowiadają ograniczeniom CHECK z migracji `create_flashcards`
 * (Zod liczy jednostki UTF-16, Postgres znaki — Zod jest co najmniej tak surowy jak baza).
 */

export type Flashcard = Database["public"]["Tables"]["flashcards"]["Row"];
export type FlashcardSource = Database["public"]["Enums"]["flashcard_source"];

export const FLASHCARD_FRONT_MAX = 200;
export const FLASHCARD_BACK_MAX = 500;
export const FLASHCARD_SOURCES = ["ai", "ai-edited", "manual"] as const satisfies readonly FlashcardSource[];

export const flashcardInputSchema = z.object({
  front: z.string().trim().min(1).max(FLASHCARD_FRONT_MAX),
  back: z.string().trim().min(1).max(FLASHCARD_BACK_MAX),
  source: z.enum(FLASHCARD_SOURCES),
});

export type FlashcardInput = z.infer<typeof flashcardInputSchema>;

/** Aktywne (niesoftusunięte) fiszki zalogowanego użytkownika, od najnowszej. */
export async function listFlashcards(supabase: TypedSupabaseClient): Promise<Flashcard[]> {
  const { data, error } = await supabase
    .from("flashcards")
    .select("*")
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(`Nie udało się pobrać fiszek: ${error.message}`);
  }
  return data;
}

/** Zapisuje fiszkę zalogowanego użytkownika; treść jest walidowana i przycinana przed wysłaniem do bazy. */
export async function insertFlashcard(supabase: TypedSupabaseClient, input: FlashcardInput): Promise<Flashcard> {
  const parsed = flashcardInputSchema.parse(input);

  const { data, error } = await supabase.from("flashcards").insert(parsed).select().single();

  if (error) {
    throw new Error(`Nie udało się zapisać fiszki: ${error.message}`);
  }
  return data;
}
