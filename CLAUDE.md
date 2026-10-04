@AGENTS.md

## Claude Code

- `graphify-out/graph.json` is a code knowledge graph of this repo. Before a repo-wide search, run `graphify explain "<Class>"` or `graphify affected "<file path>"`; the rules and limits are in the "Knowledge Graph (graphify)" section of AGENTS.md.
- This file must stay a regular file. Do not replace it with a symlink to AGENTS.md: on Windows a symlink checks out as a one-line text file and none of AGENTS.md gets loaded.
