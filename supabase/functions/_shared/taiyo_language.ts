export type TaiyoLanguageCode = "en" | "ar";

export function normalizeTaiyoLanguage(value: unknown): TaiyoLanguageCode {
  const normalized = typeof value === "string"
    ? value.trim().toLowerCase()
    : "";
  if (normalized === "ar" || normalized === "arabic") return "ar";
  if (normalized === "en" || normalized === "english") return "en";
  return "en";
}

export function languageNameFor(value: unknown) {
  return normalizeTaiyoLanguage(value) === "ar" ? "Arabic" : "English";
}

export function languageInstructionFor(value: unknown) {
  const language = normalizeTaiyoLanguage(value);
  if (language === "ar") {
    return "Selected language: ar. You must respond in Arabic. Keep JSON keys in English. Translate only user-facing string values.";
  }
  return "Selected language: en. You must respond in English. Keep JSON keys in English. Translate only user-facing string values.";
}
