# Minti Studio — Veri Modeli Referansı

> Bu dosya Minti Studio'nun analytics ile ilgili Postgres tablolarını belgeler.
> Amaç: Codex'e prompt verirken ve dbt modelleri yazarken yanlış tablo/kolon
> varsayımını önlemek. Her yeni veri görevinde bu dosyayı referans al.
>
> Şema: tüm tablolar `main` şemasında.
> Tek aktif brand: "Hocaefendiden Kisa Kisa" (`is_default = true`).
> Sistem multi-brand'i destekler ama pratikte şu an tek aktif brand var.

---

## Hızlı bakış (tablo rolleri)

| Tablo | Rol | Granülarite |
|---|---|---|
| `shorts_generated_videos` | Üretilen/yayınlanan her Short (MERKEZ tablo) | 1 satır = 1 video |
| `shorts_brands` | Marka tanımları + owner | 1 satır = 1 brand |
| `shorts_video_daily_snapshots` | Günlük video metrikleri (view, like, vb.) — çok platform | gün × video × platform |
| `raw_yt_traffic_sources` | YouTube trafik kaynağı kırılımı (views nereden geldi) | gün × video × kaynak tipi |
| `raw_yt_video_retention` | YouTube video retention + subscribers (YENİ) | gün × video |
| `shorts_channel_subscriber_daily` | Günlük kanal abone/follower sayısı — çok platform | gün × kanal × platform |
| `youtube_channels` | KAYNAK kanallar (içerik indirilen, BİZİM DEĞİL) | 1 satır = 1 kaynak kanal |

---

## ⚠️ Kritik tuzaklar (bu oturumda öğrenilenler)

1. **`youtube_video_id` kullan, `source_video_id` DEĞİL.**
   `shorts_generated_videos`'ta iki ID var:
   - `source_video_id` = içeriğin indirildiği KAYNAK videonun ID'si (başkasının videosu).
   - `youtube_video_id` = bizim YAYINLADIĞIMIZ Short'un gerçek YouTube ID'si.
   YouTube Analytics / API çağrılarında ve join'lerde HER ZAMAN `youtube_video_id`.

2. **`youtube_channels` BİZİM yayın kanallarımız DEĞİL.**
   Bunlar içerik indirdiğimiz kaynak kanallar (Pırlanta Sözler, HerkulNagme vb.).
   YouTube Analytics bu kanalların verisini VEREMEZ (sadece `channel==MINE` çalışır).
   Bizim analytics çekebildiğimiz tek şey: kendi yayınladığımız Short'lar.

3. **`shorts_brands`'te `is_active` kolonu YOKTUR.** Aktiflik için `is_default` var.
   Brand aktiflik filtresi yazma; pratikte sadece default brand'in published videosu var.

4. **"published" illa YouTube demek değil.** Minti çok platformlu.
   `publish_status='published'` bir video en az bir platforma gitti demek.
   YouTube için ayrıca `youtube_video_id IS NOT NULL` filtresi gerekir.

5. **DB katmanı `?` placeholder kullanır (psycopg değil, custom abstraction).**
   `%s` değil. Mevcut koda (`daily_subscriber_snapshot.py`) bak.

---

## Tablolar (gerçek kolonlar)

### shorts_generated_videos  (MERKEZ — üretilen Short'lar)
Her Minti tarafından üretilen/yayınlanan video. ~376 satır toplam,
~156'sı published + youtube_video_id dolu.

| kolon | tip | not |
|---|---|---|
| id | bigint | PK (Minti internal) |
| brand_id | varchar | → shorts_brands.id |
| source_video_id | varchar | KAYNAK video ID — analytics'te KULLANMA |
| source_channel_type | varchar | kaynak platform |
| clip_filename | varchar | |
| output_filename | varchar | |
| storage_file_key | varchar | S3 key |
| generation_status | varchar | |
| publish_status | varchar | 'published' / 'not_ready' / 'failed' |
| youtube_video_id | varchar | ⭐ YAYINLANAN YouTube ID — analytics join anahtarı |
| instagram_media_id | varchar | |
| facebook_video_id | varchar | |
| tiktok_video_id | varchar | |
| planned_publish_at | timestamp | |
| published_at | timestamp | |
| plan_run_id | varchar | |
| raw_plan_entry_json | jsonb | başlık/kategori/transcript burada da var |
| created_at | timestamp | |
| updated_at | timestamp | |
| generated_title | text | video başlığı |
| generated_description | text | |
| generated_excerpt | text | |
| generated_transcript_full | text | |
| youtube_published_at | timestamp | |
| instagram_published_at | timestamp | |
| facebook_published_at | timestamp | |
| tiktok_published_at | timestamp | |
| primary_publish_platform | varchar | |

### shorts_brands  (marka tanımları)
| kolon | tip | not |
|---|---|---|
| id | varchar | PK (uuid) → diğer tablolarda brand_id |
| owner_user_id | varchar | sahip kullanıcı |
| name | varchar | "Hocaefendiden Kisa Kisa" |
| slug | varchar | |
| is_default | boolean | aktiflik proxy'si (is_active YOK) |
| created_at | timestamp | |
| updated_at | timestamp | |

### shorts_video_daily_snapshots  (günlük video metrikleri — çok platform)
Çizimdeki "Views" kutusu. Her gün her video her platform için bir satır.
| kolon | tip | not |
|---|---|---|
| snapshot_date | date | |
| effective_at | timestamp | |
| channel_type | text | youtube / instagram / facebook / tiktok |
| video_id | text | platform video ID (youtube ise youtube_video_id ile eşleşir) |
| channel_id | text | |
| channel_name | text | |
| video_title | text | |
| impressions | bigint | |
| views | bigint | ⭐ raw_yt_traffic_sources'un toplamı buna eşit olmalı (YouTube) |
| comments | bigint | |
| likes | bigint | |
| shares | bigint | |
| reach | bigint | |
| saved | bigint | |
| stats_source | text | |
| brand_id | varchar | → shorts_brands.id |

### raw_yt_traffic_sources  (YouTube trafik kaynağı — YENİ)
YouTube'a özgü. views'ın "nereden geldi" kırılımı. Platform kolonu YOK (hep YouTube).
| kolon | tip | not |
|---|---|---|
| snapshot_date | date | PK |
| video_id | text | PK — = youtube_video_id |
| traffic_source_type | text | PK — SHORTS/SUBSCRIBER/YT_SEARCH/YT_CHANNEL/... |
| views | integer | |
| fetched_at | timestamptz | son çekim zamanı (idempotent upsert için) |

Gerçek trafik kaynağı tipleri (90 günlük veride görülen, view'a göre):
SHORTS (baskın ~%80), SUBSCRIBER, YT_SEARCH, YT_CHANNEL, YT_OTHER_PAGE,
EXT_URL, NOTIFICATION, NO_LINK_OTHER, PLAYLIST, SOUND_PAGE, RELATED_VIDEO.

### raw_yt_video_retention  (YouTube video retention — YENİ)
YouTube'a özgü. Video bazında günlük izlenme kalitesi metrikleri.
Trafik kaynağıyla join'lenince "nereden gelen izleyici ne kadar izledi" analizi yapılır.

| kolon | tip | not |
|---|---|---|
| snapshot_date | date | PK |
| video_id | text | PK — = youtube_video_id |
| views | integer | o günkü toplam view (trafik kaynaklarının toplamına ≈ eşit olmalı) |
| average_view_duration_seconds | numeric | ortalama izlenme süresi (saniye) |
| average_view_percentage | numeric | videonun yüzde kaçı izlendi — 100+ olursa loop var |
| subscribers_gained | integer | o videodan kazanılan abone (genelde çok düşük, Shorts özelliği) |
| fetched_at | timestamptz | idempotent upsert için |

⚠️ Gerçek veriden gözlemler (90 günlük):
- `average_view_percentage > 100` = video loop yapıyor (örn. ha-iSQC8YeE: %106.7, MMonBlvKCv0: %100.4)
- Loop yapan videolar algoritma için en güçlü sinyal
- `subscribers_gained` çok düşük (65K view için bile sadece 43 abone) — Shorts izleyicisi abone olmaya meyilli değil
- En yüksek retention: D891vHj4iP8 %85.3, KisOLVGbBXg %82.1
- `average_view_duration_seconds` × 100 / video_süresi ≈ `average_view_percentage` (kontrol için)

### shorts_channel_subscriber_daily  (günlük abone — çok platform)
| kolon | tip | not |
|---|---|---|
| snapshot_date | date | |
| effective_at | timestamp | |
| channel_type | text | youtube / instagram / facebook / tiktok |
| channel_id | text | |
| channel_name | text | |
| subscriber_count | bigint | |
| stats_source | text | |
| subscriber_count_exact | bigint | |
| subscribers_gained | bigint | YouTube (Analytics API) |
| subscribers_lost | bigint | YouTube |
| subscribers_net | bigint | gained - lost |
| subscriber_count_api_rounded | bigint | |
| brand_id | varchar | → shorts_brands.id |

### youtube_channels  (KAYNAK kanallar — analytics dışı)
⚠️ Bunlar bizim DEĞİL. İçerik indirdiğimiz kaynak kanallar. Analytics çekilemez.
| kolon | tip | not |
|---|---|---|
| channel_id | bigint | PK (internal) |
| channel_name | text | "Pırlanta Sözler" vb. |
| channel_url | text | |
| notes | text | |
| added_at | timestamp | |
| youtube_channel_id | text | gerçek YouTube kanal ID |
| uploads_playlist_id | text | |
| total_videos | integer | |
| is_active | boolean | (bu tabloda var, shorts_brands'te yok) |
| next_page_token | text | |
| owner_user_id | text | |
| baseline_subscribers_exact | bigint | |
| baseline_date | date | |
| brand_id | varchar | |

---

## İlişkiler (join anahtarları)

```
shorts_brands.id
   └──< shorts_generated_videos.brand_id
   └──< shorts_video_daily_snapshots.brand_id
   └──< shorts_channel_subscriber_daily.brand_id

shorts_generated_videos.youtube_video_id
   └──= raw_yt_traffic_sources.video_id          (YouTube trafik kaynağı)
   └──= shorts_video_daily_snapshots.video_id     (channel_type='youtube' iken)
```

## dbt notları
- dbt projesi ayrı repo: `minti-analytics` (live docs: saltikg.github.io/minti-analytics).
- dbt cron'da saatlik çalışır: `~/apps/dbt/run_dbt_build.sh`.
- Multi-target: Postgres (dev) + Snowflake. cast makroları mevcut.
- Yeni source: `raw_yt_traffic_sources`'u sources.yml'e ekle.
- Planlanan: stg_yt_traffic_sources → fct_video_traffic_mix (kaynak sınıflandırma).
- Tutarlılık testi fikri: raw_yt_traffic_sources günlük views toplamı ≈
  shorts_video_daily_snapshots.views (channel_type='youtube').

## İlişkiler (join anahtarları) — GÜNCELLENDİ

```
shorts_brands.id
   └──< shorts_generated_videos.brand_id
   └──< shorts_video_daily_snapshots.brand_id
   └──< shorts_channel_subscriber_daily.brand_id

shorts_generated_videos.youtube_video_id
   └──= raw_yt_traffic_sources.video_id          (YouTube trafik kaynağı)
   └──= raw_yt_video_retention.video_id           (YouTube retention — YENİ)
   └──= shorts_video_daily_snapshots.video_id     (channel_type='youtube' iken)
```

## dbt notları — GÜNCELLENDİ
- dbt projesi ayrı repo: `minti-analytics` (live docs: saltikg.github.io/minti-analytics).
- dbt cron'da saatlik çalışır: `~/apps/dbt/run_dbt_build.sh`.
- Multi-target: Postgres (dev) + Snowflake. cast makroları mevcut.
- Yeni sources eklenecek: `raw_yt_traffic_sources` VE `raw_yt_video_retention` → sources.yml'e ekle.
- Planlanan staging: `stg_yt_traffic_sources`, `stg_yt_video_retention`.
- Planlanan mart: `fct_video_traffic_mix` (kaynak sınıflandırma + retention join).
- Tutarlılık testi: raw_yt_traffic_sources toplamı ≈ raw_yt_video_retention.views ≈ shorts_video_daily_snapshots.views (youtube).

## ingestion notları (youtube_traffic_sources.py)
- Pagination (startIndex) YouTube Analytics 500 hatasına yol açıyor — KULLANMA.
- Bunun yerine tarih penceresi 30 günlük chunk'lara bölünüyor (_date_chunks).
- Default pencere: son 4 gün (YouTube veriyi geriye dönük revize eder).
- Backfill: `ingest_traffic_sources(start_date=date(2026, 2, 26))` — tek komut yeterli.
- Cron: `0 */8 * * *` — günde 3 kez, ayrı flock kilidi (yt_traffic.lock).
