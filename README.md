# Util

Menü çubuğunda çalışan küçük bir macOS uygulaması. İki işi var:

- **Alt-Tab (Switcher):** `Option+Tab` ile pencere önizlemeli geçiş paneli. `Cmd+Tab`'e dokunmaz.
- **Pano geçmişi (Clipboard):** `Cmd+Shift+V` ile kopyaladığın şeylerin aranabilir, şifreli geçmişi. Normal `Cmd+C` / `Cmd+V` aynen çalışır.

Ağ bağlantısı, analytics veya otomatik güncelleme yok. Minimum macOS 14.

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
make run    # derle, imzala, /Applications/Util.app'e kopyala ve aç
```

`make app` yalnızca `build/Util.app` üretir (kurmaz). İlk imzalamada Keychain, `codesign`'ın anahtarı kullanması için şifreni sorabilir; **"Her Zaman İzin Ver"** seçersen bir daha sormaz.

## İzinler

Uygulama ilk açılışta "Util İzinleri" penceresini gösterir:

- **Erişilebilirlik:** `Option+Tab` ve `Cmd+Shift+V` kısayollarını dinlemek, pencereleri öne getirmek ve seçilen öğeyi yapıştırmak için.
- **Ekran Kaydı:** Alt-Tab panelinde pencere önizlemelerini göstermek için. Görüntü kaydedilmez, panel kapalıyken ekran görüntüsü alınmaz.
- **Pano Erişimi** (macOS 15.4 ve sonrası): kopyaladığın metin ve görselleri geçmişe kaydetmek için. macOS, programla pano okumayı varsayılan olarak her seferinde sorar; sorduğunda **"Her Zaman İzin Ver"** seç. Sonradan Sistem Ayarları → Gizlilik ve Güvenlik → Pano bölümünden değiştirebilirsin ("Sistem Ayarları'nı aç" düğmesi oraya gider). İzin "Her Zaman İzin Ver" olmadıkça pencerede "Verilmedi" görünür. Daha eski macOS'ta bu satır görünmez.

Ekran Kaydı verildikten sonra macOS uygulamayı yeniden başlatmanı isteyebilir (pencerede "Util'i yeniden başlat" düğmesi var). Bu izinler hiçbir zaman dışarı veri göndermek için kullanılmaz.

## Veri nerede, nasıl şifreli

- Konum: `~/Library/Application Support/Util/` (klasör 0700, dosyalar 0600).
- Pano geçmişi (`index`, `blob-*` ve küçük resim dosyaları) **AES-GCM** (CryptoKit) ile şifrelenip yazılır; diske düz metin gitmez.
- Anahtar (256 bit, rastgele) Keychain'de durur: service `com.yumoteknoloji.util`, account `clipboard-key`. Bu Mac'e özeldir, yedekle başka makineye taşınmaz.
- Limitler: 500 sabitlenmemiş öğe (sabitlenenler hariç), tek kopya en fazla 25 MB.

Geçmişi tamamen sıfırlamak için uygulamayı kapatıp klasörü sil; Keychain kaydını silmek de eski verinin açılmasını imkânsız kılar.

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
- `Sources/Util`: uygulama kabuğu (AppDelegate, menü, izin penceresi)
- `scripts/build-app.sh`: `.app` paketini oluşturur ve imzalar
