# Fuzzy Search Algorithm Resources

## Knowledge

- [fzy ALGORITHM.md — jhawthorn (GitHub)](https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md)
  Primary source for the fzy scoring model. Explains gap penalty, consecutive bonus, and the DP structure. Use for: lessons on scoring and ranking.

- [Approximate string matching — Wikipedia](https://en.wikipedia.org/wiki/Approximate_string_matching)
  Solid overview of the problem space and algorithm families (online vs offline, Levenshtein, Bitap). Use for: framing the problem and understanding algorithm categories.

- [Levenshtein distance — Wikipedia](https://en.wikipedia.org/wiki/Levenshtein_distance)
  Canonical definition, recurrence relation, and DP construction. Use for: edit distance lessons.

- [Levenshtein Distance Computation — Baeldung on Computer Science](https://www.baeldung.com/cs/levenshtein-distance-computation)
  Clear walkthrough of the DP table with worked examples. Use for: beginner-friendly edit distance exercises.

- [Fuzzy Search Algorithm for Approximate String Matching — Baeldung on CS](https://www.baeldung.com/cs/fuzzy-search-algorithm)
  Covers threshold-based matching and discusses algorithm trade-offs. Use for: bridging from distance to search.

- [What is fuzzy matching? — Redis Blog](https://redis.io/blog/what-is-fuzzy-matching/)
  Practical framing of when and why fuzzy matching is used. Use for: motivation and problem statement lessons.

- [fzy-lua algorithm docs — swarn (GitHub)](https://github.com/swarn/fzy-lua/blob/main/docs/fzy.md)
  Detailed prose explanation of fzy's scoring algorithm with mathematical notation. Use for: deep dive into the scoring model.

## Wisdom (Communities)

- [r/algorithms — Reddit](https://reddit.com/r/algorithms)
  General algorithm discussion with strong moderation. Use for: questions on DP formulations and algorithm correctness.

- [Computer Science Stack Exchange](https://cs.stackexchange.com)
  High-trust Q&A for algorithm theory. Use for: formal questions about edit distance variants and complexity.

## Gaps

- No peer-reviewed paper found that explains the full fzy scoring rationale end-to-end; the closest is the ALGORITHM.md source doc itself.
