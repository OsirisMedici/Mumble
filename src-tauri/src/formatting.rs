//! Optional local formatting applied to completed transcripts, never to commands.

use once_cell::sync::Lazy;
use regex::Regex;
use std::panic::{catch_unwind, AssertUnwindSafe};
use text2num::digit_string::DigitString;
use text2num::error::Error;
use text2num::lang::{English, MorphologicalMarker};
use text2num::{replace_numbers_in_text, BasicAnnotate, LangInterpreter};

#[derive(Default)]
struct EnglishNumbers(English);

// Delegate English grammar to the parser, adding Indian scales and mixed ASR
// output such as "12 lakh fifty thousand" without changing other words.
impl LangInterpreter for EnglishNumbers {
    fn apply(&self, word: &str, digits: &mut DigitString) -> Result<(), Error> {
        match word {
            "lakh" | "lakhs" | "lac" | "lacs" if digits.is_range_free(5, 6) => digits.shift(5),
            "crore" | "crores" if digits.is_range_free(7, 8) => digits.shift(7),
            "thousand" if digits.len() > 5 && digits.is_range_free(3, 4) => digits.shift(3),
            word if !word.is_empty() && word.bytes().all(|b| b.is_ascii_digit()) => {
                digits.put(word.as_bytes())
            }
            _ => self.0.apply(word, digits),
        }
    }

    fn apply_decimal(&self, word: &str, digits: &mut DigitString) -> Result<(), Error> {
        self.0.apply_decimal(word, digits)
    }

    fn get_morph_marker(&self, word: &str) -> MorphologicalMarker {
        self.0.get_morph_marker(word)
    }

    fn check_decimal_separator(&self, word: &str) -> Option<char> {
        self.0.check_decimal_separator(word)
    }

    fn format_and_value(&self, digits: &DigitString) -> (String, f64) {
        self.0.format_and_value(digits)
    }

    fn is_linking(&self, word: &str) -> bool {
        self.0.is_linking(word)
    }

    fn basic_annotate<T: BasicAnnotate>(&self, tokens: &mut Vec<T>) {
        self.0.basic_annotate(tokens);
        let words: Vec<usize> = tokens
            .iter()
            .enumerate()
            .filter_map(|(i, token)| (!token.text_lowercase().trim().is_empty()).then_some(i))
            .collect();
        for (position, &i) in words.iter().enumerate() {
            if tokens[i].text_lowercase() == "second" && position > 0 {
                let previous = tokens[words[position - 1]].text_lowercase();
                if matches!(previous, "one" | "1" | "a" | "per" | "each" | "every") {
                    tokens[i].set_nan(true);
                }
            }
        }
    }
}

static ENGLISH: Lazy<EnglishNumbers> = Lazy::new(EnglishNumbers::default);
static ARTICLE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b(?:a|an)\s+(hundred|thousand|million|billion|lakh|crore)\b").unwrap()
});
static NEGATIVE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)\b(?:minus|negative)\s+(\d+(?:\.\d+)?)\b").unwrap());
static DECIMAL_SCALE: Lazy<Regex> = Lazy::new(|| {
    let word = "zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fourty|fifty|sixty|seventy|eighty|ninety|hundred|thousand";
    Regex::new(&format!(
        r"(?i)\b((?:{word}|point|\d+)(?:[\s-]+(?:{word}|and|point))*|\d+\.\d+)\s+(hundreds?|thousands?|millions?|billions?|lakhs?|lacs?|crores?)\b"
    )).unwrap()
});

/// Move the decimal point with strings so money/counts never acquire floating
/// point rounding errors. The input is a non-negative decimal from the parser.
fn shift_decimal(number: &str, power: usize) -> Option<String> {
    let (whole, fraction) = number.split_once('.').unwrap_or((number, ""));
    if whole.is_empty()
        || !whole
            .bytes()
            .chain(fraction.bytes())
            .all(|b| b.is_ascii_digit())
    {
        return None;
    }
    let mut digits = format!("{whole}{fraction}");
    let point = whole.len().checked_add(power)?;
    if point >= digits.len() {
        digits.extend(std::iter::repeat_n('0', point - digits.len()));
    } else {
        digits.insert(point, '.');
    }
    let (whole, fraction) = digits.split_once('.').unwrap_or((&digits, ""));
    let integer = whole.trim_start_matches('0');
    let integer = if integer.is_empty() { "0" } else { integer };
    let fraction = fraction.trim_end_matches('0');
    Some(if fraction.is_empty() {
        integer.to_string()
    } else {
        format!("{integer}.{fraction}")
    })
}

/// Keep the original transcript if formatting is disabled or the parser fails.
pub fn format_spoken_numbers(text: &str, enabled: bool) -> String {
    if !enabled || text.is_empty() {
        return text.to_string();
    }
    catch_unwind(AssertUnwindSafe(|| {
        let prepared = ARTICLE.replace_all(text, "one $1");
        // The underlying parser handles decimals and integer scales separately.
        // Resolve fractional scaled amounts before it sees "point five million".
        let prepared = DECIMAL_SCALE.replace_all(&prepared, |capture: &regex::Captures<'_>| {
            let words = capture[1].to_ascii_lowercase();
            if !words.contains("point") && !words.contains('.') {
                return capture[0].to_string();
            }
            let parsed = if words.bytes().all(|b| b.is_ascii_digit() || b == b'.') {
                Some(words)
            } else {
                let words = if words.starts_with("point ") {
                    format!("zero {words}")
                } else {
                    words
                };
                Some(replace_numbers_in_text(&words, &*ENGLISH, 0.0))
            };
            let power = match capture[2].to_ascii_lowercase().trim_end_matches('s') {
                "hundred" => 2,
                "thousand" => 3,
                "lakh" | "lac" => 5,
                "million" => 6,
                "crore" => 7,
                "billion" => 9,
                _ => return capture[0].to_string(),
            };
            parsed
                .and_then(|number| shift_decimal(&number, power))
                .unwrap_or_else(|| capture[0].to_string())
        });
        let numbers = replace_numbers_in_text(&prepared, &*ENGLISH, 0.0);
        NEGATIVE
            .replace_all(&numbers, |capture: &regex::Captures<'_>| {
                let previous = numbers[..capture.get(0).unwrap().start()]
                    .chars()
                    .rev()
                    .find(|c| !c.is_whitespace());
                if previous.is_some_and(|c| c.is_ascii_digit() || c == ')') {
                    capture[0].to_string()
                } else {
                    format!("-{}", &capture[1])
                }
            })
            .into_owned()
    }))
    .unwrap_or_else(|_| text.to_string())
}

// Only join text around an explicit @/spoken-at marker and a dotted domain.
// Sentence punctuation stays outside the match. No domain is invented.
static EMAIL_AT: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)@|attherate|\bat[ \t]+the[ \t]+rate|\bat(?:[ \t]+sign)?\b").unwrap()
});
static EMAIL_LOCAL: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)([a-z0-9]+(?:[ \t]*(?:[._%+\-]|\b(?:dot|period|underscore|under[ \t]+score|hyphen|dash|plus)\b)[ \t]*[a-z0-9]+|[ \t]+(?:zero|oh|one|two|three|four|five|six|seven|eight|nine|[a-z0-9]))*)[ \t]*$").unwrap()
});
static EMAIL_DOMAIN: Lazy<Regex> = Lazy::new(|| {
    let label = r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?";
    // A sentence's period followed by a space isn't a domain separator.
    let dot = r"(?:[ \t]+\.[ \t]+|[ \t]*\.|[ \t]+(?:dot|period)[ \t]+)";
    Regex::new(&format!(
        r"(?i)^[ \t]*((?:g[ \t]+mail|{label})(?:{dot}{label})+)"
    ))
    .unwrap()
});
static EMAIL_SYMBOL: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b(?:dot|period|underscore|under[ \t]+score|hyphen|dash|plus)\b").unwrap()
});
static EMAIL_CUE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b(?:e-?mail(?:[ \t]+address)?[ \t]+is|e-?mail(?:[ \t]+address)?[ \t]*:)[ \t]+([a-z0-9]+(?:[ \t]+[a-z0-9]+){0,3})[ \t]*$").unwrap()
});
static WRITTEN_EMAIL: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)[a-z0-9][a-z0-9._%+\-]*@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+").unwrap()
});

fn email_prose_word(word: &str) -> bool {
    matches!(
        word.to_ascii_lowercase().as_str(),
        "a" | "an"
            | "the"
            | "i"
            | "we"
            | "you"
            | "they"
            | "it"
            | "is"
            | "are"
            | "my"
            | "your"
            | "our"
            | "email"
            | "mail"
            | "address"
            | "send"
            | "to"
            | "contact"
            | "reach"
            | "me"
            | "us"
            | "him"
            | "her"
            | "please"
            | "write"
            | "look"
            | "visit"
            | "available"
            | "meet"
            | "meeting"
            | "website"
            | "site"
            | "online"
            | "work"
            | "works"
            | "working"
            | "shop"
            | "read"
            | "more"
            | "details"
            | "see"
            | "find"
            | "learn"
            | "and"
            | "or"
            | "then"
            | "hello"
            | "hi"
    )
}

static EMAIL_DOMAIN_DOT: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)[ \t]+(?:dot|period)[ \t]+").unwrap());

fn compact_email_part(text: &str, local: bool) -> String {
    if !local {
        return EMAIL_DOMAIN_DOT
            .replace_all(text, ".")
            .split_whitespace()
            .collect::<String>()
            .to_ascii_lowercase();
    }
    let symbols = EMAIL_SYMBOL.replace_all(text, |c: &regex::Captures<'_>| {
        match c[0].to_ascii_lowercase().as_str() {
            "dot" | "period" => ".",
            "underscore" | "under score" => "_",
            "hyphen" | "dash" => "-",
            "plus" => "+",
            _ => "_",
        }
    });
    symbols
        .split_whitespace()
        .map(|word| {
            if local {
                match word.to_ascii_lowercase().as_str() {
                    "zero" | "oh" => "0".to_string(),
                    "one" => "1".to_string(),
                    "two" => "2".to_string(),
                    "three" => "3".to_string(),
                    "four" => "4".to_string(),
                    "five" => "5".to_string(),
                    "six" => "6".to_string(),
                    "seven" => "7".to_string(),
                    "eight" => "8".to_string(),
                    "nine" => "9".to_string(),
                    _ => word.to_ascii_lowercase(),
                }
            } else {
                word.to_ascii_lowercase()
            }
        })
        .collect()
}

fn format_email_addresses(text: &str) -> String {
    let mut output = String::with_capacity(text.len());
    let mut cursor = 0;
    let written: Vec<_> = WRITTEN_EMAIL.find_iter(text).collect();
    for at in EMAIL_AT.find_iter(text) {
        if written
            .iter()
            .any(|m| m.start() <= at.start() && at.end() <= m.end())
        {
            continue;
        }
        if at.start() < cursor {
            continue;
        }
        let before = &text[cursor..at.start()];
        let Some(local_capture) = EMAIL_LOCAL.captures(before) else {
            continue;
        };
        let local_match = local_capture.get(1).unwrap();
        let mut local_start = local_match.start();
        let mut raw_local = local_match.as_str();
        // Join full names only with an email cue or in a standalone spoken
        // address. Existing written addresses never absorb preceding prose.
        if let Some(cue) = EMAIL_CUE.captures(before) {
            let name = cue.get(1).unwrap();
            if name
                .as_str()
                .split_whitespace()
                .all(|w| !email_prose_word(w))
            {
                local_start = name.start();
                raw_local = name.as_str();
            }
        } else {
            let trimmed = before.trim();
            let parts: Vec<_> = trimmed.split_whitespace().collect();
            if (2..=3).contains(&parts.len())
                && parts
                    .iter()
                    .all(|w| w.bytes().all(|b| b.is_ascii_alphanumeric()) && !email_prose_word(w))
            {
                local_start = before.find(trimmed).unwrap();
                raw_local = trimmed;
            }
        }
        while let Some(space) = raw_local.find(char::is_whitespace) {
            let first = &raw_local[..space];
            if first.len() <= 1 || !email_prose_word(first) {
                break;
            }
            let tail = raw_local[space..].trim_start();
            local_start += raw_local.len() - tail.len();
            raw_local = tail;
        }
        if raw_local.len() > 1
            && email_prose_word(raw_local)
            && !matches!(raw_local.to_ascii_lowercase().as_str(), "hello" | "hi")
        {
            continue;
        }
        let start = cursor + local_start;
        // Never format an ASCII suffix of an unsupported international local part.
        if text[..start]
            .chars()
            .next_back()
            .is_some_and(|c| c.is_alphanumeric() || "._%+-@".contains(c))
        {
            continue;
        }
        let Some(domain_capture) = EMAIL_DOMAIN.captures(&text[at.end()..]) else {
            continue;
        };
        let domain_match = domain_capture.get(1).unwrap();
        let end = at.end() + domain_match.end();
        if text[end..]
            .chars()
            .next()
            .is_some_and(|c| c.is_alphanumeric() || c == '-')
        {
            continue;
        }
        let local = compact_email_part(raw_local, true);
        let domain = compact_email_part(domain_match.as_str(), false);
        if !valid_email_parts(&local, &domain) {
            continue;
        }
        output.push_str(&text[cursor..start]);
        output.push_str(&format!("{local}@{domain}"));
        cursor = end;
    }
    output.push_str(&text[cursor..]);
    output
}

fn valid_email_parts(local: &str, domain: &str) -> bool {
    !local.is_empty()
        && local.len() <= 64
        && !local.starts_with('.')
        && !local.ends_with('.')
        && !local.contains("..")
        && domain.len() <= 253
        && domain.split('.').all(|label| {
            !label.is_empty()
                && label.len() <= 63
                && !label.starts_with('-')
                && !label.ends_with('-')
                && label
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b == b'-')
        })
        && domain
            .rsplit('.')
            .next()
            .is_some_and(|tld| tld.len() >= 2 && tld.bytes().all(|b| b.is_ascii_alphabetic()))
}

/// Apply both preferences at the final-output boundary. Protect addresses from
/// number formatting: "first@one.com" must never become "1st@1.com".
pub fn format_transcript(text: &str, numbers: bool, emails: bool) -> String {
    let text = if emails {
        format_email_addresses(text)
    } else {
        text.to_string()
    };
    if !numbers {
        return text;
    }
    let mut result = String::with_capacity(text.len());
    let mut cursor = 0;
    for address in WRITTEN_EMAIL.find_iter(&text) {
        result.push_str(&format_spoken_numbers(&text[cursor..address.start()], true));
        result.push_str(address.as_str());
        cursor = address.end();
    }
    result.push_str(&format_spoken_numbers(&text[cursor..], true));
    result
}

#[cfg(test)]
mod tests {
    use super::{format_spoken_numbers, format_transcript};

    #[test]
    fn email_formatting_supports_at_the_rate_and_custom_domains() {
        for (spoken, expected) in [
            (
                "My email is pranshi at gmail dot com.",
                "My email is pranshi@gmail.com.",
            ),
            ("pranshi attherate gmail.com", "pranshi@gmail.com"),
            ("johnattherategmail.com", "john@gmail.com"),
            (
                "My email is john at the rategmail.com.",
                "My email is john@gmail.com.",
            ),
            ("Pranshi at the rate G Mail dot com", "pranshi@gmail.com"),
            ("pranshi @ gmail.com", "pranshi@gmail.com"),
            ("pranshi sharma @ gmail.com", "pranshisharma@gmail.com"),
            ("Hello john @ gmail.com", "Hello john@gmail.com"),
            ("john at plus dot studio", "john@plus.studio"),
            ("john at period dot com", "john@period.com"),
            (
                "Send to hello at example dot studio, please.",
                "Send to hello@example.studio, please.",
            ),
            (
                "sam at sign mail dot example dot co dot uk",
                "sam@mail.example.co.uk",
            ),
            (
                "john dot smith at outlook dot com",
                "john.smith@outlook.com",
            ),
            (
                "john underscore smith plus work at company-name dot io",
                "john_smith+work@company-name.io",
            ),
            ("john dash smith at yahoo dot com", "john-smith@yahoo.com"),
            (
                "My email is pranshi sharma at the rate gmail dot com.",
                "My email is pranshisharma@gmail.com.",
            ),
            (
                "pranshi sharma attherate gmail dot com",
                "pranshisharma@gmail.com",
            ),
            ("john one two three at gmail dot com", "john123@gmail.com"),
            ("j o h n at example dot com", "john@example.com"),
            (
                "Email me at john at gmail dot com. Thanks!",
                "Email me at john@gmail.com. Thanks!",
            ),
            (
                "a at gmail dot com and b at yahoo dot com",
                "a@gmail.com and b@yahoo.com",
            ),
        ] {
            assert_eq!(format_transcript(spoken, false, true), expected, "{spoken}");
        }
    }

    #[test]
    fn email_formatting_preserves_prose_punctuation_and_written_addresses() {
        for text in [
            "Meet me at the office.",
            "Look at example.com.",
            "We are available at example dot com.",
            "Ask Sam at work.",
            "The rate is five per hour.",
            "My email is john at gmail.",
            "My email is john at example dot 123.",
            "Hello John.Smith+Work@Example.COM. Thanks!",
            "first@one.com",
            "  No changes.\n",
            "",
        ] {
            assert_eq!(format_transcript(text, false, true), text, "{text}");
        }
    }

    #[test]
    fn email_and_number_preferences_work_independently_and_are_idempotent() {
        let spoken = "Send twenty five to first attherate one dot com.";
        assert_eq!(format_transcript(spoken, false, false), spoken);
        assert_eq!(
            format_transcript(spoken, false, true),
            "Send twenty five to first@one.com."
        );
        let both = format_transcript(spoken, true, true);
        assert_eq!(both, "Send 25 to first@one.com.");
        assert_eq!(format_transcript(&both, true, true), both);
        assert_eq!(
            format_transcript("first@one.com and twenty five", true, false),
            "first@one.com and 25"
        );
    }

    #[test]
    fn combines_number_phrases_instead_of_replacing_each_word() {
        for (spoken, expected) in [
            ("I need twenty five tickets.", "I need 25 tickets."),
            ("One hundred and three people.", "103 people."),
            (
                "The year is two thousand and twenty six.",
                "The year is 2026.",
            ),
            ("Two million three hundred thousand.", "2300000."),
            ("Twenty-five minutes.", "25 minutes."),
            ("one, two, three", "1, 2, 3"),
            ("three point one four", "3.14"),
            ("zero point zero five", "0.05"),
            ("The first of twenty items.", "The 1st of 20 items."),
            (
                "The budget is twelve lakh fifty thousand.",
                "The budget is 1250000.",
            ),
            (
                "one crore two lakh thirty thousand four hundred and five",
                "10230405",
            ),
            ("12 lakh fifty thousand", "1250000"),
            ("a hundred people", "100 people"),
            ("It is minus five degrees.", "It is -5 degrees."),
            ("negative three point five", "-3.5"),
            ("five minus two", "5 minus 2"),
            (
                "Wait one second, then bring twenty two items.",
                "Wait 1 second, then bring 22 items.",
            ),
            ("three point five million", "3500000"),
            ("one point two lakh", "120000"),
            ("The budget is 1.5 lakh.", "The budget is 150000."),
            ("and three point five million", "and 3500000"),
            ("point five million", "500000"),
            (
                "The second person will wait one second.",
                "The 2nd person will wait 1 second.",
            ),
        ] {
            assert_eq!(format_spoken_numbers(spoken, true), expected, "{spoken}");
        }
    }

    #[test]
    fn disabled_preserves_the_exact_original() {
        let original = "  Twenty five, one hundred.\n";
        assert_eq!(format_spoken_numbers(original, false), original);
    }

    #[test]
    fn preserves_other_text_existing_digits_and_whitespace() {
        for text in [
            "Call someone for a quote.",
            "Send it to John, not for review.",
            "Version 2.5 costs 125.50.",
            "Cost is 1,250.50, code 00123.",
            "Wait a second.",
            "नमस्ते दुनिया。こんにちは世界。",
            "  Hello!\nNext line.  ",
            "",
        ] {
            assert_eq!(format_spoken_numbers(text, true), text);
        }
    }

    #[test]
    fn applying_formatting_again_does_not_change_the_result() {
        let once = format_spoken_numbers("I need twenty five at three point five.", true);
        assert_eq!(format_spoken_numbers(&once, true), once);
    }
}
