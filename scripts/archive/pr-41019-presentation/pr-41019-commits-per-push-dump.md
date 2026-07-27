# GitHub API — Audit Trail #2: branch commits at each force-push

Companion to `pr-41019-github-api-dump.md`. This dump covers the requests made to reconstruct **the branch's own commit list (develop excluded) at every one of the 32 force-pushes** of PR RocketChat/Rocket.Chat#41019, plus the supporting diff-size / file-list calls. Repo: `RocketChat/Rocket.Chat`.

---

## 14. First attempt — per-tip `compare` loop (ABANDONED)

```
for sha in <32 tip SHAs>:
  gh api "repos/RocketChat/Rocket.Chat/compare/develop...$sha" --jq '{tip,ahead,commits:[...] }'
```

**Result:** timed out (>2 min, 0 of 32 completed). The `compare` endpoint embeds full file diffs/patches in every response, making 32 sequential calls far too heavy. Abandoned in favour of ancestry-walking (below).

---

## 15. develop commit-SHA set (membership oracle)

Fetched once so the ancestry walk knows where the branch rejoins develop.

**Request** (REST, list-commits — no diffs in the payload):
```
gh api "repos/RocketChat/Rocket.Chat/commits?sha=develop&since=2026-06-10T00:00:00Z&until=2026-07-08T00:00:00Z&per_page=100" \
   --paginate --jq '.[].sha'
```

**Raw data:** 192 SHAs. First 8:
```
39bfdf414eaeb15561dd25a87f3d67ff17b89010
38e80cb47919ca6aaedec6870f5702a1f94bb35c
31249c3bdb6a6a60c46eccdda80827af88bf055c
4fa7ab652e7f0864f8ce14de320b89532528ecaf
160e7f1c264e6a36bfe05f6fb6fb4fa7f2d77d71
8ed8599c7346b5cc082fa7e2e58d4214fc56c7f2
9ffcbd212e3993a150c75d6767f744b3fe8607e1
5740ec507b4e8af1b4770bb239ee19a4f0aa4a21
...
```

---

## 16. Per-tip ancestry (the parent walk)

For each of the 32 recovered tip SHAs, walked the commit ancestry via GraphQL `history` (commit metadata only — **no file diffs**), then trimmed the list at the first oid present in the develop set from §15.

**Request** (GraphQL, once per tip — 32 calls):
```graphql
query($oid:GitObjectID!){
  repository(owner:"RocketChat", name:"Rocket.Chat"){
    object(oid:$oid){ ... on Commit {
      history(first:30){ nodes { oid messageHeadline } }
    }}
  }
}
```
```
gh api graphql -f query='<above>' -F oid=<tip-sha> \
   --jq '.data.repository.object.history.nodes[] | [.oid, .messageHeadline] | @tsv'
```

**Trim rule:** keep nodes from the tip downward until the first oid ∈ develop-set; those kept are the branch's own commits. Boundary spot-checked (commits above the cut are all apps/runtime work; the first excluded commit is unrelated develop history, e.g. `React 19 (#40796)`, `feat(message-parser): add GFM table support`).

### Recovered data — branch commits per force-push (newest/tip first)

Counts: 6 6 6 6 7 7 8 8 8 10 11 10 11 16 22 16 16 16 18 18 15 15 15 14 14 15 17 18 7 7 3 4

#### Push 1/32 · 2026-06-21T18:04:14Z · tip `984de1d` · Phase A · 6 commits
```
984de1d  fix(apps): linting and typechecking
d1e6209  tests(apps): fix node-runtime tests
3b55b30  chore(ci): add dedicated CI step for node-runtime tests
a0d5540  feat(apps): adapt apps package to accept node-runtime
55f02ec  feat(apps): duplicate deno-runtime as node-runtime
c51fd27  fix(deno): lint problem
```

#### Push 2/32 · 2026-06-21T21:18:24Z · tip `0fd3c3c` · Phase A · 6 commits
```
0fd3c3c  fix(apps): linting and typechecking
e9b74ae  tests(apps): fix node-runtime tests
b410886  chore(ci): add dedicated CI step for node-runtime tests
25830f0  feat(apps): adapt apps package to accept node-runtime
ae3adbd  feat(apps): duplicate deno-runtime as node-runtime
c51fd27  fix(deno): lint problem
```

#### Push 3/32 · 2026-06-23T14:34:40Z · tip `17c8548` · Phase A · 6 commits
```
17c8548  fix(apps): linting and typechecking
865b8d8  tests(apps): fix node-runtime tests
5384571  chore(ci): add dedicated CI step for node-runtime tests
6dc0ec9  feat(apps): adapt apps package to accept node-runtime
d79c23f  feat(apps): duplicate deno-runtime as node-runtime
9441c1f  fix(deno): lint problem
```

#### Push 4/32 · 2026-06-23T22:35:56Z · tip `ba2d17d` · Phase A · 6 commits
```
ba2d17d  fix(apps): linting and typechecking
c3af1bf  tests(apps): fix node-runtime tests
29d59c3  chore(ci): add dedicated CI step for node-runtime tests
1117e50  feat(apps): adapt apps package to accept node-runtime
530d138  feat(apps): duplicate deno-runtime as node-runtime
9d26e95  fix(deno): lint problem
```

#### Push 5/32 · 2026-06-24T15:29:03Z · tip `3d7f648` · Phase A · 7 commits
```
3d7f648  chore(ci): include new dir to turbo build outputs
535712c  fix(apps): linting and typechecking
504238e  tests(apps): fix node-runtime tests
cc6416e  chore(ci): add dedicated CI step for node-runtime tests
99756ec  feat(apps): adapt apps package to accept node-runtime
c338cf6  feat(apps): duplicate deno-runtime as node-runtime
4f0eadf  fix(deno): lint problem
```

#### Push 6/32 · 2026-06-25T13:21:33Z · tip `2f0986d` · Phase A · 7 commits
```
2f0986d  chore(ci): include new dir to turbo build outputs
859c854  fix(apps): linting and typechecking
fd77eb8  tests(apps): fix node-runtime tests
20f4d86  chore(ci): add dedicated CI step for node-runtime tests
369425f  feat(apps): adapt apps package to accept node-runtime
5a90a15  feat(apps): duplicate deno-runtime as node-runtime
9e6216d  fix(deno): lint problem
```

#### Push 7/32 · 2026-06-25T17:47:53Z · tip `9d0d1fa` · Phase A · 8 commits
```
9d0d1fa  chore(ci): include new dir to turbo build outputs
027ff06  fix(apps): linting and typechecking
4699e17  tests(apps): fix node-runtime tests
2261c17  chore(ci): add dedicated CI step for node-runtime tests
44eb598  feat(apps): adapt apps package to accept node-runtime
622db80  feat(apps): duplicate deno-runtime as node-runtime
3fb1259  fix(deno): lint problem
7a3a83c  chore(apps): unit test improvements (#40785)
```

#### Push 8/32 · 2026-06-25T17:47:56Z · tip `20a6c76` · Phase A · 8 commits
```
20a6c76  chore(ci): include new dir to turbo build outputs
2614dfe  fix(apps): linting and typechecking
7576e1e  tests(apps): fix node-runtime tests
bbba144  chore(ci): add dedicated CI step for node-runtime tests
ed718bc  feat(apps): adapt apps package to accept node-runtime
e94feb7  feat(apps): duplicate deno-runtime as node-runtime
da7f278  fix(deno): lint problem
b6ad4b9  chore(apps): unit test improvements (#40785)
```

#### Push 9/32 · 2026-06-25T17:48:27Z · tip `0bd8c2f` · Phase A · 8 commits
```
0bd8c2f  chore(ci): include new dir to turbo build outputs
027ff06  fix(apps): linting and typechecking
4699e17  tests(apps): fix node-runtime tests
2261c17  chore(ci): add dedicated CI step for node-runtime tests
44eb598  feat(apps): adapt apps package to accept node-runtime
622db80  feat(apps): duplicate deno-runtime as node-runtime
3fb1259  fix(deno): lint problem
7a3a83c  chore(apps): unit test improvements (#40785)
```

#### Push 10/32 · 2026-06-26T20:48:27Z · tip `1a87551` · Phase B · 10 commits
```
1a87551  refactor(apps): use direct ESM imports in node-runtime
574963f  docs(apps): add shared base runtime proposal
c794de4  chore(ci): include new dir to turbo build outputs
4541989  fix(apps): linting and typechecking
04833b5  tests(apps): fix node-runtime tests
aef8faa  chore(ci): add dedicated CI step for node-runtime tests
c0e4d01  feat(apps): adapt apps package to accept node-runtime
cc58d26  feat(apps): duplicate deno-runtime as node-runtime
a20cdc5  refactor(apps): drop .ts extensions and use direct ESM imports in den…
3d17dd5  fix(deno): lint problem
```

#### Push 11/32 · 2026-06-29T13:54:59Z · tip `d990c3e` · Phase B · 11 commits
```
d990c3e  refactor(apps): use direct ESM imports in node-runtime
3880d05  docs(apps): add shared base runtime proposal
10eb200  chore(ci): include new dir to turbo build outputs
f98fdbc  fix(apps): linting and typechecking
edee91f  tests(apps): fix node-runtime tests
c26dc81  chore(ci): add dedicated CI step for node-runtime tests
41c17d4  feat(apps): adapt apps package to accept node-runtime
4eef4b2  feat(apps): duplicate deno-runtime as node-runtime
668b9a5  refactor(apps): drop Deno specific APIs in deno-runtime
f8fcd00  refactor(apps): drop .ts extensions
b969e1a  fix(deno): lint problem
```

#### Push 12/32 · 2026-06-29T20:01:09Z · tip `d0f3809` · Phase B · 10 commits
```
d0f3809  refactor(apps): use direct ESM imports in node-runtime
981f479  docs(apps): add shared base runtime proposal
8eafad0  chore(ci): include new dir to turbo build outputs
3c036f2  fix(apps): linting and typechecking
f3672c0  tests(apps): fix node-runtime tests
624e73b  chore(ci): add dedicated CI step for node-runtime tests
2c7550c  feat(apps): adapt apps package to accept node-runtime
8037b6f  feat(apps): duplicate deno-runtime as node-runtime
6a4ec10  refactor(apps): drop Deno specific APIs in deno-runtime
9e16c96  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 13/32 · 2026-06-29T20:45:07Z · tip `bf97139` · Phase B · 11 commits
```
bf97139  refactor(apps): converge deno-runtime toward node-runtime
4025415  refactor(apps): use direct ESM imports in node-runtime
981f479  docs(apps): add shared base runtime proposal
8eafad0  chore(ci): include new dir to turbo build outputs
3c036f2  fix(apps): linting and typechecking
f3672c0  tests(apps): fix node-runtime tests
624e73b  chore(ci): add dedicated CI step for node-runtime tests
2c7550c  feat(apps): adapt apps package to accept node-runtime
8037b6f  feat(apps): duplicate deno-runtime as node-runtime
6a4ec10  refactor(apps): drop Deno specific APIs in deno-runtime
9e16c96  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 14/32 · 2026-06-30T13:12:19Z · tip `a072bb0` · Phase B · 16 commits
```
a072bb0  docs(apps): rewrite shared-base-runtime proposal for the converged seam
965e910  refactor(apps): converge deno-runtime AST onto real acorn types
b73144c  fix(apps): resolve dangling acorn type imports in node-runtime
71ff9ef  refactor(apps): converge error-handlers notification shape in deno-ru…
4d827ec  refactor(apps): remove unnecessary declaration files
9937c8c  refactor(apps): converge deno-runtime toward node-runtime
8dda908  refactor(apps): use direct ESM imports in node-runtime
bc2b2ea  docs(apps): add shared base runtime proposal
d5b66e4  chore(ci): include new dir to turbo build outputs
1e25c5e  fix(apps): linting and typechecking
81832b6  tests(apps): fix node-runtime tests
9220848  chore(ci): add dedicated CI step for node-runtime tests
26229a4  feat(apps): adapt apps package to accept node-runtime
215e316  feat(apps): duplicate deno-runtime as node-runtime
15031fa  refactor(apps): drop Deno specific APIs in deno-runtime
ca22b31  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 15/32 · 2026-06-30T23:40:53Z · tip `3562fd7` · Phase B · 22 commits
```
3562fd7  test(apps): run apps test files serially to avoid subprocess races
82631d5  build(apps): wire base-runtime into build, typecheck and test pipelines
d5a980a  refactor(apps): reduce deno-runtime to a thin base adapter
46f7baa  refactor(apps): reduce node-runtime to a thin base adapter
1de3c82  refactor(apps): extract shared base-runtime from node/deno trees
a6fe39c  docs(apps): correct base-runtime consumption model in proposal
4f859d3  docs(apps): rewrite shared-base-runtime proposal for the converged seam
8ccc40e  fix(apps): resolve dangling acorn type imports in node-runtime
de52240  refactor(apps): remove unnecessary declaration files
0717d86  refactor(apps): use direct ESM imports in node-runtime
4a9f98d  docs(apps): add shared base runtime proposal
e89e075  chore(ci): include new dir to turbo build outputs
0ceb646  fix(apps): linting and typechecking
6e15a52  tests(apps): fix node-runtime tests
d73be31  chore(ci): add dedicated CI step for node-runtime tests
13a9437  feat(apps): adapt apps package to accept node-runtime
1e7326f  feat(apps): duplicate deno-runtime as node-runtime
0396edd  refactor(apps): converge deno-runtime AST onto real acorn types
db31c21  refactor(apps): converge error-handlers notification shape in deno-ru…
60f1db7  refactor(apps): converge deno-runtime toward node-runtime
ace6546  refactor(apps): drop Deno specific APIs in deno-runtime
810b2c5  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 16/32 · 2026-07-01T15:56:58Z · tip `ab32863` · Phase B · 16 commits
```
ab32863  build(apps): wire base-runtime into build, typecheck and test pipelines
12b343f  refactor(apps): reduce deno-runtime to a thin base adapter
b07f5e7  refactor(apps): reduce node-runtime to a thin base adapter
58ee0af  refactor(apps): extract shared base-runtime from node/deno trees
738c1c3  docs(apps): correct base-runtime consumption model in proposal
a950aa0  docs(apps): rewrite shared-base-runtime proposal for the converged seam
6aa48d0  docs(apps): add shared base runtime proposal
f7dd714  chore(ci): add dedicated CI step for node-runtime tests
66a0a42  feat(apps): adapt apps package to accept node-runtime
f7d21b9  feat(apps): duplicate deno-runtime as node-runtime
d6422de  refactor(apps): converge deno-runtime AST onto real acorn types
291522a  refactor(apps): converge error-handlers notification shape in deno-ru…
e627fa7  refactor(apps): converge deno-runtime toward node-runtime
313195e  refactor(apps): drop Deno specific APIs in deno-runtime
47941f9  tests(apps): prevent node tests from running concurrently
3d7e37e  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 17/32 · 2026-07-01T19:52:18Z · tip `1239514` · Phase B · 16 commits
```
1239514  build(apps): wire base-runtime into build, typecheck and test pipelines
452d964  refactor(apps): reduce deno-runtime to a thin base adapter
15b7841  refactor(apps): reduce node-runtime to a thin base adapter
5fc20b0  refactor(apps): extract shared base-runtime from node/deno trees
eb90e4d  docs(apps): correct base-runtime consumption model in proposal
7ce571b  docs(apps): rewrite shared-base-runtime proposal for the converged seam
5e02761  docs(apps): add shared base runtime proposal
f4ae2f3  chore(ci): add dedicated CI step for node-runtime tests
1b01bf1  feat(apps): adapt apps package to accept node-runtime
839df80  feat(apps): duplicate deno-runtime as node-runtime
a63545c  refactor(apps): converge deno-runtime AST onto real acorn types
583f8a8  refactor(apps): converge error-handlers notification shape in deno-ru…
94736d6  refactor(apps): converge deno-runtime toward node-runtime
e0adc3f  refactor(apps): drop Deno specific APIs in deno-runtime
1db374a  tests(apps): prevent node tests from running concurrently
9dfb255  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 18/32 · 2026-07-01T21:05:03Z · tip `7d1e3b5` · Phase B · 16 commits
```
7d1e3b5  build(apps): wire base-runtime into build, typecheck and test pipelines
979b986  refactor(apps): reduce deno-runtime to a thin base adapter
15b7841  refactor(apps): reduce node-runtime to a thin base adapter
5fc20b0  refactor(apps): extract shared base-runtime from node/deno trees
eb90e4d  docs(apps): correct base-runtime consumption model in proposal
7ce571b  docs(apps): rewrite shared-base-runtime proposal for the converged seam
5e02761  docs(apps): add shared base runtime proposal
f4ae2f3  chore(ci): add dedicated CI step for node-runtime tests
1b01bf1  feat(apps): adapt apps package to accept node-runtime
839df80  feat(apps): duplicate deno-runtime as node-runtime
a63545c  refactor(apps): converge deno-runtime AST onto real acorn types
583f8a8  refactor(apps): converge error-handlers notification shape in deno-ru…
94736d6  refactor(apps): converge deno-runtime toward node-runtime
e0adc3f  refactor(apps): drop Deno specific APIs in deno-runtime
1db374a  tests(apps): prevent node tests from running concurrently
9dfb255  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 19/32 · 2026-07-02T00:34:01Z · tip `bd5ebb3` · Phase C · 18 commits
```
bd5ebb3  refactor(base-runtime): better directory structure
7e9a245  refactor(base-runtime): messageLoop to mainLoop
7d1e3b5  build(apps): wire base-runtime into build, typecheck and test pipelines
979b986  refactor(apps): reduce deno-runtime to a thin base adapter
15b7841  refactor(apps): reduce node-runtime to a thin base adapter
5fc20b0  refactor(apps): extract shared base-runtime from node/deno trees
eb90e4d  docs(apps): correct base-runtime consumption model in proposal
7ce571b  docs(apps): rewrite shared-base-runtime proposal for the converged seam
5e02761  docs(apps): add shared base runtime proposal
f4ae2f3  chore(ci): add dedicated CI step for node-runtime tests
1b01bf1  feat(apps): adapt apps package to accept node-runtime
839df80  feat(apps): duplicate deno-runtime as node-runtime
a63545c  refactor(apps): converge deno-runtime AST onto real acorn types
583f8a8  refactor(apps): converge error-handlers notification shape in deno-ru…
94736d6  refactor(apps): converge deno-runtime toward node-runtime
e0adc3f  refactor(apps): drop Deno specific APIs in deno-runtime
1db374a  tests(apps): prevent node tests from running concurrently
9dfb255  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 20/32 · 2026-07-02T00:45:42Z · tip `b9a33ae` · Phase C · 18 commits
```
b9a33ae  refactor(base-runtime): better directory structure
7e9a245  refactor(base-runtime): messageLoop to mainLoop
7d1e3b5  build(apps): wire base-runtime into build, typecheck and test pipelines
979b986  refactor(apps): reduce deno-runtime to a thin base adapter
15b7841  refactor(apps): reduce node-runtime to a thin base adapter
5fc20b0  refactor(apps): extract shared base-runtime from node/deno trees
eb90e4d  docs(apps): correct base-runtime consumption model in proposal
7ce571b  docs(apps): rewrite shared-base-runtime proposal for the converged seam
5e02761  docs(apps): add shared base runtime proposal
f4ae2f3  chore(ci): add dedicated CI step for node-runtime tests
1b01bf1  feat(apps): adapt apps package to accept node-runtime
839df80  feat(apps): duplicate deno-runtime as node-runtime
a63545c  refactor(apps): converge deno-runtime AST onto real acorn types
583f8a8  refactor(apps): converge error-handlers notification shape in deno-ru…
94736d6  refactor(apps): converge deno-runtime toward node-runtime
e0adc3f  refactor(apps): drop Deno specific APIs in deno-runtime
1db374a  tests(apps): prevent node tests from running concurrently
9dfb255  refactor(apps): drop .ts extensions and use direct ESM imports in den…
```

#### Push 21/32 · 2026-07-02T19:20:03Z · tip `4e9be8b` · Phase C · 15 commits
```
4e9be8b  chore(ci): add dedicated CI step for node-runtime tests
86f118b  feat(apps): adapt apps package to accept node-runtime
febbcc4  feat(apps): Introduce node-runtime
48048d6  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
11bacfa  build(apps): wire base-runtime into build, typecheck and test pipelines
a47b8dd  refactor(base-runtime): extract shared base-runtime from node/deno trees
680ebc3  docs(apps): add shared base runtime proposal
a5d24cb  refactor(deno-runtime): extract main handler loop from main.ts
38d07be  refactor(deno-runtime): extract sandbox config from construct.ts
7e1b19b  refactor(deno-runtime): move prepareEnvironment to main.ts
59a8844  fix(deno-runtime): better location for subprocess validation
a30ead6  refactor(apps): converge deno-runtime AST onto real acorn types
c3cf0e5  refactor(apps): converge error-handlers notification shape in deno-ru…
249e20e  refactor(apps): converge deno-runtime toward node-runtime
11eab33  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 22/32 · 2026-07-02T20:01:03Z · tip `4e300d7` · Phase C · 15 commits
```
4e300d7  chore(ci): add dedicated CI step for node-runtime tests
1accd85  feat(apps): adapt apps package to accept node-runtime
6ef7e27  feat(apps): Introduce node-runtime
efa09e3  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
1720aaf  build(apps): wire base-runtime into build, typecheck and test pipelines
faa3dd4  refactor(base-runtime): extract shared base-runtime from node/deno trees
af765ab  docs(apps): add shared base runtime proposal
8427fb6  refactor(deno-runtime): extract main handler loop from main.ts
98d0058  refactor(deno-runtime): extract sandbox config from construct.ts
7eab696  refactor(deno-runtime): move prepareEnvironment to main.ts
9b73459  fix(deno-runtime): better location for subprocess validation
ffee3e7  refactor(apps): converge deno-runtime AST onto real acorn types
2c77626  refactor(apps): converge error-handlers notification shape in deno-ru…
8942294  refactor(apps): converge deno-runtime toward node-runtime
58c9f3e  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 23/32 · 2026-07-02T20:23:21Z · tip `a759717` · Phase C · 15 commits
```
a759717  chore(ci): add dedicated CI step for node-runtime tests
53ff57c  feat(apps): adapt apps package to accept node-runtime
067be64  feat(apps): introduce node-runtime
efa09e3  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
1720aaf  build(apps): wire base-runtime into build, typecheck and test pipelines
faa3dd4  refactor(base-runtime): extract shared base-runtime from node/deno trees
af765ab  docs(apps): add shared base runtime proposal
8427fb6  refactor(deno-runtime): extract main handler loop from main.ts
98d0058  refactor(deno-runtime): extract sandbox config from construct.ts
7eab696  refactor(deno-runtime): move prepareEnvironment to main.ts
9b73459  fix(deno-runtime): better location for subprocess validation
ffee3e7  refactor(apps): converge deno-runtime AST onto real acorn types
2c77626  refactor(apps): converge error-handlers notification shape in deno-ru…
8942294  refactor(apps): converge deno-runtime toward node-runtime
58c9f3e  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 24/32 · 2026-07-02T20:30:26Z · tip `c56a77d` · Phase C · 14 commits
```
c56a77d  chore(ci): add dedicated CI step for node-runtime tests
afbddba  feat(apps): adapt apps package to accept node-runtime
9d7b555  feat(apps): introduce node-runtime
38ba2d1  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
36b259c  build(apps): wire base-runtime into build, typecheck and test pipelines
cf09ac5  refactor(base-runtime): extract shared base-runtime from node/deno trees
8427fb6  refactor(deno-runtime): extract main handler loop from main.ts
98d0058  refactor(deno-runtime): extract sandbox config from construct.ts
7eab696  refactor(deno-runtime): move prepareEnvironment to main.ts
9b73459  fix(deno-runtime): better location for subprocess validation
ffee3e7  refactor(apps): converge deno-runtime AST onto real acorn types
2c77626  refactor(apps): converge error-handlers notification shape in deno-ru…
8942294  refactor(apps): converge deno-runtime toward node-runtime
58c9f3e  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 25/32 · 2026-07-02T21:27:56Z · tip `981a104` · Phase C · 14 commits
```
981a104  chore(ci): add dedicated CI step for node-runtime tests
cb72c70  feat(apps): adapt apps package to accept node-runtime
428be89  feat(apps): introduce node-runtime
e7cf7b9  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
9d6ec50  build(apps): wire base-runtime into build, typecheck and test pipelines
cf09ac5  refactor(base-runtime): extract shared base-runtime from node/deno trees
8427fb6  refactor(deno-runtime): extract main handler loop from main.ts
98d0058  refactor(deno-runtime): extract sandbox config from construct.ts
7eab696  refactor(deno-runtime): move prepareEnvironment to main.ts
9b73459  fix(deno-runtime): better location for subprocess validation
ffee3e7  refactor(apps): converge deno-runtime AST onto real acorn types
2c77626  refactor(apps): converge error-handlers notification shape in deno-ru…
8942294  refactor(apps): converge deno-runtime toward node-runtime
58c9f3e  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 26/32 · 2026-07-02T22:10:45Z · tip `6a5300a` · Phase C · 15 commits
```
6a5300a  chore(ci): add dedicated CI step for node-runtime tests
185a428  feat(apps): adapt apps package to accept node-runtime
6dfb0a5  feat(apps): introduce node-runtime
526e62f  refactor(apps): extract DenoSubprocessController logic to BaseSubproc…
e7cf7b9  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
9d6ec50  build(apps): wire base-runtime into build, typecheck and test pipelines
cf09ac5  refactor(base-runtime): extract shared base-runtime from node/deno trees
8427fb6  refactor(deno-runtime): extract main handler loop from main.ts
98d0058  refactor(deno-runtime): extract sandbox config from construct.ts
7eab696  refactor(deno-runtime): move prepareEnvironment to main.ts
9b73459  fix(deno-runtime): better location for subprocess validation
ffee3e7  refactor(apps): converge deno-runtime AST onto real acorn types
2c77626  refactor(apps): converge error-handlers notification shape in deno-ru…
8942294  refactor(apps): converge deno-runtime toward node-runtime
58c9f3e  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 27/32 · 2026-07-03T15:03:38Z · tip `d4d9fb1` · Phase C · 17 commits
```
d4d9fb1  chore(ci): add dedicated CI step for node-runtime tests
c216960  feat(apps): adapt apps package to accept node-runtime
69b7fa4  feat(apps): introduce node-runtime
e1bd350  refactor(apps): extract DenoSubprocessController logic to BaseSubproc…
a52b620  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
ff35f45  build(apps): wire base-runtime into build, typecheck and test pipelines
9df026b  refactor(base-runtime): extract shared base-runtime from node/deno trees
23d65db  refactor(deno-runtime): add catch call to handler
297a78f  fix(apps): process.exit code argument is truncated past 255
6984383  refactor(deno-runtime): extract main handler loop from main.ts
05533e2  refactor(deno-runtime): extract sandbox config from construct.ts
b9bcb3b  refactor(deno-runtime): move prepareEnvironment to main.ts
d4ce601  fix(deno-runtime): better location for subprocess validation
3aa7001  refactor(apps): converge deno-runtime AST onto real acorn types
a175f32  refactor(apps): converge error-handlers notification shape in deno-ru…
96c73a3  refactor(apps): converge deno-runtime toward node-runtime
7bb8407  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 28/32 · 2026-07-03T15:44:11Z · tip `3838459` · Phase C · 18 commits
```
3838459  chore(ci): add dedicated CI step for node-runtime tests
bd4d4b1  feat(apps): adapt apps package to accept node-runtime
7bab7cc  feat(apps): introduce node-runtime
701ab40  refactor(apps): extract DenoSubprocessController logic to BaseSubproc…
36d995a  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
d50fca5  build(apps): wire base-runtime into build, typecheck and test pipelines
24e29cd  refactor(base-runtime): extract shared base-runtime from node/deno trees
a13b708  fix(deno-runtime): better validation of millisecond arg
50ce49f  refactor(deno-runtime): add catch call to handler
e790b09  fix(apps): process.exit code argument is truncated past 255
e9eec9c  refactor(deno-runtime): extract main handler loop from main.ts
0345228  refactor(deno-runtime): extract sandbox config from construct.ts
18d2112  refactor(deno-runtime): move prepareEnvironment to main.ts
a160cea  fix(deno-runtime): better location for subprocess validation
359fe57  refactor(apps): converge deno-runtime AST onto real acorn types
e805fa5  refactor(apps): converge error-handlers notification shape in deno-ru…
8af0aff  refactor(apps): converge deno-runtime toward node-runtime
c3a82ea  refactor(apps): drop Deno specific APIs in deno-runtime
```

#### Push 29/32 · 2026-07-03T18:06:18Z · tip `7e66856` · Phase C · 7 commits
```
7e66856  chore(ci): add dedicated CI step for node-runtime tests
bc1ee77  feat(apps): adapt apps package to accept node-runtime
6f43227  feat(apps): introduce node-runtime
d18dac5  refactor(apps): extract DenoSubprocessController logic to BaseSubproc…
2b81508  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
2a7d77b  build(apps): wire base-runtime into build, typecheck and test pipelines
987cbcd  refactor(base-runtime): extract shared base-runtime from node/deno trees
```

#### Push 30/32 · 2026-07-03T18:34:11Z · tip `10ea8c6` · Phase C · 7 commits
```
10ea8c6  chore(ci): add dedicated CI step for node-runtime tests
13283e2  feat(apps): adapt apps package to accept node-runtime
2de01f8  feat(apps): introduce node-runtime
dd8c041  refactor(apps): extract DenoSubprocessController logic to BaseSubproc…
cec408f  refactor(deno-runtime): reduce deno-runtime to a wrapper for base-run…
6bf2b91  build(apps): wire base-runtime into build, typecheck and test pipelines
c7c3894  refactor(base-runtime): extract shared base-runtime from node/deno trees
```

#### Push 31/32 · 2026-07-03T19:44:20Z · tip `de40f6a` · Phase C · 3 commits
```
de40f6a  chore(ci): add dedicated CI step for node-runtime tests
f607d77  feat(apps): adapt apps package to accept node-runtime
b8ad122  feat(apps): introduce node-runtime
```

#### Push 32/32 · 2026-07-06T14:39:16Z · tip `810ebbf` · Phase D · 4 commits
```
810ebbf  add changeset
6fd6196  chore(ci): add dedicated CI step for node-runtime tests
aaba745  feat(apps): adapt apps package to accept node-runtime
00168e4  feat(apps): introduce node-runtime
```

> Full 40-char SHAs for all 370 commits are embedded in the artifact's `STACKS` array (`pr-41019-timeline.src.html`); short SHAs shown here for readability. Each links to `github.com/RocketChat/Rocket.Chat/commit/<full-sha>` in the artifact (ephemeral — unreachable objects GitHub still serves).

---

## 17. Supporting `compare` calls (diff sizes + peak file list)

### 17a. Cumulative diff vs fork point at 5 key tips (branch-size section)

**Request** (REST):
```
gh api "repos/RocketChat/Rocket.Chat/compare/develop...$sha" \
   --jq '{tip, commits:.total_commits, files:(.files|length), add:([.files[].additions]|add), del:([.files[].deletions]|add)}'
```

**Raw data:**
```
tip         commits  files   +add    -del
1a87551c2       10    161   10467    448
7d1e3b5b0       16    117    4437   3860
4e9be8bab       15    111    4117   3410
de40f6a4b        3     17     248     82
810ebbfb9        4     18     255     84
```

### 17b. Peak-monolith file list (tip `7d1e3b5b`, for the file-tree card)

**Request** (REST):
```
gh api "repos/RocketChat/Rocket.Chat/compare/develop...7d1e3b5b0cb9597a89534c12287dad0f37434b03" \
   --jq '.files[] | [.filename, .status, .additions, .deletions] | @tsv'
```

**Raw data:** 117 files (`path  status  +add  -del`):
```
.github/workflows/ci-test-e2e.yml	modified	+21	-3
.github/workflows/ci.yml	modified	+21	-0
apps/meteor/.mocharc.api.apps.js	added	+15	-0
apps/meteor/package.json	modified	+1	-0
docker-compose-ci.yml	modified	+1	-0
docs/proposals/shared-base-runtime.md	added	+273	-0
packages/apps/base-runtime/AppObjectRegistry.ts	renamed	+2	-2
packages/apps/base-runtime/handlers/api-handler.ts	renamed	+8	-7
packages/apps/base-runtime/handlers/app/construct.ts	added	+175	-0
packages/apps/base-runtime/handlers/app/handleGetStatus.ts	renamed	+3	-2
packages/apps/base-runtime/handlers/app/handleInitialize.ts	renamed	+5	-5
packages/apps/base-runtime/handlers/app/handleOnDisable.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/app/handleOnEnable.ts	renamed	+5	-5
packages/apps/base-runtime/handlers/app/handleOnInstall.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/app/handleOnPreSettingUpdate.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/app/handleOnSettingUpdated.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/app/handleOnUninstall.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/app/handleOnUpdate.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/app/handleSetStatus.ts	added	+28	-0
packages/apps/base-runtime/handlers/app/handleUploadEvents.ts	renamed	+17	-14
packages/apps/base-runtime/handlers/app/handler.ts	renamed	+18	-17
packages/apps/base-runtime/handlers/lib/assertions.ts	renamed	+3	-3
packages/apps/base-runtime/handlers/listener/handler.ts	renamed	+20	-20
packages/apps/base-runtime/handlers/outboundcomms-handler.ts	renamed	+7	-6
packages/apps/base-runtime/handlers/scheduler-handler.ts	renamed	+7	-6
packages/apps/base-runtime/handlers/slashcommand-handler.ts	renamed	+14	-12
packages/apps/base-runtime/handlers/tests/api-handler.test.ts	added	+176	-0
packages/apps/base-runtime/handlers/tests/helpers/mod.ts	renamed	+4	-4
packages/apps/base-runtime/handlers/tests/listener-handler.test.ts	renamed	+73	-82
packages/apps/base-runtime/handlers/tests/scheduler-handler.test.ts	renamed	+10	-10
packages/apps/base-runtime/handlers/tests/slashcommand-handler.test.ts	added	+162	-0
packages/apps/base-runtime/handlers/tests/uikit-handler.test.ts	added	+105	-0
packages/apps/base-runtime/handlers/tests/upload-event-handler.test.ts	added	+123	-0
packages/apps/base-runtime/handlers/tests/videoconference-handler.test.ts	renamed	+43	-53
packages/apps/base-runtime/handlers/uikit/handler.ts	renamed	+29	-16
packages/apps/base-runtime/handlers/videoconference-handler.ts	renamed	+7	-6
packages/apps/base-runtime/lib/accessors/builders/BlockBuilder.ts	added	+16	-0
packages/apps/base-runtime/lib/accessors/builders/DiscussionBuilder.ts	added	+48	-0
packages/apps/base-runtime/lib/accessors/builders/LivechatMessageBuilder.ts	renamed	+7	-15
packages/apps/base-runtime/lib/accessors/builders/MessageBuilder.ts	renamed	+7	-11
packages/apps/base-runtime/lib/accessors/builders/RoomBuilder.ts	renamed	+4	-10
packages/apps/base-runtime/lib/accessors/builders/UserBuilder.ts	renamed	+3	-9
packages/apps/base-runtime/lib/accessors/builders/VideoConferenceBuilder.ts	renamed	+2	-9
packages/apps/base-runtime/lib/accessors/extenders/HttpExtender.ts	renamed	+0	-0
packages/apps/base-runtime/lib/accessors/extenders/MessageExtender.ts	renamed	+2	-8
packages/apps/base-runtime/lib/accessors/extenders/RoomExtender.ts	renamed	+2	-8
packages/apps/base-runtime/lib/accessors/extenders/VideoConferenceExtend.ts	renamed	+2	-8
packages/apps/base-runtime/lib/accessors/formatResponseErrorHandler.ts	renamed	+0	-0
packages/apps/base-runtime/lib/accessors/http.ts	renamed	+6	-3
packages/apps/base-runtime/lib/accessors/mod.ts	renamed	+126	-92
packages/apps/base-runtime/lib/accessors/modify/ModifyCreator.ts	renamed	+38	-41
packages/apps/base-runtime/lib/accessors/modify/ModifyExtender.ts	renamed	+10	-15
packages/apps/base-runtime/lib/accessors/modify/ModifyUpdater.ts	renamed	+19	-24
packages/apps/base-runtime/lib/accessors/notifier.ts	renamed	+8	-12
packages/apps/base-runtime/lib/accessors/tests/AppAccessors.test.ts	renamed	+27	-15
packages/apps/base-runtime/lib/accessors/tests/ModifyCreator.test.ts	renamed	+74	-57
packages/apps/base-runtime/lib/accessors/tests/ModifyExtender.test.ts	added	+235	-0
packages/apps/base-runtime/lib/accessors/tests/ModifyUpdater.test.ts	added	+238	-0
packages/apps/base-runtime/lib/accessors/tests/formatResponseErrorHandler.test.ts	renamed	+51	-51
packages/apps/base-runtime/lib/accessors/tests/http.test.ts	renamed	+38	-46
packages/apps/base-runtime/lib/ast/mod.ts	renamed	+8	-9
packages/apps/base-runtime/lib/ast/operations.ts	renamed	+12	-12
packages/apps/base-runtime/lib/ast/tests/data/ast_blocks.ts	renamed	+82	-2
packages/apps/base-runtime/lib/ast/tests/operations.test.ts	renamed	+43	-42
packages/apps/base-runtime/lib/codec.ts	renamed	+2	-7
packages/apps/base-runtime/lib/logger.ts	renamed	+29	-7
packages/apps/base-runtime/lib/messenger.ts	renamed	+50	-46
packages/apps/base-runtime/lib/metricsCollector.ts	renamed	+5	-4
packages/apps/base-runtime/lib/parseArgs.ts	added	+25	-0
packages/apps/base-runtime/lib/requestContext.ts	renamed	+3	-3
packages/apps/base-runtime/lib/room.ts	renamed	+5	-5
packages/apps/base-runtime/lib/roomFactory.ts	renamed	+3	-3
packages/apps/base-runtime/lib/sanitizeDeprecatedUsage.ts	renamed	+1	-1
packages/apps/base-runtime/lib/secureFields.ts	renamed	+3	-2
packages/apps/base-runtime/lib/tests/logger.test.ts	added	+111	-0
packages/apps/base-runtime/lib/tests/messenger.test.ts	added	+79	-0
packages/apps/base-runtime/lib/tests/secureFields.test.ts	renamed	+9	-11
packages/apps/base-runtime/lib/wrapAppForRequest.ts	renamed	+4	-4
packages/apps/base-runtime/messageLoop.ts	added	+125	-0
packages/apps/base-runtime/tsconfig.json	added	+18	-0
packages/apps/deno-runtime/acorn-walk.d.ts	removed	+0	-175
packages/apps/deno-runtime/acorn.d.ts	removed	+0	-915
packages/apps/deno-runtime/deno.jsonc	modified	+7	-6
packages/apps/deno-runtime/deno.lock	modified	+11	-21
packages/apps/deno-runtime/error-handlers.ts	modified	+6	-11
packages/apps/deno-runtime/handlers/app/construct.ts	removed	+0	-132
packages/apps/deno-runtime/handlers/app/handleSetStatus.ts	removed	+0	-33
packages/apps/deno-runtime/handlers/tests/api-handler.test.ts	removed	+0	-118
packages/apps/deno-runtime/handlers/tests/slashcommand-handler.test.ts	removed	+0	-159
packages/apps/deno-runtime/handlers/tests/uikit-handler.test.ts	removed	+0	-105
packages/apps/deno-runtime/handlers/tests/upload-event-handler.test.ts	removed	+0	-107
packages/apps/deno-runtime/lib/accessors/builders/BlockBuilder.ts	removed	+0	-215
packages/apps/deno-runtime/lib/accessors/builders/DiscussionBuilder.ts	removed	+0	-59
packages/apps/deno-runtime/lib/accessors/tests/ModifyExtender.test.ts	removed	+0	-244
packages/apps/deno-runtime/lib/accessors/tests/ModifyUpdater.test.ts	removed	+0	-243
packages/apps/deno-runtime/lib/parseArgs.ts	removed	+0	-11
packages/apps/deno-runtime/lib/require.ts	modified	+1	-2
packages/apps/deno-runtime/lib/tests/logger.test.ts	removed	+0	-110
packages/apps/deno-runtime/lib/tests/messenger.test.ts	removed	+0	-99
packages/apps/deno-runtime/lib/transports/stdoutTransport.ts	added	+16	-0
packages/apps/deno-runtime/main.ts	modified	+41	-123
packages/apps/deno-runtime/tests/error-handlers.test.ts	added	+46	-0
packages/apps/node-runtime/src/error-handlers.ts	added	+10	-0
packages/apps/node-runtime/src/lib/loader-hook.ts	added	+19	-0
packages/apps/node-runtime/src/lib/transports/stdoutTransport.ts	added	+16	-0
packages/apps/node-runtime/src/main.ts	added	+30	-0
packages/apps/node-runtime/tsconfig.json	added	+18	-0
packages/apps/package.json	modified	+20	-6
packages/apps/src/server/managers/AppRuntimeManager.ts	modified	+9	-1
packages/apps/src/server/runtime/AppsEngineNodeRuntime.ts	removed	+0	-75
packages/apps/src/server/runtime/node/AppsEngineNodeRuntime.ts	added	+696	-0
packages/apps/src/server/runtime/node/LivenessManager.ts	added	+254	-0
packages/apps/src/server/runtime/node/ProcessMessenger.ts	added	+57	-0
packages/apps/src/server/runtime/node/bundler.ts	added	+90	-0
packages/apps/src/server/runtime/node/codec.ts	added	+78	-0
packages/apps/turbo.json	modified	+1	-1
yarn.lock	modified	+31	-0
```

---

## Endpoint summary (this dump)

| Purpose | Endpoint | Type | Calls |
|---|---|---|---|
| Abandoned commit-list attempt | `GET /compare/develop...{sha}` | REST | 0 completed (timed out) |
| develop membership set | `GET /commits?sha=develop&since&until` | REST (paginated) | 1 (multi-page) |
| per-tip ancestry | `POST /graphql` (Commit.history) | GraphQL | 32 |
| diff sizes | `GET /compare/develop...{sha}` | REST | 5 |
| peak file list | `GET /compare/develop...{sha}` | REST | 1 (+1 re-capture for this dump) |

*Caveats:* develop-set window was Jun 10 – Jul 8 (192 commits) — sufficient here (every fork point fell inside it, verified by clean trim boundaries). GraphQL `history(first:30)` was deep enough for every tip (max branch depth was 22). Commit subjects are `messageHeadline` (first line only).
