# GitHub API — Request & Raw Data Dump

Investigation of **PR RocketChat/Rocket.Chat#41019** and its stack.
All requests issued via the `gh` CLI. `gh pr view` / `gh pr list` hit GitHub's **GraphQL** API; `gh api …` hits the **REST** API. Where a `--jq`/`python` filter was applied to the response, it is noted — those rows show the *filtered* data I actually consumed, not the full raw payload.

Repo: `RocketChat/Rocket.Chat` · Investigated: 2026-07-17

---

## 1. PR #41019 — metadata + body

**Request** (GraphQL, via `gh pr view`; output piped through `head -c 8000`, so the body is truncated):
```
gh pr view 41019 --repo RocketChat/Rocket.Chat \
  --json number,title,state,createdAt,closedAt,mergedAt,author,body,labels,milestone,url,comments
```

**Raw data** (truncated at 8000 bytes):
```json
{"author":{"id":"MDQ6VXNlcjE4MTAzMDk=","is_bot":false,"login":"d-gubert","name":"Douglas Gubert"},"body":"...
This PR adds a **Node.js runtime backend** for the Apps-Engine subprocess, as an alternative to the existing Deno runtime. It builds directly on the shared `base-runtime`: both runtimes are now thin, platform-specific wrappers around the same core (main loop, messenger, handlers), and this PR simply adds the Node-flavored wrapper plus the wiring to select it.

The Node runtime is **opt-in and off by default** — nothing changes in production unless APPS_ENGINE_RUNTIME_BACKEND=node is set, so the blast radius is limited to that flag.

### What's in this PR
- packages/apps/node-runtime/ — new package, the Node counterpart to deno-runtime/. It's deliberately tiny:
  - src/main.ts — boots the shared main loop, wiring the base runtime's setTransport / setSandboxRequire / setSandboxGlobals / startMainLoop.
  - src/lib/loader-hook.ts — remaps @rocket.chat/apps/* bare specifiers to the local package dir via node:module registerHooks (the Node analog of Deno's import map).
  - src/lib/require.ts — the sandbox require handed to apps: an allow-list of Node built-ins and external packages (uuid, @rocket.chat/apps-engine), normalizing node:-prefixed specifiers.
  - src/lib/transports/stdoutTransport.ts — writes messenger frames to process.stdout.
  - src/error-handlers.ts — forwards uncaughtException to the host as a notification.
  - tsconfig.json — its own build target (node-runtime/dist).
- packages/apps/src/server/runtime/node/AppsEngineNodeRuntime.ts — the concrete NodeRuntimeSubprocessController, extending BaseRuntimeSubprocessController. It spawns node with --permission + --allow-fs-read=<dir> sandbox flags (the old placeholder src/server/runtime/AppsEngineNodeRuntime.ts is deleted).
- AppRuntimeManager.ts — runtime selection via the APPS_ENGINE_RUNTIME_BACKEND env var (defaults to deno); exports nodeRuntimeFactory / denoRuntimeFactory.
- Build/CI — node-runtime added to the build (build:node-runtime, typecheck:node-runtime), turbo outputs, the files array, and a dedicated (temporary) CI job (test-api-apps-node-ee) that runs the apps API E2E suite against the Node runtime. Includes a new apps/meteor/.mocharc.api.apps.js config and testapi:apps script, plus threading APPS_ENGINE_RUNTIME_BACKEND through docker-compose-ci.yml.

## Tips for the reviewer
1. This was authored as a stacked PR — the base-runtime work has since landed. Written on top of the shared base-runtime extraction (#41125, #41149), which has now merged into develop... This PR itself is small — 4 commits / 18 files...
2. Read it as a mirror of the Deno runtime. (suggested reading order: main.ts, loader-hook.ts, require.ts, AppsEngineNodeRuntime.ts, AppRuntimeManager.ts)
3. What's intentionally out of scope: the old placeholder server/runtime/AppsEngineNodeRuntime.ts is deleted and replaced by the real one under runtime/node/. The new CI job and E2E step are explicitly temporary — they exist only until the Deno runtime is removed.
4. No behavior change by default. defaultRuntimeFactory stays Deno unless the env var is node.

## Issue(s)
[ARCH-2189]

## Steps to test or reproduce
1. Build the apps package (yarn build in packages/apps) so node-runtime/dist is produced.
2. Start the server with APPS_ENGINE_RUNTIME_BACKEND=node.
3. Install and run an app — it should behave identically to the Deno runtime.
4. Locally, the apps E2E suite can be run against the Node runtime with APPS_ENGINE_RUNTIME_BACKEND=node yarn testapi:apps in apps/meteor.
Leaving the env var unset (or deno) keeps the existing Deno runtime path.
```
*(Body reproduced from the truncated response; markdown comment markers omitted. `author.login = d-gubert`, `is_bot = false`.)*

---

## 2. PR #41019 / #41125 / #41149 — dates, diff stats, commits

**Request** (GraphQL):
```
gh pr view 41019 --repo RocketChat/Rocket.Chat \
  --json number,title,state,createdAt,closedAt,mergedAt,baseRefName,headRefName,additions,deletions,changedFiles,commits
gh pr view 41125 --repo RocketChat/Rocket.Chat \
  --json number,title,state,createdAt,closedAt,mergedAt,baseRefName,headRefName,additions,deletions,changedFiles
gh pr view 41149 --repo RocketChat/Rocket.Chat \
  --json number,title,state,createdAt,closedAt,mergedAt,baseRefName,headRefName,additions,deletions,changedFiles
```

**Raw data — #41019** (commits array reproduced as headline / authoredDate / committedDate / oid):
```json
{
  "number": 41019,
  "title": "feat(apps): introduce alternative node-runtime",
  "state": "MERGED",
  "createdAt": "2026-06-19T18:54:26Z",
  "closedAt": "2026-07-06T17:37:36Z",
  "mergedAt": "2026-07-06T17:37:36Z",
  "baseRefName": "develop",
  "headRefName": "feat/apps-new-node-runtime",
  "additions": 255,
  "deletions": 84,
  "changedFiles": 18,
  "commits": [
    {"messageHeadline":"feat(apps): introduce node-runtime",
     "authoredDate":"2026-07-02T18:43:14Z","committedDate":"2026-07-06T14:39:03Z",
     "oid":"00168e42e477e1644e424e6bf0cfdfdf3640e178",
     "authors":["d-gubert","claude (Claude Opus 4.8)"],
     "messageBody":"refactor(apps): reduce node-runtime to a thin base adapter ... (squashed body also contains: chore(apps): include node-runtime in typecheck pipeline; chore(apps): clean node-runtime/dist in build:clean; fix(apps): print readable standalone-usage message in node-runtime) — Claude-Session: session_01LUT7EFw8g3GZjzD4huVpwD"},
    {"messageHeadline":"feat(apps): adapt apps package to accept node-runtime",
     "authoredDate":"2026-06-29T19:55:10Z","committedDate":"2026-07-06T14:39:05Z",
     "oid":"aaba74556816f17bff8caed81d810635619284e0",
     "messageBody":"refactor(apps): make NodeSubprocessController use the BaseSubprocessController"},
    {"messageHeadline":"chore(ci): add dedicated CI step for node-runtime tests",
     "authoredDate":"2026-06-19T19:22:29Z","committedDate":"2026-07-06T14:39:05Z",
     "oid":"6fd61962a52c1dd113cb8829e1900b5b89ee0366","messageBody":""},
    {"messageHeadline":"add changeset",
     "authoredDate":"2026-07-03T19:59:54Z","committedDate":"2026-07-06T14:39:05Z",
     "oid":"810ebbfb9be7aa5ffc6c31d140910b70cb8d517a",
     "messageBody":"docs(apps): fix typo in changeset (alernative -> alternative)"}
  ]
}
```

**Raw data — #41125**:
```json
{"number":41125,"title":"chore(apps): refactor deno-runtime to drop Deno specific APIs",
 "state":"MERGED","createdAt":"2026-06-30T22:47:09Z","closedAt":"2026-07-03T17:52:58Z",
 "mergedAt":"2026-07-03T17:52:58Z","baseRefName":"develop","headRefName":"chore/refactor-deno-apis",
 "additions":664,"deletions":1674,"changedFiles":24}
```

**Raw data — #41149**:
```json
{"number":41149,"title":"chore(apps): isolate platform independent logic from deno-runtime",
 "state":"MERGED","createdAt":"2026-07-02T19:19:40Z","closedAt":"2026-07-03T19:37:43Z",
 "mergedAt":"2026-07-03T19:37:43Z","baseRefName":"develop","headRefName":"chore/apps-base-runtime",
 "additions":2522,"deletions":2350,"changedFiles":101}
```

---

## 3. Author's related PRs + #41019 timeline events

**Request A** (GraphQL, `gh pr list`):
```
gh pr list --repo RocketChat/Rocket.Chat --author d-gubert --state all \
  --search "apps runtime in:title" --json number,title,state,createdAt,mergedAt --limit 30
```

**Raw data A**:
```json
[
 {"number":41201,"title":"chore(apps): remove the Deno runtime","state":"OPEN","createdAt":"2026-07-06T20:25:30Z","mergedAt":null},
 {"number":41376,"title":"chore(apps): consolidate accessor implementation to runtime (1/4)","state":"OPEN","createdAt":"2026-07-14T19:53:31Z","mergedAt":null},
 {"number":41378,"title":"chore(apps): consolidate accessor implementation to runtime (3/4)","state":"OPEN","createdAt":"2026-07-14T20:04:29Z","mergedAt":null},
 {"number":41377,"title":"chore(apps): consolidate accessor implementation to runtime (2/4)","state":"OPEN","createdAt":"2026-07-14T20:00:05Z","mergedAt":null},
 {"number":41171,"title":"chore(apps): consolidate accessor implementation to runtime (4/4)","state":"OPEN","createdAt":"2026-07-03T20:41:38Z","mergedAt":null},
 {"number":41103,"title":"chore(apps): refactor deno-runtime imports","state":"MERGED","createdAt":"2026-06-29T20:00:59Z","mergedAt":"2026-07-02T17:00:27Z"},
 {"number":41019,"title":"feat(apps): introduce alternative node-runtime","state":"MERGED","createdAt":"2026-06-19T18:54:26Z","mergedAt":"2026-07-06T17:37:36Z"},
 {"number":41149,"title":"chore(apps): isolate platform independent logic from deno-runtime","state":"MERGED","createdAt":"2026-07-02T19:19:40Z","mergedAt":"2026-07-03T19:37:43Z"},
 {"number":41125,"title":"chore(apps): refactor deno-runtime to drop Deno specific APIs","state":"MERGED","createdAt":"2026-06-30T22:47:09Z","mergedAt":"2026-07-03T17:52:58Z"},
 {"number":40005,"title":"Plan: Node runtime to replace Deno runtime for apps-engine subprocess","state":"CLOSED","createdAt":"2026-03-31T09:21:40Z","mergedAt":null},
 {"number":39701,"title":"refactor(apps): prepare deno-runtime for Deno upgrade","state":"MERGED","createdAt":"2026-03-17T23:45:51Z","mergedAt":"2026-03-20T04:16:11Z"},
 {"number":32677,"title":"chore: Log apps runtime data on SIGUSR2","state":"CLOSED","createdAt":"2024-06-25T23:23:57Z","mergedAt":null},
 {"number":36346,"title":"fix: properly throw error objects to apps on runtime","state":"MERGED","createdAt":"2025-07-02T18:59:06Z","mergedAt":"2025-07-04T12:21:44Z"},
 {"number":34205,"title":"fix(apps): runtime orchestration fixes","state":"MERGED","createdAt":"2024-12-17T20:18:06Z","mergedAt":"2024-12-19T21:21:34Z"},
 {"number":33929,"title":"fix: apps-engine runtime fixes","state":"MERGED","createdAt":"2024-11-10T22:49:55Z","mergedAt":"2024-11-11T11:56:04Z"},
 {"number":31821,"title":"feat: Apps-Engine Deno Runtime update","state":"MERGED","createdAt":"2024-02-23T14:39:14Z","mergedAt":"2024-06-17T22:17:08Z"}
]
```

**Request B** (REST, `/timeline`, filtered through a python script to selected event types):
```
gh api repos/RocketChat/Rocket.Chat/issues/41019/timeline --paginate
   | python (filter: cross-referenced, force-pushed, ready_for_review, review_requested, committed, merged, closed, labeled)
```

**Raw data B** (filtered — `date  event  actor  extra`):
```
2026-06-21T18:04:14Z head_ref_force_pushed d-gubert
2026-06-21T21:18:24Z head_ref_force_pushed d-gubert
2026-06-21T23:41:11Z labeled rc-layne[bot] needs-security-review
2026-06-22T16:18:02Z labeled coderabbitai[bot] type: feature
2026-06-23T14:34:40Z head_ref_force_pushed d-gubert
2026-06-23T22:35:56Z head_ref_force_pushed d-gubert
2026-06-24T15:29:03Z head_ref_force_pushed d-gubert
2026-06-25T13:21:33Z head_ref_force_pushed d-gubert
2026-06-25T17:47:53Z head_ref_force_pushed d-gubert
2026-06-25T17:47:56Z head_ref_force_pushed d-gubert
2026-06-25T17:48:27Z head_ref_force_pushed d-gubert
2026-06-26T20:48:27Z head_ref_force_pushed d-gubert
2026-06-29T13:54:59Z head_ref_force_pushed d-gubert
2026-06-29T20:01:09Z head_ref_force_pushed d-gubert
2026-06-29T20:45:07Z head_ref_force_pushed d-gubert
2026-06-29T20:55:35Z cross-referenced d-gubert #41103 chore(apps): refactor deno-runtime imports
2026-06-30T13:12:19Z head_ref_force_pushed d-gubert
2026-06-30T23:40:53Z head_ref_force_pushed d-gubert
2026-07-01T15:56:58Z head_ref_force_pushed d-gubert
2026-07-01T19:52:18Z head_ref_force_pushed d-gubert
2026-07-01T19:57:02Z cross-referenced d-gubert #41125 chore(apps): refactor deno-runtime to drop Deno specific APIs
2026-07-01T21:05:03Z head_ref_force_pushed d-gubert
2026-07-02T00:34:01Z head_ref_force_pushed d-gubert
2026-07-02T00:45:42Z head_ref_force_pushed d-gubert
2026-07-02T19:20:03Z head_ref_force_pushed d-gubert
2026-07-02T19:24:52Z cross-referenced d-gubert #41149 chore(apps): isolate platform independent logic from deno-runtime
2026-07-02T20:01:03Z head_ref_force_pushed d-gubert
2026-07-02T20:23:21Z head_ref_force_pushed d-gubert
2026-07-02T20:30:26Z head_ref_force_pushed d-gubert
2026-07-02T21:27:56Z head_ref_force_pushed d-gubert
2026-07-02T22:10:45Z head_ref_force_pushed d-gubert
2026-07-03T15:03:38Z head_ref_force_pushed d-gubert
2026-07-03T15:44:11Z head_ref_force_pushed d-gubert
2026-07-03T18:06:18Z head_ref_force_pushed d-gubert
2026-07-03T18:34:11Z head_ref_force_pushed d-gubert
2026-07-03T19:44:20Z head_ref_force_pushed d-gubert
2026-07-03T21:54:51Z ready_for_review d-gubert
2026-07-03T21:54:52Z review_requested d-gubert
2026-07-03T21:54:52Z review_requested d-gubert
2026-07-06T14:39:03Z committed Douglas Gubert
2026-07-06T14:39:05Z committed Douglas Gubert
2026-07-06T14:39:05Z committed Douglas Gubert
2026-07-06T14:39:05Z committed Douglas Gubert
2026-07-06T14:39:16Z head_ref_force_pushed d-gubert
2026-07-06T17:37:36Z merged ggazzo
2026-07-06T17:37:36Z closed ggazzo
2026-07-06T18:46:43Z cross-referenced tvnl-charan #6 feat(apps): introduce alternative node-runtime (PR 41019 replay)
```

---

## 4. PR #41103 — diff stats

**Request** (GraphQL):
```
gh pr view 41103 --repo RocketChat/Rocket.Chat --json additions,deletions,changedFiles,title
```

**Raw data**:
```json
{"title":"chore(apps): refactor deno-runtime imports","additions":309,"deletions":390,"changedFiles":68}
```

---

## 5. Force-push HEAD SHAs (from timeline `commit_id`)

**Request** (REST, `/timeline`, filtered to `head_ref_force_pushed` events; `before`/`after` were null, `commit_id` held the tip SHA at each push):
```
gh api repos/RocketChat/Rocket.Chat/issues/41019/timeline --paginate
   | python (filter: event == head_ref_force_pushed → print created_at, commit_id, before, after)
```

**Raw data** (`created_at  commit_id  before  after`):
```
2026-06-21T18:04:14Z  984de1d56a3bb0148a031f1324be96d988bd85cc  before=None after=None
2026-06-21T21:18:24Z  0fd3c3c7e4eec20059f08637b73edbf544d85cb5  before=None after=None
2026-06-23T14:34:40Z  17c854876577c364c37630e54b3b13424aa0d640  before=None after=None
2026-06-23T22:35:56Z  ba2d17de21f5a21f9ebd9388693dab4e5b559a1b  before=None after=None
2026-06-24T15:29:03Z  3d7f6481bd60793309e20eef77dede7bf84c85be  before=None after=None
2026-06-25T13:21:33Z  2f0986d503a01a02da071538c2c7c6f467ede4ee  before=None after=None
2026-06-25T17:47:53Z  9d0d1fa57d2620ef674c2970980b3f8466570352  before=None after=None
2026-06-25T17:47:56Z  20a6c767d567bfd56d411876041758cea293fdb4  before=None after=None
2026-06-25T17:48:27Z  0bd8c2f0969bb3841ded91a370cb206bdfcefcad  before=None after=None
2026-06-26T20:48:27Z  1a87551c2fc709c1ff4c62e3c0c77a54761893c2  before=None after=None
2026-06-29T13:54:59Z  d990c3e55654b553b3b0989a0a7b2913d774e313  before=None after=None
2026-06-29T20:01:09Z  d0f38092c2708d43032df19b4477a820267cf3d0  before=None after=None
2026-06-29T20:45:07Z  bf971390d376b3a53d5b9ad3ac01cf94a839e2e6  before=None after=None
2026-06-30T13:12:19Z  a072bb0f9b58233f085ac24dc3b4a94f7c04829e  before=None after=None
2026-06-30T23:40:53Z  3562fd7f58cb1cfffe3c1305cf8fb025afedb715  before=None after=None
2026-07-01T15:56:58Z  ab328631e97ba9be601ff9aec5c9c35fa3131a2b  before=None after=None
2026-07-01T19:52:18Z  123951473e9c8a7cde926704c593f60963933e58  before=None after=None
2026-07-01T21:05:03Z  7d1e3b5b0cb9597a89534c12287dad0f37434b03  before=None after=None
2026-07-02T00:34:01Z  bd5ebb31a712e5e90f9fc788d9ead1e3af7e6e53  before=None after=None
2026-07-02T00:45:42Z  b9a33ae683ba4b98419cb668a2f4cc353ecaece1  before=None after=None
2026-07-02T19:20:03Z  4e9be8baba0606f2cb03d01d81bc135ab2128b12  before=None after=None
2026-07-02T20:01:03Z  4e300d7161a826eddef481c99b6ecfee4887aa75  before=None after=None
2026-07-02T20:23:21Z  a759717b6a54ae82b68f1c862e22e15e42c87b3e  before=None after=None
2026-07-02T20:30:26Z  c56a77da210b8ad9b0b981e2c9c0281c46800096  before=None after=None
2026-07-02T21:27:56Z  981a1045f12088ab03540379d908367c0fb2a3f5  before=None after=None
2026-07-02T22:10:45Z  6a5300a6c3f82c664b38aff2dee52ef566819646  before=None after=None
2026-07-03T15:03:38Z  d4d9fb14689b830bcbf00752a08951633e5ee143  before=None after=None
2026-07-03T15:44:11Z  3838459e2ff78080cd446fd351977cc19c2a33db  before=None after=None
2026-07-03T18:06:18Z  7e668566c92c10d2aff91c8a7bcf848a0d72670f  before=None after=None
2026-07-03T18:34:11Z  10ea8c681a8cf76e0ffb03b738aee0ebe97c6505  before=None after=None
2026-07-03T19:44:20Z  de40f6a4b4f220790255e7f05e0fd88645cdf7b5  before=None after=None
2026-07-06T14:39:16Z  810ebbfb9be7aa5ffc6c31d140910b70cb8d517a  before=None after=None
```
(32 force-pushes; the final `commit_id` 810ebbfb… is also the merged tip.)

---

## 6. PR #40005 — the planning PR (body)

**Request** (GraphQL):
```
gh pr view 40005 --repo RocketChat/Rocket.Chat --json number,title,state,createdAt,closedAt,body
```

**Raw data** (body truncated at 600 chars in the response):
```
title:  Plan: Node runtime to replace Deno runtime for apps-engine subprocess
state:  CLOSED
created: 2026-03-31T09:21:40Z
closed:  2026-07-07T19:27:58Z
body:
  Comprehensive analysis of deno-runtime/ and migration plan to a node-runtime that preserves
  identical behavior without Deno-specific APIs.
  ### Deno API inventory
  Cataloged all Deno-specific surface area across ~25 files:
  - Direct globals: Deno.stdin.readable, Deno.stdout, Deno.stderr, Deno.args, Deno.pid, Deno.exit(), Deno.open()
  - Std library: @std/io (writeAll), @std/cli (parseArgs), @std/streams (toArrayBuffer)
  - Missing in Node: ErrorEvent (needs polyfill), global addEventListener('unhandledrejection')
    → process.on('unhandledRejection')
  - [truncated]
```

---

## 7. PR #41019 — comment & review counts

**Request** (GraphQL):
```
gh pr view 41019 --repo RocketChat/Rocket.Chat --json comments,reviews  (→ python: len of each)
```

**Raw data**:
```
issue comments: 7
reviews: 18
```

---

## 8. Recovered commit metadata for all 32 force-push tips

**Request** (REST, one `GET /commits/{sha}` per SHA; these are now-unreachable commits still served by the API):
```
for sha in <the 32 SHAs from section 5>:
  gh api repos/RocketChat/Rocket.Chat/commits/$sha \
    --jq '[.sha[0:9], (.commit.message|split("\n")[0]), .commit.author.date, .commit.committer.date, ([.parents[].sha[0:9]]|join(","))]|@tsv'
```

**Raw data** (`tip_sha  subject  author.date  committer.date  parent_sha`):
```
984de1d56  fix(apps): linting and typechecking                                       2026-06-20T04:45:35Z  2026-06-21T18:04:05Z  d1e620906
0fd3c3c7e  fix(apps): linting and typechecking                                       2026-06-20T04:45:35Z  2026-06-21T21:18:05Z  e9b74ae3f
17c854876  fix(apps): linting and typechecking                                       2026-06-20T04:45:35Z  2026-06-23T14:34:29Z  865b8d8c6
ba2d17de2  fix(apps): linting and typechecking                                       2026-06-20T04:45:35Z  2026-06-23T22:35:54Z  c3af1bf20
3d7f6481b  chore(ci): include new dir to turbo build outputs                         2026-06-24T15:26:46Z  2026-06-24T15:29:01Z  535712cba
2f0986d50  chore(ci): include new dir to turbo build outputs                         2026-06-24T15:26:46Z  2026-06-25T13:21:31Z  859c8545a
9d0d1fa57  chore(ci): include new dir to turbo build outputs                         2026-06-24T15:26:46Z  2026-06-25T17:39:38Z  027ff062d
20a6c767d  chore(ci): include new dir to turbo build outputs                         2026-06-24T15:26:46Z  2026-06-25T17:47:01Z  2614dfe4c
0bd8c2f09  chore(ci): include new dir to turbo build outputs                         2026-06-24T15:26:46Z  2026-06-25T17:44:46Z  027ff062d
1a87551c2  refactor(apps): use direct ESM imports in node-runtime                    2026-06-26T16:56:41Z  2026-06-26T20:46:03Z  574963fae
d990c3e55  refactor(apps): use direct ESM imports in node-runtime                    2026-06-26T16:56:41Z  2026-06-29T13:33:32Z  3880d0554
d0f38092c  refactor(apps): use direct ESM imports in node-runtime                    2026-06-26T16:56:41Z  2026-06-29T19:59:04Z  981f479c4
bf971390d  refactor(apps): converge deno-runtime toward node-runtime                 2026-06-29T20:44:22Z  2026-06-29T20:44:22Z  402541582
a072bb0f9  docs(apps): rewrite shared-base-runtime proposal for the converged seam   2026-06-29T23:15:36Z  2026-06-30T13:12:09Z  965e91006
3562fd7f5  test(apps): run apps test files serially to avoid subprocess races        2026-06-30T19:29:13Z  2026-06-30T23:39:58Z  82631d5a6
ab328631e  build(apps): wire base-runtime into build, typecheck and test pipelines   2026-06-30T19:28:57Z  2026-07-01T15:46:41Z  12b343f46
123951473  build(apps): wire base-runtime into build, typecheck and test pipelines   2026-06-30T19:28:57Z  2026-07-01T19:50:49Z  452d9641d
7d1e3b5b0  build(apps): wire base-runtime into build, typecheck and test pipelines   2026-06-30T19:28:57Z  2026-07-01T21:03:35Z  979b986c1
bd5ebb31a  refactor(base-runtime): better directory structure                        2026-07-01T21:48:31Z  2026-07-02T00:33:47Z  7e9a24596
b9a33ae68  refactor(base-runtime): better directory structure                        2026-07-01T21:48:31Z  2026-07-02T00:45:23Z  7e9a24596
4e9be8bab  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-02T19:16:41Z  86f118b90
4e300d716  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-02T20:00:01Z  1accd85a7
a759717b6  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-02T20:22:54Z  53ff57cda
c56a77da2  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-02T20:29:15Z  afbddba72
981a1045f  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-02T21:27:28Z  cb72c703c
6a5300a6c  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-02T22:07:22Z  185a42819
d4d9fb146  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-03T14:53:54Z  c216960fa
3838459e2  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-03T15:42:40Z  bd4d4b11f
7e668566c  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-03T18:03:42Z  bc1ee77f7
10ea8c681  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-03T18:32:57Z  13283e2fe
de40f6a4b  chore(ci): add dedicated CI step for node-runtime tests                   2026-06-19T19:22:29Z  2026-07-03T19:43:45Z  f607d7799
810ebbfb9  add changeset                                                             2026-07-03T19:59:54Z  2026-07-06T14:39:05Z  6fd61962a
```
Note: 32 pushes → 30 distinct parent SHAs (`027ff062d` and `7e9a24596` each appear twice), i.e. a fresh base at nearly every push. Author date `2026-06-19T19:22:29Z` at the tip from `4e9be8bab` (Jul 2) onward = a day-one commit resurfaced to the top → interactive rebase.

---

## 9. PR #41019 — review submissions (state / date / author)

**Request** (GraphQL):
```
gh pr view 41019 --repo RocketChat/Rocket.Chat --json reviews \
   --jq '.reviews[] | [.submittedAt, .state, .author.login] | @tsv'   (sorted)
```

**Raw data** (`submittedAt  state  author`):
```
2026-06-22T16:31:33Z  COMMENTED  coderabbitai
2026-07-03T20:49:18Z  COMMENTED  d-gubert
2026-07-03T20:49:46Z  COMMENTED  coderabbitai
2026-07-03T21:58:40Z  COMMENTED  coderabbitai
2026-07-03T22:02:53Z  COMMENTED  cubic-dev-ai
2026-07-03T22:21:47Z  COMMENTED  hacktron-app
2026-07-06T14:42:00Z  COMMENTED  d-gubert
2026-07-06T14:42:14Z  COMMENTED  hacktron-app
2026-07-06T14:44:10Z  COMMENTED  d-gubert
2026-07-06T14:45:23Z  COMMENTED  d-gubert
2026-07-06T14:47:11Z  COMMENTED  d-gubert
2026-07-06T14:47:25Z  COMMENTED  cubic-dev-ai
2026-07-06T14:50:48Z  COMMENTED  d-gubert
2026-07-06T14:50:58Z  COMMENTED  cubic-dev-ai
2026-07-06T15:03:28Z  COMMENTED  coderabbitai
2026-07-06T15:43:47Z  COMMENTED  d-gubert
2026-07-06T15:44:13Z  COMMENTED  cubic-dev-ai
2026-07-06T17:37:19Z  APPROVED   ggazzo
```
(18 reviews; only APPROVED is `ggazzo` at 2026-07-06T17:37:19Z, ~17s before merge.)

---

## 10. PR #41019 — inline review-comment count

**Request** (REST):
```
gh api repos/RocketChat/Rocket.Chat/pulls/41019/comments --paginate --jq 'length'
```

**Raw data**:
```
24
```

---

## 11. PR #40005 — diff stats (structured)

**Request** (GraphQL):
```
gh pr view 40005 --repo RocketChat/Rocket.Chat \
   --json createdAt,closedAt,mergedAt,state,additions,deletions,changedFiles
```

**Raw data**:
```json
{"created":"2026-03-31T09:21:40Z","closed":"2026-07-07T19:27:58Z","merged":null,
 "state":"CLOSED","add":590,"del":0,"files":1}
```

---

## 12. PR #41232 — the IPC continuation

**Request** (GraphQL):
```
gh pr view 41232 --repo RocketChat/Rocket.Chat \
   --json number,title,state,createdAt,closedAt,mergedAt,baseRefName,additions,deletions,changedFiles,body
```

**Raw data** (body truncated at 500 chars):
```json
{"num":41232,"title":"feat(apps): replace stdio stream communication with Node IPC channel",
 "state":"OPEN","created":"2026-07-08T01:29:14Z","merged":null,
 "base":"chore/remove-deno-runtime","add":722,"del":358,"files":21,
 "body":"## Proposed changes ...\nExecutes the plan recommended in packages/apps/docs/ipc-channel-feasibility.md: communication between the Apps-Engine host process and the app subprocess now happens over Node's built-in IPC channel (child.send() / process.send() with serialization: 'advanced') instead of a msgpack-encoded byte stream over stdin/stdout, and all scaffolding that existed to support the stdio transport is removed.\nWhat changes, in order of the commits: [truncated]"}
```
Key: `base = chore/remove-deno-runtime` → #41232 is stacked on #41201's branch.

---

## 13. Commit lists at 4 key tips (branch size vs develop)

**Request** (REST, `GET /compare/{base}...{head}`; `ahead_by` = commits on the branch not in the *current* `develop`, `merge_base_commit` = fork point):
```
for sha in 1a87551c2… 7d1e3b5b0… 4e9be8bab… de40f6a4b…:
  gh api "repos/RocketChat/Rocket.Chat/compare/develop...$sha" \
     --jq '{ahead:.ahead_by, base:.merge_base_commit.sha[0:9], subjects:[.commits[]|.commit.message|split("\n")[0]]}'
```

**Raw data — tip `1a87551c2` (Jun 26)** — ahead 10, merge-base `294ee5d6f`:
```json
{"ahead":10,"base":"294ee5d6f","subjects":[
 "fix(deno): lint problem",
 "refactor(apps): drop .ts extensions and use direct ESM imports in deno-runtime",
 "feat(apps): duplicate deno-runtime as node-runtime",
 "feat(apps): adapt apps package to accept node-runtime",
 "chore(ci): add dedicated CI step for node-runtime tests",
 "tests(apps): fix node-runtime tests",
 "fix(apps): linting and typechecking",
 "chore(ci): include new dir to turbo build outputs",
 "docs(apps): add shared base runtime proposal",
 "refactor(apps): use direct ESM imports in node-runtime"]}
```

**Raw data — tip `7d1e3b5b0` (Jul 1, PEAK)** — ahead 16, merge-base `761314d5e`:
```json
{"ahead":16,"base":"761314d5e","subjects":[
 "refactor(apps): drop .ts extensions and use direct ESM imports in deno-runtime",
 "tests(apps): prevent node tests from running concurrently",
 "refactor(apps): drop Deno specific APIs in deno-runtime",
 "refactor(apps): converge deno-runtime toward node-runtime",
 "refactor(apps): converge error-handlers notification shape in deno-runtime",
 "refactor(apps): converge deno-runtime AST onto real acorn types",
 "feat(apps): duplicate deno-runtime as node-runtime",
 "feat(apps): adapt apps package to accept node-runtime",
 "chore(ci): add dedicated CI step for node-runtime tests",
 "docs(apps): add shared base runtime proposal",
 "docs(apps): rewrite shared-base-runtime proposal for the converged seam",
 "docs(apps): correct base-runtime consumption model in proposal",
 "refactor(apps): extract shared base-runtime from node/deno trees",
 "refactor(apps): reduce node-runtime to a thin base adapter",
 "refactor(apps): reduce deno-runtime to a thin base adapter",
 "build(apps): wire base-runtime into build, typecheck and test pipelines"]}
```

**Raw data — tip `4e9be8bab` (Jul 2)** — ahead 15, merge-base `e5da5d016`:
```json
{"ahead":15,"base":"e5da5d016","subjects":[
 "refactor(apps): drop Deno specific APIs in deno-runtime",
 "refactor(apps): converge deno-runtime toward node-runtime",
 "refactor(apps): converge error-handlers notification shape in deno-runtime",
 "refactor(apps): converge deno-runtime AST onto real acorn types",
 "fix(deno-runtime): better location for subprocess validation",
 "refactor(deno-runtime): move prepareEnvironment to main.ts",
 "refactor(deno-runtime): extract sandbox config from construct.ts",
 "refactor(deno-runtime): extract main handler loop from main.ts",
 "docs(apps): add shared base runtime proposal",
 "refactor(base-runtime): extract shared base-runtime from node/deno trees",
 "build(apps): wire base-runtime into build, typecheck and test pipelines",
 "refactor(deno-runtime): reduce deno-runtime to a wrapper for base-runtime",
 "feat(apps): Introduce node-runtime",
 "feat(apps): adapt apps package to accept node-runtime",
 "chore(ci): add dedicated CI step for node-runtime tests"]}
```

**Raw data — tip `de40f6a4b` (Jul 3, COLLAPSED)** — ahead 3, merge-base `8dc49642d`:
```json
{"ahead":3,"base":"8dc49642d","subjects":[
 "feat(apps): introduce node-runtime",
 "feat(apps): adapt apps package to accept node-runtime",
 "chore(ci): add dedicated CI step for node-runtime tests"]}
```

Branch-size trajectory: **10 → 16 → 15 → 3** (final merged form adds the changeset commit → 4). Merge-base advanced `294ee5d6 → 761314d5 → e5da5d01 → 8dc49642` (fresh rebase each step).

---

## Endpoint summary

| # | Endpoint | Type | Calls |
|---|----------|------|-------|
| 1,2,4,6,7,9,11,12 | `gh pr view` | GraphQL | 10 |
| 3A | `gh pr list` | GraphQL | 1 |
| 3B, 5 | `GET /issues/41019/timeline` | REST | 2 |
| 8 | `GET /commits/{sha}` | REST | 32 |
| 10 | `GET /pulls/41019/comments` | REST | 1 |
| 13 | `GET /compare/develop...{sha}` | REST | 4 |

Total: ~50 GitHub requests (11 GraphQL `gh` invocations + ~39 REST calls).

*Caveats:* several `body` fields were captured truncated (noted inline); the timeline outputs in §3B/§5 were filtered client-side (raw payload not retained in full); `ahead_by` in §13 is measured against **current** `develop`, so it reflects commits unique to the branch at that tip (the intended "branch size" reading).
