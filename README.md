# sammrai/skills

Personal Claude Code skills collection, distributed as a plugin marketplace.

## Install

In Claude Code:

```
/plugin marketplace add sammrai/skills
/plugin install app-traffic-analysis@sammrai-skills
/plugin install browser-har-capture@sammrai-skills
```

## Plugins

| Plugin | Description |
|---|---|
| `app-traffic-analysis` | Capture mobile app HTTPS traffic via mitmproxy and auto-generate `openapi.yaml` (mitmproxy2swagger with XML response support) |
| `browser-har-capture` | Record and verify browser network traffic for web application workflows |

## Layout

```
.claude-plugin/
└── marketplace.json        Marketplace manifest

skills/
└── app-traffic-analysis/
    ├── SKILL.md
    └── assets/
└── browser-har-capture/
    └── SKILL.md
```
