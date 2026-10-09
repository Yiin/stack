# stack

Source for https://stack.yiin.lt: an explainer page plus a download of the agent stack
(AGENTS.md, /orchestrate, /plan-epic, /cook-epic, /cook-it, project-map).

- `site/index.html` is the page.
- `site/files/` holds the shared files. They are copies, with personal details removed.
- `site/img/` holds the illustrations. `art/gen.sh` made them with Gemini (`art/gen.sh <name> <aspect> "<prompt>"`), then `magick <name>.img -quality 82 site/img/<name>.webp`.
- `./build.sh` rebuilds `site/stack.tar.gz`. Run it after you change `site/files/`.

Coolify builds the Dockerfile (nginx), app xvb9vv2s6rjghhkgw9bgds74. A push to `main` does not start a deploy (checked 2026-10-09). Push, then start it with the `use-coolify` skill (`POST /applications/<uuid>/start`).
