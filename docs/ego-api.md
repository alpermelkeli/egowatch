# EGO API Dokümantasyonu

Ankara EGO Genel Müdürlüğü web sitesinden elde edilen API dokümantasyonu.

**Base URL:** `https://www.ego.gov.tr`

---

## Otobüs Nerede

Belirtilen durak numarasına yaklaşan otobüsleri ve tahmini varış sürelerini döndürür.

```
POST /otobusnerede
Content-Type: application/x-www-form-urlencoded
```

**Request Body:**

| Alan | Tip | Açıklama |
|------|-----|----------|
| `durak_no` | string | 5 haneli durak numarası |

**Örnek İstek:**
```bash
curl -X POST https://www.ego.gov.tr/otobusnerede \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Referer: https://www.ego.gov.tr/otobusnerede" \
  -d "durak_no=10135"
```

**Response:** HTML sayfa. İçinden parse edilecek alanlar:

| CSS Sınıfı | Açıklama | Örnek |
|------------|----------|-------|
| `.eta-mins` | Tahmini varış süresi | `6 dk` |
| `.eta-queue` | `durak_sırası/toplam_durak` formatında konum | `59/52` |
| `.route-meta` | Araç detayı: plaka, hat, hız, tip | `06 DU 3524, [12-570], Hız:8 km, Körüklü, Engelli` |

**Örnek Response Parse (Python):**
```python
import requests, re

resp = requests.post(
    "https://www.ego.gov.tr/otobusnerede",
    data={"durak_no": "10135"},
    headers={"Referer": "https://www.ego.gov.tr/otobusnerede"}
)

html = resp.text
etas   = re.findall(r'eta-mins[^>]+title="([^"]+)"[^>]*>([^<]*)', html)
queues = re.findall(r'eta-queue[^>]+title="([^"]+)"[^>]*>([^<]*)', html)
metas  = re.findall(r'route-meta[^>]+>([^<]+)', html)

for i, meta in enumerate(metas):
    eta   = etas[i][1].strip()   if i < len(etas)   else "-"
    queue = queues[i][1].strip() if i < len(queues) else "-"
    print(f"ETA: {eta} | Konum: {queue} | Detay: {meta.strip()}")
```

**Gerçek DOM yapısı (doğrulandı — bkz. `docs/api-samples/otobusnerede_10135.html`):**
Her otobüs bir `.bus-card` bloğudur; dokümandaki sade alan listesinden daha zengindir:
```html
<div class="bus-card">
  <div class="route-badge">590</div>                         <!-- hat no -->
  <div class="route-main">
    <div class="route-title">KORU METRO İST.-YAŞAMKENT</div>  <!-- yön/başlık -->
    <div class="route-meta">06 BD 0863, [07-501], Hız:0 km, Solo, Engelli, Bisiklet Aparatı</div>
  </div>
  <div class="eta">
    <div class="eta-mins">14 dk</div>
    <div class="eta-queue">59/44</div>
  </div>
</div>
```
Henüz ilk duraktan kalkmamış araçlarda `route-meta` yerine
`Sonraki Hareket Saati İlk Duraktan 16:11 / 2 dk Sonra` yazar ve `eta-*` alanları boştur.
Swift parser: `EGOHTMLParser.parseBusArrivals` (bloğa göre ayrıştırır, paralel diziye değil).

**Notlar:**
- Durak numarası 5 haneli olmalıdır.
- Response HTML formatındadır, JSON değildir.
- Veri gerçek zamanlıdır (canlı konum).
- IP kısıtlaması yoktur.

---

## Hat Listesi

Otobüs, metro ve Ankaray hatlarının listesini döndürür. Response `<option>` tagları içeren HTML'dir.

```
POST /AjaxData/HatListesiOtobus    → Otobüs hatları
POST /AjaxData/HatListesiMetro     → Metro hatları
POST /AjaxData/HatListesiAnkaray   → Ankaray hatları
Content-Type: application/x-www-form-urlencoded
```

**Request Body:** Boş (body gönderilmeli, alan gerekmez)

**Örnek İstek:**
```bash
curl -X POST https://www.ego.gov.tr/AjaxData/HatListesiOtobus \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Referer: https://www.ego.gov.tr/HareketSaatleri" \
  -d " "
```

**Örnek Response:**
```html
<option value="0" selected>OTOBÜS</option>
<option value="101"> (101) - GÖLBAŞI-HAYMANA YOLU-BAHÇELİEVLER</option>
<option value="101-1"> (101-1) - GÖLBAŞI-HAYMANA YOLU-BAHÇELİEVLER-KARAOĞLAN MAHALLESİ</option>
...
```

**Örnek Response Parse (Python):**
```python
import requests, re

resp = requests.post(
    "https://www.ego.gov.tr/AjaxData/HatListesiOtobus",
    data=" ",
    headers={"Referer": "https://www.ego.gov.tr/HareketSaatleri"}
)

hatlar = re.findall(r'<option value="([^"]+)">([^<]+)</option>', resp.text)
for value, label in hatlar:
    print(f"{value}: {label.strip()}")
```

**Notlar (doğrulandı — bkz. `docs/api-samples/hatlistesi_otobus.html`):**
- İlk satır başlıktır: `<option value="0" selected>OTOBÜS</option>` → `value="0"` atlanır.
- Etiket formatı ` (101 ) - GÖLBAŞI-...` şeklindedir; ` (kod ) - ` öneki temizlenip hat adı alınır.
- Türkçe karakterler numerik entity olarak gelir; decode gerekir.
- Swift parser: `EGOHTMLParser.parseLineList`.

---

## Hareket Saatleri

Belirtilen hattın sefer saatlerini, güzergahını ve durak listesini döndürür.

```
POST /HareketSaatleri
Content-Type: application/x-www-form-urlencoded
```

**Request Body:**

| Alan | Tip | Açıklama |
|------|-----|----------|
| `hat_no1` | string | Otobüs hat numarası (örn. `101`) |
| `hat_no2` | string | Metro hat numarası |
| `hat_no3` | string | Ankaray hat numarası |

> Kullanılmayan alanlar boş bırakılır.

**Örnek İstek (Otobüs):**
```bash
curl -X POST https://www.ego.gov.tr/HareketSaatleri \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Referer: https://www.ego.gov.tr/HareketSaatleri" \
  -d "hat_no1=101&hat_no2=&hat_no3="
```

**Response:** HTML sayfa. Parse edilecek alanlar:

| HTML İçeriği | Açıklama | Örnek |
|---|---|---|
| `Hat No` satırı | Hat numarası | `101` |
| `Hat Adı` satırı | Güzergah adı | `GÖLBAŞI-BAHÇELİEVLER` |
| `Kalkış Yeri` satırı | Kalkış noktası | `BAHÇELİEVLER MH. GÖLBAŞI` |
| `Mesafesi` satırı | Toplam mesafe | `43 km` |
| `Süresi` satırı | Sefer süresi | `73 dakika` |
| Sefer saatleri kolonu | Hafta içi / Cumartesi / Pazar saatleri | `08:00, 09:00, ...` |
| Durak satırları | Sıra no, durak kodu, durak adı, mahalle | `1 \| 14043 \| GÖLBAŞI HAREKET NOKTASI` |

**Gerçek DOM yapısı (doğrulandı — bkz. `docs/api-samples/hareketsaatleri_101.html`):**
- Hat bilgileri: `<table class="hs-kv">` içinde `<td class="key">Hat No</td>...<td>101</td>` satırları
  (Hat No, Hat Adı, Kalkış Yeri, Mesafesi, Süresi).
- Sefer saatleri: `<table class="hs-table">` — üç kolon (Hafta içi / Cumartesi / Pazar),
  her kolon `<td class="hs-times">` içinde `08:00 -<br/>09:00 -<br/>...` biçiminde.
- Duraklar: `<table class="route-table">` (caption "Geçtiği Güzergahlar") `tbody` satırları
  `Sıra | Durak No | Durak Adı | Durak Adres`.
- ⚠️ Yanıtta Türkçe karakterler **numerik HTML entity** olarak gelir (`G&#214;LBAŞI`); decode gerekir.
- Swift parser: `EGOHTMLParser.parseLineSchedule`.

**Notlar:**
- Response HTML formatındadır, JSON değildir.
- Hat numarası `/AjaxData/HatListesi*` endpoint'lerinden alınır.
- IP kısıtlaması yoktur.
