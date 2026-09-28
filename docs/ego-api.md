# EGO API Dokümantasyonu

Ankara EGO Genel Müdürlüğü web sitesinden elde edilen API dokümantasyonu.

**Base URL:** `https://www.ego.gov.tr`

---

## Otobüs Nerede

Belirtilen durak numarasına yaklaşan otobüsleri ve tahmini varış sürelerini döndürür.

> ⚠️ **Eylül 2026 değişikliği:** Eski `POST /otobusnerede` (`durak_no=...`) artık
> "YAPILAN İŞLEMDE HATA OLUŞTU" sayfası döndürüyor. Sorgu artık üç adımlı ve
> dinamik token'lı. Sitenin bunu yapan JS'i `modernizr.min.js` dosyasının sonuna
> gizlenmiş (obfuscated) durumda.

**Akış** (üç istek de aynı çerezleri — `ASP.NET_SessionId` vb. — paylaşmalı):

1. `GET /otobusnerede` → sayfadaki formdan durak alanının **rastgele** adı okunur:
   ```html
   <form id="5615486279" class="bus-form" name="5615486279" method="post" action="/otobusnerede/sorgula">
     <input type="hidden" id="guvenlikToken" name="__RequestVerificationToken" value="...">
     <input type="text" id="5615486279" autocomplete="off" name="5615486279">
   ```
   Sayfadaki `__RequestVerificationToken` değeri **kullanılmaz**; JS onu 2. adımdaki token ile değiştirir.
2. `GET /Security/GetDynamicToken` — header `X-Custom-Req: JS-Tetikleme` zorunlu.
   Yanıt: `{"success":true,"token":"BzDF_PBe..."}`
3. `POST /otobusnerede/sorgula` (`application/x-www-form-urlencoded`):
   `__RequestVerificationToken=<token>&<alan_adı>=<durak_no>`

**Örnek (curl):**
```bash
curl -s -c jar -b jar https://www.ego.gov.tr/otobusnerede > form.html
FIELD=$(grep -oE 'class="bus-form" name="[0-9]+"' form.html | grep -oE '[0-9]+')
TOKEN=$(curl -s -c jar -b jar -H "X-Custom-Req: JS-Tetikleme" \
  https://www.ego.gov.tr/Security/GetDynamicToken | sed -E 's/.*"token":"([^"]+)".*/\1/')
curl -s -c jar -b jar -X POST https://www.ego.gov.tr/otobusnerede/sorgula \
  -H "Referer: https://www.ego.gov.tr/otobusnerede" \
  --data "__RequestVerificationToken=$TOKEN&$FIELD=10135"
```

**Yanıt DOM yapısı** (Eylül 2026):
```html
<div class="bus-card">
  <div class="route-badge">502</div>                       <!-- ÖHO hatlarında: route-badge-ozel -->
  <div class="route-main">
    <div class="route-title">KAHRAMANKAZAN-SIHHİYE</div>   <!-- ÖHO hatlarında: route-title-ozel -->
    <div class="route-meta">06 BK 0928- [08-525]</div>     <!-- plaka- [araç no] -->
  </div>
  <div class="eta">
    <div class="eta-mins" title="Tahmini">14dk 23sn</div>  <!-- ya da "Geliyor" / "Geldi" -->
    <div class="eta-queue" title="...">60/84</div>          <!-- otobüsün durak sırası / sizin durak sıranız -->
  </div>
</div>
```
- `route-meta` artık hız ve araç özelliklerini (Körüklü, Engelli, ...) içermiyor.
  Parser eski virgüllü biçimi (`06 BD 0863, [07-501], Hız:0 km, Solo, ...`) de destekler.
- Yaklaşan otobüs yoksa `bus-list` içinde kart olmaz; sadece IP ve saat görünür.
- Kısa sürede çok sayıda sorgu atılırsa sunucu bir süre **boş liste** döndürebiliyor (HTTP 200).
- Swift: `EGOAPIClient.busArrivals` (akış), `EGOHTMLParser.parseBusFormFieldName` / `parseBusArrivals`.

**Notlar:**
- Durak numarası 5 haneli olmalıdır.
- Response HTML formatındadır, JSON değildir.
- Veri gerçek zamanlıdır (canlı konum).

---

## Hat Listesi

> ⚠️ **Eylül 2026 değişikliği:** `/AjaxData/HatListesi*` endpoint'leri kaldırıldı (404).
> Listeler artık `GET /HareketSaatleri` sayfasına gömülü üç `<select>` içinde geliyor.

```
GET /HareketSaatleri
```

| `<select>` id | Tür |
|---|---|
| `hat_liste_otobus` (name `hat_no1`) | Otobüs |
| `hat_liste_metro` (name `hat_no2`) | Metro |
| `hat_liste_ankaray` (name `hat_no3`) | Ankaray |

```html
<select ... name="hat_no1" id="hat_liste_otobus">
  <option value="0" selected>OTOBÜS</option><option value="101"> (101 ) - GÖLBAŞI-HAYMANA YOLU-BAHÇELİEVLER</option>...
</select>
```

**Notlar:**
- İlk satır başlıktır (`value="0"`) → atlanır.
- Etiket formatı ` (101 ) - GÖLBAŞI-...`; ` (kod ) - ` öneki temizlenip hat adı alınır.
- Swift parser: `EGOHTMLParser.parseLineList` (select id'si `TransitType.lineListSelectID`).

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
- Hat numarası `/HareketSaatleri` sayfasındaki `<select>` listelerinden alınır.
- IP kısıtlaması yoktur.
