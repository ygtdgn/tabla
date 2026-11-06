# Tabla

Menü çubuğunda çalışan küçük bir macOS uygulaması. İki işi var:

- **Alt-Tab (Switcher):** `Option+Tab` ile pencere önizlemeli geçiş paneli. `Cmd+Tab`'e dokunmaz.
- **Pano geçmişi (Clipboard):** `Cmd+Shift+V` ile kopyaladığın şeylerin aranabilir, şifreli geçmişi. Normal `Cmd+C` / `Cmd+V` aynen çalışır.

Ağ bağlantısı, analytics veya otomatik güncelleme yok. Minimum macOS 14.

Kodda ve iç kimliklerde eski adı **Util** geçer (SwiftPM hedefleri, bundle id `com.yumoteknoloji.util`, veri klasörü). Bunlar bilerek değiştirilmedi: bundle id değişirse macOS verilen izinleri unutur ve pano geçmişi eski klasörde kalır.

## Gereksinimler

1. **Xcode** (komut satırı araçlarıyla birlikte).
2. **Yumo Teknoloji "Apple Development" sertifikası.** Xcode → Settings → Accounts → hesabını seç → Manage Certificates ile ekle. Ad-hoc imza kullanılmaz; böylece izinler her derlemede sıfırlanmaz.
3. **`signing.env` dosyası.** `signing.env.example` dosyasını `signing.env` olarak kopyala ve içindeki `UTIL_SIGN_IDENTITY` değerine sertifikanın SHA-1 değerini yaz:

   ```sh
   cp signing.env.example signing.env
   security find-identity -v -p codesigning   # Yumo geçen satırdaki SHA-1'i al
   ```

   `signing.env` git'e girmez.

## Komutlar

```sh
make test   # tüm testler (swift test)
make run    # derle, imzala, /Applications/Tabla.app'e kopyala ve aç
make icon   # Resources/AppIcon.svg değişince AppIcon.icns'i yeniden üret
```

`make app` yalnızca `build/Tabla.app` üretir (kurmaz). İlk imzalamada Keychain, `codesign`'ın anahtarı kullanması için şifreni sorabilir; **"Her Zaman İzin Ver"** seçersen bir daha sormaz.

## İzinler

Uygulama ilk açılışta "Tabla İzinleri" penceresini gösterir:

- **Erişilebilirlik:** `Option+Tab` kısayolunu yakalamak, pencereleri öne getirmek ve seçilen öğeyi yapıştırmak (Tabla'nın gönderdiği `Cmd+V`) için. `Cmd+Shift+V` sistem kısayolu olarak kayıtlıdır ve bu izin olmadan da paneli açar; izin yoksa seçilen öğe yalnızca panoya kopyalanır.
- **Ekran Kaydı:** Alt-Tab panelinde pencere önizlemelerini göstermek için. Görüntü kaydedilmez, panel kapalıyken ekran görüntüsü alınmaz.
- **Pano Erişimi** (macOS 15.4 ve sonrası): kopyaladığın metin ve görselleri geçmişe kaydetmek için. macOS, programla pano okumayı varsayılan olarak her seferinde sorar; sorduğunda **"Her Zaman İzin Ver"** seç. Sonradan Sistem Ayarları → Gizlilik ve Güvenlik → **Diğer Uygulamalardan Yapıştır** bölümünden değiştirebilirsin ("Sistem Ayarları'nı aç" düğmesi oraya gider). İzin "Her Zaman İzin Ver" olmadıkça pencerede "Verilmedi" görünür. Daha eski macOS'ta bu satır görünmez.

Ekran Kaydı verildikten sonra macOS uygulamayı yeniden başlatmanı isteyebilir (pencerede "Tabla'yı yeniden başlat" düğmesi var). Bu izinler hiçbir zaman dışarı veri göndermek için kullanılmaz.

## Veri nerede, nasıl şifreli

- Konum: `~/Library/Application Support/Util/` (klasör 0700, dosyalar 0600).
- Pano geçmişi (`index`, `blob-*` ve küçük resim dosyaları) **AES-GCM** (CryptoKit) ile şifrelenip yazılır; diske düz metin gitmez.
- Anahtar (256 bit, rastgele) giriş Anahtar Zinciri'nde (login keychain) durur: service `com.yumoteknoloji.util`, account `clipboard-key`.
- Anahtar Zinciri anahtarı veremezse (ör. erişim reddedildi) geçmiş silinmez: o oturumda kopyalar yalnızca bellekte tutulur ve panel "Geçmiş şu an açılamıyor…" der. Anahtar yeniden alınınca bellekteki kopyalar geçmişe katılır. Okunamayan bir `index` silinmez, `index.unreadable-<zaman>` adıyla kenara alınır.
- Limitler: 500 sabitlenmemiş öğe (sabitlenenler hariç); bir kopyanın her temsili (düz metin, RTF, HTML, görsel) en fazla 25 MB, aşan temsil atlanır. Yalnız TIFF olarak gelen görseller PNG'ye çevrilip saklanır.

Geçmişi tamamen sıfırlamak için uygulamayı kapatıp klasörü sil; Keychain kaydını silmek de eski verinin açılmasını imkânsız kılar.

## Bilinen sınırlamalar

- Parola alanı ya da Terminal'in "Güvenli Klavye Girişi" etkinken (macOS Secure Input) `Option+Tab` çalışmaz; macOS bu sırada klavye olaylarını uygulamalara vermez.
- macOS, Ekran Kaydı iznini belirli aralıklarla yeniden sorabilir.

## Kısayollar nerede tanımlı

`Sources/UtilCore/Shortcuts.swift`: Option+Tab (Switcher), Cmd+Shift+V (Clipboard) ve panelin gecikmesi (0,1 sn) tek yerde. Değiştirmek için Claude'dan bu dosyayı düzenlemesini iste.

## Yeni özellik ekleme

Her özellik ayrı bir modül:

1. `Sources/<X>Feature/` klasörü aç ve içinde `Feature` protokolünü (`Sources/UtilCore/Feature.swift`) uygulayan bir sınıf yaz: `menuItems()`, `apply(permissions:)`, `shutdown()`.
2. `Package.swift`: `.target(name: "<X>Feature", dependencies: ["UtilCore"])` ekle ve `Util` executable hedefinin `dependencies` listesine `"<X>Feature"` yaz (isteğe bağlı test hedefi de ekle).
3. `Sources/Util/AppDelegate.swift`: `features` dizisine bir satır ekle, örn. `<X>Feature()`.

Menü öğeleri ve izin değişimlerini `AppDelegate` otomatik dağıtır; ek bağlantı gerekmez.

## Yapı

- `Sources/UtilCore`: ortak parçalar (Feature, izinler, kısayollar, şifreleme, depolama)
- `Sources/ClipboardFeature`, `Sources/SwitcherFeature`: iki özellik
- `Sources/Util`: uygulama kabuğu (AppDelegate, menü, menü çubuğu simgesi, izin penceresi)
- `Resources/AppIcon.svg`: uygulama simgesinin kaynağı; `AppIcon.icns` bundan `make icon` ile üretilir
- `scripts/build-app.sh`: `Tabla.app` paketini oluşturur ve imzalar
