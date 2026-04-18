# sammrai/skills

Personal Claude Code skills collection.

## Layout

```
skills/
└── app-traffic-analysis/   Capture mobile app HTTPS traffic via mitmproxy and generate openapi.yaml
```

## Install

Clone this repo, then symlink individual skills into `~/.claude/skills/`:

```bash
git clone https://github.com/sammrai/skills.git ~/src/sammrai-skills
ln -s ~/src/sammrai-skills/skills/app-traffic-analysis ~/.claude/skills/app-traffic-analysis
```
