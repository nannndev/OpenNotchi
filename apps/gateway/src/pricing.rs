//! Estimated request cost from token counts. Subscription accounts don't bill per token,
//! so this is "what it would cost on the API" — useful to compare usage, not an invoice.

/// USD per million tokens: (input, output, cached input). Most specific id first; matched by substring.
/// shortcut: a small hand-kept table; unknown models cost 0 until added here.
const PRICES: &[(&str, f64, f64, f64)] = &[
    ("claude-fable-5", 10.0, 50.0, 1.0),
    ("claude-opus-5-5", 4.0, 20.0, 0.2),
    ("claude-opus-5", 5.0, 25.0, 0.5),
    ("claude-opus-4", 5.0, 25.0, 0.5),
    ("claude-sonnet-5", 2.0, 10.0, 0.2),
    ("claude-sonnet-4", 3.0, 15.0, 0.3),
    ("claude-haiku-5-5", 0.1, 0.5, 0.01),
    ("claude-haiku-4", 1.0, 5.0, 0.1),
    ("gpt-5.5", 1.25, 10.0, 0.125),
    ("gpt-5-mini", 0.25, 2.0, 0.025),
    ("gpt-5", 1.25, 10.0, 0.125),
    ("gpt-4.1-mini", 0.4, 1.6, 0.1),
    ("gpt-4.1", 2.0, 8.0, 0.5),
    ("gpt-4o-mini", 0.15, 0.6, 0.075),
    ("gpt-4o", 2.5, 10.0, 1.25),
    ("gemini-2.5-pro", 1.25, 10.0, 0.31),
    ("gemini-2.5-flash", 0.3, 2.5, 0.075),
    ("deepseek", 0.28, 0.42, 0.028),
];

/// Estimated USD for one request. `input` includes `cached`.
pub fn cost(model: &str, input: i64, output: i64, cached: i64) -> f64 {
    let m = model.to_ascii_lowercase();
    let Some(&(_, inp, out, cache)) = PRICES.iter().find(|(id, ..)| m.contains(id)) else { return 0.0 };
    let fresh = (input - cached).max(0) as f64;
    (fresh * inp + cached.max(0) as f64 * cache + output.max(0) as f64 * out) / 1e6
}

#[cfg(test)]
mod tests {
    use super::cost;

    #[test]
    fn prices_known_models_per_million_tokens() {
        assert!((cost("claude-sonnet-5-5", 1_000_000, 0, 0) - 2.0).abs() < 1e-9);
    }

    #[test]
    fn cached_input_uses_the_cache_price() {
        assert!((cost("claude-sonnet-5-5", 1_000_000, 0, 1_000_000) - 0.2).abs() < 1e-9);
    }

    #[test]
    fn the_most_specific_id_wins() {
        assert!((cost("gpt-5-mini", 0, 1_000_000, 0) - 2.0).abs() < 1e-9);
    }

    #[test]
    fn unknown_models_cost_nothing() {
        assert_eq!(cost("some-new-model", 1000, 1000, 0), 0.0);
    }
}
