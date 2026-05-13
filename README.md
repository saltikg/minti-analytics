# minti-analytics

dbt Core analytics project for [Minti Studio](https://mintistudio.com) — a solo-built social video brand operating on YouTube Shorts and Instagram Reels.

This project transforms raw ingestion data (YouTube API, Instagram API) into clean analytics models using a staging → marts architecture on PostgreSQL.

---

## Architecture

```
YouTube API ──┐
              ├──► Flask Ingestion App ──► PostgreSQL (main schema)
Instagram API ─┘                                    │
                                                    ▼
                                          dbt (this project)
                                                    │
                                                    ▼
                                         PostgreSQL (analytics schema)
                                                    │
                                                    ▼
                                           Minti Studio Dashboard
```

**Stack:** Python · Flask · PostgreSQL · dbt Core · AWS EC2 · AWS S3

---

## Project Structure

```
models/
├── staging/          # Cleaned views on top of raw source tables
├── intermediate/     # Mid-layer transformations
└── marts/            # Fact and dimension tables for analytics
```

### Staging Models
| Model | Description |
|-------|-------------|
| `stg_shorts_generated_videos` | Generated video records with pipeline metadata |
| `stg_video_daily_snapshots` | Daily performance snapshots per video |
| `stg_shorts_channel_subscriber_daily` | Daily subscriber counts per channel |
| `stg_comments` | Normalized comments from YouTube and Instagram |
| `stg_social_comment_cache` | Cross-platform comment cache (YouTube, Instagram, Facebook) |

### Mart Models
| Model | Description |
|-------|-------------|
| `fct_video_daily_metrics` | Daily view, like, and comment counts per video |
| `fct_video_daily_deltas` | Day-over-day metric changes per video |
| `fct_channel_daily_growth` | Daily subscriber growth per channel |
| `fct_social_comments` | Unified comment feed across platforms |
| `dim_generated_videos` | Dimension table for AI-generated video metadata |

### Intermediate Models
| Model | Description |
|-------|-------------|
| `fct_generated_video_content` | Content-level aggregations for generated videos |

---

## Data Sources

Raw tables live in the `main` schema of the `minti_studio` PostgreSQL database.

| Source Table | Description |
|---|---|
| `shorts_video_daily_snapshots` | Daily performance snapshots per short video |
| `shorts_generated_videos` | Generated video records and production outputs |
| `shorts_channel_subscriber_daily` | Historical daily subscriber metrics per channel |
| `social_comment_cache` | Normalized comments across YouTube, Instagram, Facebook |

---

## Orchestration

- **Runtime:** dbt Core on AWS EC2
- **Schedule:** Cron job at 02:00 UTC daily
- **Command:** `dbt build` (runs + tests all models)

---

## dbt Commands

```bash
dbt debug        # Test connection
dbt run          # Run all models
dbt test         # Run all tests
dbt build        # Run + test in one command
dbt docs generate && dbt docs serve   # View lineage graph
```

---

## About Minti Studio

Minti Studio is a Turkish-language social video brand with 13K+ YouTube Shorts subscribers and 5K+ Instagram Reels followers. The full platform includes AI-assisted video generation, transcript extraction (OpenAI Whisper), and multi-platform publishing — all built and operated solo since 2022.