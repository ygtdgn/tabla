# Util: macOS için Alt-Tab + Clipboard Geçmişi (Tasarım)

Tarih: 2026-11-05 · Durum: onaylandı (2026-11-06)

## 1. Ne ve neden

Kullanıcı için tek, native bir macOS menü çubuğu uygulaması. İki özelliği var:

1. **Alt-Tab:** Windows'taki gibi pencere bazlı geçiş, canlı önizlemelerle.
2. **Clipboard geçmişi:** kopyalanan metinlere ve görsellere sonradan erişim.

**Neden kendi uygulaması?** (kullanıcının söyledikleri)
- Hazır alternatifler (AltTab, Maccy, Paste vb.) para istiyor.
- Kendi uygulaması olsun, sonradan özellik eklenebilsin, ucu açık bir temel olsun.
- Güvenlik: kopyalanan veriler bilgisayardan çıkmamalı.

**Cmd+Tab'da kullanıcıyı rahatsız eden şeyler:**
- Önizleme yok.
- Uygulama bazlı çalışıyor. Hızlı basınca sadece bir önceki uygulamaya gidiyor, bütün açık pencereleri hızlıca göremiyor.

**Kodu kim yazacak:** Kullanıcı Swift yazmayacak, yeni özellikleri de Claude'dan isteyecek. Bu yüzden kod okunur ve modüler olmalı. Yeni bir özellik mevcut modüllere dokunmadan eklenebilmeli.

## 2. Hedefler

- Option+Tab ile açılan, pencere bazlı, canlı önizlemeli bir geçiş paneli.
- Cmd+Shift+V ile açılan, aranabilen, sabitleme destekli bir clipboard geçmişi (metin ve görsel).
- Tamamen yerel çalışma. Ağ erişimi yok.
- Yeni özellik eklemeye hazır bir uygulama iskeleti.

## 3. Hedef dışı (v1)

- Cmd+Tab'ı değiştirmek ya da devre dışı bırakmak. Cmd+Tab olduğu gibi kalır.
- Parola tespiti, hassas öğe kilidi, Touch ID ile açma. Kullanıcı bunu açıkça bıraktı: her şey normal metin olarak geçmişe girer.
- App Store dağıtımı. Sandbox, gereken API'lere (event tap, Erişilebilirlik, pencere yakalama) izin vermiyor.
- Başkalarına dağıtım ve notarization. Sadece kullanıcının kendi makinesi için.
- iCloud senkronu, cihazlar arası paylaşım.
- Finder'da dosya kopyalama (dosya referansları). v1'de geçmişe alınmaz (benim kararım).
- Ayarlar penceresinden kısayol değiştirme. v1'de kısayollar sabit, ama kodda tek bir yerde tanımlı (benim kararım).

## 4. Anti-hedefler (çalışsa bile başarısızlık sayılır)

- **Herhangi bir verinin internete gitmesi.** Uygulamada ağ kodu, analytics, crash reporter ya da otomatik güncelleyici olmayacak.
- **Panelin geç açılması ya da takılması.** Option basılı tutulduğunda panel ~0,1 sn içinde görünmeli. Bu bekleme sadece hızlı geçişte panelin yanıp sönmesini engellemek için var. Daha uzun bir bekleme ya da takılma kabul edilmez.
- **Arka planda sürekli CPU veya pil tüketmek.** Örneğin panel kapalıyken sürekli ekran görüntüsü almak.
- **Kullanıcının alışık olduğu sistem davranışlarını bozmak.** Cmd+Tab ve normal Cmd+C / Cmd+V aynen çalışmaya devam etmeli.

## 5. Kısıtlar ve ortam

- Kullanıcının makinesi: macOS 27.0.1, Apple Silicon, Xcode kurulu, Swift 6.4.
- Dil: Swift. UI tarafında AppKit ile SwiftUI karışık kullanılabilir. Paneller için `NSPanel` ve `NSVisualEffectView` uygun. Seçim builder'ın.
- Uygulama sandbox dışında çalışır.
- Gereken izinler:
  - **Erişilebilirlik (Accessibility):** pencere listesi, pencereyi öne getirme, Option+Tab'ı yakalayan event tap, Cmd+V gönderme.
  - **Ekran Kaydı (Screen Recording):** pencere önizlemeleri. ScreenCaptureKit kullanılır.
- **İmzalama:** macOS izinleri ve Keychain erişimi kod imzasına bağlı. Her build'de imza değişirse kullanıcı izinleri tekrar tekrar vermek zorunda kalır. Bu yüzden build'ler sabit bir sertifikayla imzalanmalı, ad-hoc imza kullanılmamalı.
  - **Kullanıcının kararı:** imzalama **Yumo Teknoloji** developer hesabının Apple Development sertifikasıyla yapılacak.
  - Bu sertifika şu an makinede yok. İlk build'den önce kullanıcı Yumo hesabını Xcode → Settings → Accounts'a eklemeli. Xcode sertifikayı kendisi oluşturur.
  - Plan ve kod yazımı bunu beklemez, sadece ilk çalıştırmadan önce gerekir.
  - Sertifika sonradan değişirse izinlerin bir kez yeniden verilmesi gerekir.

## 6. Uygulama kabuğu

- **Menü çubuğu uygulaması.** Dock'ta ikon yok (`LSUIElement`).
- **Ad:** "Util" (benim kararım, klasör adından). Bundle id builder'ın kararı.
- **Menü çubuğu menüsü:**
  - Clipboard'u aç
  - Geçmişi temizle
  - Girişte başlat (açık/kapalı)
  - İzinler…
  - Çık
- **Girişte başlat:** `SMAppService` ile. İlk çalıştırmada varsayılan olarak açık (benim kararım).
- **İlk çalıştırma ekranı:** Hangi iznin ne için gerektiğini Türkçe anlatır. Her izin için yanında bir durum göstergesi (verildi/verilmedi) ve "Sistem Ayarları'nı aç" düğmesi bulunur. İzin verilince ekran kendini günceller.
- **Arayüz dili:** Türkçe.
- **Görünüm:** Paneller sistemin açık/koyu moduna uyar, bulanık yarı saydam bir arka planı olur (benim kararım).
- **Modüler yapı (benim kararım):**
  - `Core`: izinler, global kısayollar / event tap, şifreli depolama, ortak yardımcılar.
  - `Features/Switcher`: Alt-Tab.
  - `Features/Clipboard`: clipboard geçmişi.
  - Her özellik basit bir ortak arayüze (başlat/durdur, menü öğeleri) uyar. Yeni özellik eklemek = yeni bir `Features/X` klasörü.

## 7. Alt-Tab (Switcher)

### Davranış (kullanıcı onayladı)

- **Kısayol: Option+Tab.**
  - Option basılı tutulup Tab'a basılınca panel **~0,1 sn** sonra açılır. Kullanıcı bu kısa beklemeyi seçti. Bekleme süresi kodda tek bir sabit olarak tanımlanır.
  - Option basılıyken Tab bir sonraki pencereye, Shift+Tab bir öncekine geçer.
  - **Option bırakılınca** seçili pencere öne gelir ve odaklanır.
  - **Esc:** panel kapanır, hiçbir şey değişmez.
  - **Hızlı basıp bırakma:** Option+Tab'a basıp 0,1 sn dolmadan bırakmak, Windows'taki gibi bir önceki pencereye geçer. Panel hiç görünmez, yanıp sönmez.
  - Bekleme sırasında birden fazla Tab basılırsa seçim yine ilerler. Option o sırada bırakılırsa, panel görünmemiş olsa da seçilen pencereye geçilir.
  - Panelde bir karta fareyle tıklamak o pencereye geçer.
- **Pencere bazlı liste.** Uygulama değil, her pencere ayrı bir öğe. Örneğin Chrome'da 3 pencere varsa 3 ayrı kart görünür.
- **Sıralama:** en son kullanılan pencereden en eskiye (MRU).
- **Dahil edilenler:** küçültülmüş (minimize) pencereler ve diğer masaüstlerindeki (Spaces) pencereler de listede.
- **Konum:** panel, farenin bulunduğu ekranın ortasında açılır.
- Option+Tab kombinasyonu yakalanır ve aktif uygulamaya iletilmez. Tek başına Option ya da diğer Option kombinasyonları normal çalışmaya devam eder.

### Görünüm (kullanıcı A taslağını seçti)

- Ekranın ortasında yarı saydam, bulanık, köşeleri yuvarlak bir panel.
- **Tek sırada büyük önizleme kartları.** Her kartın üstünde uygulama ikonu ve pencere başlığı, altında pencerenin önizlemesi.
- Seçili kartta mavi bir çerçeve ve hafif mavi bir arka plan.
- Pencereler bir sıraya sığmazsa alt satıra geçer. Çok sayıda pencerede kart boyutu küçülür, panel ekran dışına taşmaz.
- Önizleme oranı pencerenin kendi oranını korur.

### Builder'a bırakılan teknik konular

- **Pencere listesi:** Muhtemelen `CGWindowListCopyWindowInfo`, uygulama başına `AXUIElement` ve diğer Space'ler için gereken özel (private) API'lerin bir birleşimi. Bilinen açık kaynak AltTab'ın yaklaşımı referans alınabilir. Kişisel kullanım olduğu için private API kullanmak kabul edilebilir.
- **MRU takibi:** `NSWorkspace` aktivasyon bildirimleri ve AX odaklanmış pencere gözlemcileri.
- **Önizleme alma:** ScreenCaptureKit ile.
  - Küçültülmüş ya da başka Space'teki bir pencerenin canlı görüntüsü alınamıyorsa son önbelleklenmiş görüntü gösterilir. O da yoksa uygulama ikonu büyük gösterilir.
  - Panel açılırken anında bir şey gösterilmeli: önce önbellekten, sonra tazelenmiş görüntü.
  - Panel kapalıyken sürekli yakalama yapılmamalı (anti-hedef).
- **Listeden çıkarılacak pencereler:** menü çubuğu öğeleri, normal pencere katmanında olmayanlar, çok küçük ya da görünmez pencereler, Util'in kendi pencereleri. Gizlenmiş (Cmd+H) uygulamaların pencerelerinin dahil edilip edilmeyeceği builder'ın kararı.
- Başka Space'teki bir pencereye geçerken sistemin o Space'e geçmesi kabul edilebilir.

## 8. Clipboard geçmişi

### Davranış (kullanıcı onayladı)

- **Kısayol: Cmd+Shift+V** ile panel açılır.
  - Not: Bazı uygulamalarda Cmd+Shift+V "biçimi eşleştirerek yapıştır" anlamına geliyor. Kullanıcı bu kısayolu kabul etti, uygulamada bu çakışma bilerek göze alınıyor.
- **Kaydedilenler:** metinler ve görseller.
  - Metinlerin biçimi (RTF/HTML) saklanır.
  - Hiçbir öğe "parola" ya da "hassas" diye ayrıca işaretlenmez, hepsi normal geçmişe girer.
- **Hangi pano tipleri saklanır (benim kararım):**
  - Sadece düz metin, RTF, HTML ve görsel (PNG/TIFF) temsilleri saklanır. Uygulamalara özel tipler (Excel hücreleri, Keynote/Figma nesneleri vb.) ve dosya referansları saklanmaz.
  - Yapıştırırken saklanan tüm temsiller birlikte geri yazılır. Bu yüzden Excel hücreleri geçmişten yapıştırıldığında HTML/RTF tablo olarak gelir, Excel'in kendi hücre formatı olarak gelmez.
  - Neden: kopyalama hızlı kalır ve disk şişmez. "Metin ve fotoğraf" isteğini karşılar.
  - Veri modeli ileride yeni tipler eklenebilecek şekilde sürümlü tutulur.
- **Hem metin hem görsel içeren bir kopya** (ör. tarayıcıdan görsel kopyalanınca gelen HTML + görsel):
  - Görüntülenmeye uygun bir metin varsa listede metin öğesi gibi görünür, yoksa görsel öğesi gibi görünür.
  - Hangi durumda olursa olsun, yapıştırırken tüm temsiller birlikte yazılır.
  - Arama sadece düz metin üzerinde yapılır.
  - Shift+Enter sadece düz metni yapıştırır.
  - Tekrar kopyalama kontrolü (dedup) için anahtar: düz metin varsa onun özeti (hash), yoksa görsel verisinin özeti.
- **Panelde gezinme:**
  - Yazmaya başlamak arama yapar.
  - Ok tuşlarıyla gezilir.
  - **Enter:** seçili öğe, panel açılmadan önce aktif olan uygulamaya doğrudan yapıştırılır. Kullanıcının ayrıca Cmd+V yapmasına gerek yoktur.
  - **⌘1–⌘9:** listedeki ilgili öğeyi doğrudan yapıştırır.
    - Numaralar ekranda görünen sırayı takip eder, sabitlenenler de dahil. Kullanıcının seçtiği A taslağında ⌘1 sabitlenmiş öğedeydi.
    - Arama yapılırken numaralar filtrelenmiş sonuçlara göre yeniden verilir.
    - Her satırın yanında kendi numarası yazdığı için kullanıcı neye bastığını görür.
  - **Esc:** panel kapanır.
- **Biçimli / düz yapıştırma:** Varsayılan yapıştırma biçimi korur. Biçimsiz düz metin yapıştırmak için ayrı bir seçenek bulunur: Shift+Enter ve sağ tık menüsü (Shift+Enter benim kararım).
- **Sabitleme:** Sabitlenen öğeler panelin en üstünde ayrı bir bölümde durur ve hiçbir zaman otomatik silinmez.
- **Limit:** son **500 öğe** tutulur, sabitlenenler bu sayıya dahil değil. Limit aşılınca en eski öğeler silinir.
- **Tekrar kopyalama:** Aynı içerik tekrar kopyalanırsa yeni bir kopya oluşmaz, mevcut öğe en üste çıkar.
- **Sağ tık menüsü:** Yapıştır, Düz metin olarak yapıştır, Sabitle / Sabitlemeyi kaldır, Sil.
- **Geçmişi temizle** (menü çubuğundan): onay ister, sabitlenenleri korur (benim kararım).

### Görünüm (kullanıcı A taslağını seçti)

- **Dikey bir liste paneli.** Fare imlecinin yanında açılır ve ekran dışına taşmaz. Konum olarak fare imleci benim kararım; yazı imlecinin konumu kullanılmayacak.
- **En üstte arama kutusu.**
- Ardından **"📌 Sabitlenen"** bölümü, sonra **"Geçmiş"** bölümü gelir.
- **Her satırda:**
  - Kaynak uygulamanın ikonu.
  - Metnin ilk satırı (kısaltılmış). Görsellerde küçük resim ve boyutu (ör. "Ekran görüntüsü · 1440×900").
  - Sağda ⌘1–9 kısayol ipucu.
- Seçili satır mavi vurgulanır.
- Uzun metinler ve görseller için üzerinde durunca ya da seçince daha büyük bir önizleme gösterilebilir. Bu builder'ın kararı, v1 için zorunlu değil.

### Depolama ve güvenlik

- **Konum:** `~/Library/Application Support/Util/`.
- **Diskte şifreli (benim kararım, kullanıcıya söylendi):**
  - Tüm geçmiş (metin ve görseller) AES-GCM ile (CryptoKit) şifrelenir.
  - Anahtar macOS Keychain'de durur.
  - Kullanıcı açısından görünür bir fark yoktur: şifre sorulmaz, kilit yoktur.
- **Veri biçimi** (SQLite, dosyalar vb.) builder'ın kararı.
- **Görsel boyutu:** Görseller orijinal haliyle saklanır, liste için ayrıca küçük resim üretilir. Diskin şişmemesi için tek bir görsel çok büyükse (ör. >25 MB) kaydedilmeyebilir. Eşik builder'ın kararı.
- **Pano takibi:**
  - `NSPasteboard.changeCount` periyodik olarak kontrol edilir (macOS'ta pano değişikliği için bildirim yok). Aralık builder'ın kararı, ~0.5 sn makul.
  - `org.nspasteboard.TransientType` ve `AutoGeneratedType` işaretli içerikler kaydedilmez. Bunlar gizli veri değil, geçici gürültü (benim kararım).
  - `ConcealedType` (şifre yöneticisi işareti) için özel bir işlem yapılmaz. Kullanıcı isteği doğrultusunda bunlar normal metin olarak kaydedilir.
  - Util'in kendi yapıştırma işlemi geçmişte yeni öğe oluşturmamalı. Aynı öğe en üste çıkabilir.

## 9. Builder'a bırakılanlar (özet)

- Proje yapısı (Xcode projesi ya da SwiftPM), bundle id, minimum macOS hedefi (en az 14; kullanıcı 27'de).
- Pencere listeleme ve Space'ler için kullanılacak API'ler, private API kullanımı.
- Önizleme önbellekleme stratejisi ve yenileme zamanlaması.
- Clipboard veri modeli ve depolama biçimi.
- Animasyon detayları (panel açılma/kapanma). Gecikme yaratmamak şartıyla.
- Test stratejisi: en azından MRU sıralaması, clipboard tekrar kopyalama ve limit mantığı, şifreleme/çözme için birim testleri.

## 10. Doğrulama (bitti sayılması için)

- Option+Tab basılı tutulunca panel ~0,1 sn içinde açılıyor. Hızlı Option+Tab'da panel hiç görünmüyor. Tüm pencereler (farklı uygulamaların ve aynı uygulamanın birden çok penceresi, küçültülmüş olanlar, başka Space'tekiler) önizlemeleriyle görünüyor.
- Tab / Shift+Tab / Esc / Option bırakma / fare tıklaması anlatıldığı gibi çalışıyor. Hızlı Option+Tab bir önceki pencereye geçiyor.
- Cmd+Tab ve diğer Option kombinasyonları etkilenmiyor.
- Cmd+Shift+V paneli fare yanında açıyor.
  - Metin ve görsel kopyalar listede görünüyor.
  - Arama, Enter ile yapıştırma, ⌘1–9, Shift+Enter ile düz metin, sabitleme, silme ve geçmişi temizleme çalışıyor.
- Uygulama yeniden başlatılınca geçmiş ve sabitlenenler korunuyor. Diskteki dosyalar düz okunamıyor.
- Uygulama yeniden build edilince izinler tekrar istenmiyor (kalıcı imza).
- Uygulama hiç ağ bağlantısı açmıyor.
- Panel kapalıyken CPU kullanımı boşta seviyesinde kalıyor.
