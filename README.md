# sammrai/skills

Personal Claude Code skills collection, distributed as a plugin marketplace.

## Install

In Claude Code:

```
/plugin marketplace add sammrai/skills
/plugin install app-traffic-analysis@sammrai-skills
```

## Plugins

| Plugin | Description |
|---|---|
| `app-traffic-analysis` | Capture mobile app HTTPS traffic via mitmproxy and auto-generate `openapi.yaml` (mitmproxy2swagger with XML response support) |

## Layout

```
.claude-plugin/
└── marketplace.json        Marketplace manifest

skills/
└── app-traffic-analysis/
    ├── SKILL.md
    └── assets/
```
