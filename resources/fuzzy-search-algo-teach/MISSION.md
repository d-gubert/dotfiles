# Mission: Fuzzy Search Algorithm

## Why
To deeply understand how a fuzzy search algorithm is constructed — not just what it does, but why each design decision was made and what specific problem it solves. The goal is to be able to read a fuzzy search implementation and understand the intent behind every line.

## Success looks like
- Explain why exact string matching is insufficient and what properties a good fuzzy matcher needs
- Trace through a Levenshtein distance DP table by hand and explain each cell's meaning
- Describe the key design decisions in a scoring-based fuzzy search (gap penalty, consecutive bonus, boundary bonus) and articulate the problem each one solves
- Read the fzy/fzf scoring algorithm and follow it without confusion
- Implement a simple scored fuzzy search from scratch

## Constraints
- Learning proceeds through independent, increasingly complex lessons
- Each lesson should illuminate one design decision and the problem it solves

## Out of scope
- Full-text search engines (Elasticsearch, Lucene, inverted indexes)
- Phonetic matching (Soundex, Metaphone)
- Production performance tuning at scale
