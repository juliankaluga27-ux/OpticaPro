# Optica Pro — szkielet aplikacji iOS

Natywny projekt SwiftUI / AVFoundation dla iPhone’a. Otwórz `OpticaPro.xcodeproj` w Xcode, wybierz zespół podpisywania w ustawieniach targetu i uruchom na fizycznym iPhonie. Symulator nie udostępnia pełnej kamery.

## Budowanie IPA przez GitHub Actions

W repozytorium GitHub umieść zawartość tego folderu na głównej gałęzi (`main` albo `master`). Workflow `.github/workflows/build-unsigned-ipa.yml` uruchomi się po wypchnięciu zmian w projekcie albo ręcznie w zakładce **Actions → Build unsigned iOS IPA → Run workflow**. Po zakończeniu pobierz artefakt **OpticaPro-unsigned-IPA** z uruchomionego workflow. Artefakty są przechowywane przez 14 dni.

Workflow buduje aplikację na runnerze macOS bez certyfikatu Apple i pakuje ją jako `OpticaPro-unsigned.ipa`. Plik jest niepodpisany, więc przed instalacją na iPhonie trzeba podpisać go własnym certyfikatem w używanym narzędziu do sideloadingu. Do wersji podpisanej kontem Apple Developer potrzebny jest osobny workflow z certyfikatem i profilem provisioningowym przechowywanymi w GitHub Secrets.

## W tej wersji

- Podgląd tylnej i przedniej kamery, zdjęcia i nagrywanie filmu z dźwiękiem.
- Zoom, błysk, latarka, samowyzwalacz, proporcje kadru, siatka kadrowania.
- Ręczna kompensacja EV, ISO i czas migawki; wybór ostrości i balans bieli.
- Zmniejszanie zdjęć do wybranej liczby megapikseli (od 0,3 MP) oraz wybór maksymalnej rozdzielczości dostępnej dla aktywnego formatu kamery.
- Opcje eksportu: JPEG, HEIC, HEIF, PNG, TIFF, GIF, BMP, JPEG 2000, WebP i RAW/DNG. Możliwość kodowania poszczególnych formatów zależy od obsługi ImageIO w danej wersji iOS; w razie braku kodera aplikacja zapisuje JPEG i pokazuje komunikat. RAW wymaga dostępnego trybu RAW w kamerze.
- Profile wideo 720p, 1080p, 4K i maksimum, wybór klatkażu 24–240 kl./s, H.264/HEVC i MOV/MP4, o ile aktywna kamera i iOS je udostępniają.
- Tryb slow‑motion nagrywa z wyższą liczbą klatek, a potem eksportuje klip ze zwolnionym odtwarzaniem. Timelapse przyspiesza gotowy klip według wybranego mnożnika.
- Ustawienia interfejsu obejmują histogram, zebry, poziomicę i focus peaking.

## Ograniczenia prototypu

To jest wersja 0.1 źródeł. W tym środowisku nie da się lokalnie zbudować aplikacji iOS; do tego służy dołączony workflow GitHub Actions na runnerze macOS. Workflow tworzy IPA bez podpisu, a nie gotową do instalacji aplikację.

Możliwości aparatu Apple ogranicza do formatów aktywnej kamery. Wybrana niska liczba MP jest uzyskiwana przez zmniejszenie zdjęcia. Wyższe MP, liczba klatek i kodeki są dostępne tylko wtedy, gdy konkretny iPhone je obsługuje. Wybór rozdzielczości filmu przełącza preset sesji, a wybór liczby klatek dobiera zgodny format kamery.

Histogram, zebra, poziomica i focus peaking mają w tym szkielecie warstwę interfejsu demonstracyjną; nie analizują jeszcze na żywo pikseli obrazu ani pochylenia telefonu. Balans bieli, ostrość ręczna i układ niektórych nakładek wymagają dalszego dopracowania. Timelapse jest efektem eksportu przyspieszonego filmu, a slow‑motion eksportuje nowy klip; oba procesy zużywają dodatkowy czas i miejsce. Przed dystrybucją należy sprawdzić kompilację, uprawnienia, formaty i działanie na docelowych iPhone’ach.
