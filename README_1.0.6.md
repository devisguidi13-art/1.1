# DVS Music 1.0.6 — Music First (iPhone)

Questa versione parte dai sorgenti **1.0.5 forniti dall'utente**. La grafica SwiftUI, la libreria, i preferiti, le playlist, la radio intelligente, i generi, le classifiche e il player `AVQueuePlayer` sono conservati.

## Cosa cambia

1. `YouTubeMusicCatalog.swift` aggiunge una **ricerca di brani e metadati YouTube Music**. Analizza i risultati musicali del web client, estrae titolo, artista, durata, copertina e **video ID**, e scarta risultati senza un ID utilizzabile. Questo è un adattamento Swift originale del concetto *music-first* studiato in SimpMusic; **non incorpora né copia il suo codice Kotlin GPL-3.0**.
2. `MultiSourceCatalog.search` cerca in parallelo **YouTube Music**, **YouTube/Invidious** e **Audius**. Vengono privilegiate corrispondenze musicali pertinenti e indizi di origine musicale (Topic/VEVO); il nome YouTube Music non è una certificazione di account ufficiale.
3. Se un brano non è riproducibile, il catalogo cerca **prima un altro video ID della stessa registrazione** tramite i due motori di ricerca YouTube, controllando artista, titolo, durata e versioni (remix/live/slowed ecc.). Solo dopo prova Audius, quando esiste una corrispondenza abbastanza precisa.
4. I brani YouTube Music usano **lo stesso player YouTubeKit** già presente: non c'è un player esterno. Audius conserva il proprio endpoint di streaming tramite API.
5. I dati precedenti restano compatibili: il nuovo campo facoltativo `catalogOrigin` non altera gli ID delle tracce YouTube, le playlist o la cronologia precedenti.
6. Il workflow GitHub Actions crea l'IPA **1.0.6** e include test offline per ricerca/parsing, disambiguazione delle versioni e regressioni delle versioni precedenti.

## Limiti e trasparenza

- **SimpMusic non viene compilato su iPhone.** È una app principalmente Kotlin/Android/Desktop. Questa release implementa un motore Swift autonomo che riprende la sua strategia di ricerca. Non abbiamo copiato moduli SimpMusic.
- YouTube Music e YouTube **non sono due fornitori audio indipendenti**. Condividono la stessa infrastruttura. Questo migliora l'individuazione di brani mainstream e possibili alternative video, ma non crea un catalogo commerciale con licenza aggiuntiva.
- La ricerca YouTube Music usa un'interfaccia **web non ufficiale**. La configurazione viene letta dalla pagina pubblica attuale, senza credenziali o chiavi hardcoded. Può essere modificata/bloccata: in quel caso il motore torna ai risultati YouTube/Invidious e Audius.
- Il precedente risolutore YouTubeKit usa interfacce non ufficiali; non è garantito che ogni brano riproduca su iPhone, né che il background playback sia ammesso dalle condizioni YouTube. Le API ufficiali YouTube vietano separazione audio/video e riproduzione tramite player nascosti. Valutare i termini prima della distribuzione.
- **Verificati:** compilazione e test dei moduli Foundation su Linux, parsing Swift e regressioni offline 0.8–1.0.5. **Non verificati:** build Xcode/iOS e API/riproduzione reali; richiedono GitHub Actions e prova sul dispositivo.

## Aggiornamento manuale sul repository GitHub

1. Estrai lo ZIP e copia **tutti i file** nel repository mantenendo la struttura, soprattutto `native-ios/DVSMusic/`, `.github/workflows/crea-ipa.yml` e `tests/`. Conferma l'overwrite dei file esistenti.
2. Fai commit delle modifiche.
3. Nella scheda **Actions** apri **DVS Music 1.0.6 - Music First iPhone**, scegli **Run workflow**.
4. A build verde scarica l'artifact **DVS_Music_106_iPhone_IPA_non_firmato**; poi firma e installa l'IPA con la procedura già usata per la 1.0.5.

### Cosa provare sull'iPhone

- Cercare un brano commerciale italiano e uno internazionale, controllando l'etichetta **YouTube Music**, la durata e la copertina.
- Selezionare il brano, verificare che riproduca e che il passaggio alla traccia successiva non interrompa la coda.
- Controllare la stessa canzone in due versioni (originale, remix): il fallback non deve sostituire un remix all'originale.
- Verificare che preferiti e playlist salvati nella 1.0.5 siano ancora presenti.

Fonte di ispirazione architetturale: https://github.com/maxrave-dev/SimpMusic (GPL-3.0). Documentazione dei limiti YouTube: https://developers.google.com/youtube/terms/developer-policies/.


## 1.0.7 — Recommendation Engine refinement (2026-11-22)

- Artist taste affinity aggregates plays/listening time/favorites across artist identity, not only exact track IDs.
- Stronger genre/style matching and cross-style penalties; metadata remains a cold-start hint (no fake audio analysis).
- Recently played tracks receive a cooldown (12 hours / 3 days / 7 days tiers).
- Repeated skips penalize tracks and artist affinity; favorites gently boost related artist candidates.
- Recommendation results diversify the top of the list (artist cap, then fill remaining results).
- Added offline regression test `tests/recommendation-v107.swift` and wired it into the IPA workflow.

Verification in this working session: native Swift core, 0.8 library, intelligence, official covers, radio, multi-source, charts, new 1.0.7 test, plist validation, all Swift parse, and queue/YouTube TypeScript tests passed. Full Xcode/iOS build is not available in this Linux environment.


## 1.0.8 — Adaptive Radio (2026-11-22)

- Learns broader style/neighborhood affinity from listening time, repeated plays, skips, and favorites.
- Transfers taste between artists in the same known neighborhood; artist-level preference alone is no longer the only memory signal.
- Related-artist discovery prioritizes personally enjoyed artists and downranks skip-heavy artists; unknown styles are not incorrectly grouped together.
- Added regression test proving style-level preference transfers to another artist.
- The source track remains the musical anchor; learned preference is bounded and cannot fully override style relevance.

Verification: adaptive-radio regression test and Swift syntax parsing passed. Full Xcode/iOS build is not available in this Linux environment.


## 1.0.9 — Fast Start / Queue Warm-up (2026-11-22)

- First-track resolution remains the priority: upcoming tracks are **not** resolved in parallel with the selected song, avoiding bandwidth competition on Play.
- Once playback starts, the next four tracks are stream-resolved in a background warm-up with a maximum of two concurrent requests.
- The stream URL cache lifetime is extended to 10 minutes (temporary URLs remain memory-only).
- Queue additions are warmed before queue-item preparation, reducing transition gaps.
- AVPlayer uses a shorter forward buffer target (1 second) and `automaticallyWaitsToMinimizeStalling = false` to favor responsiveness. This may trade some resilience for faster start on unstable connections; prefetching is intended to offset next-track stalls.
- GitHub Actions workflow/artifact label updated to 1.0.9.

Verification for this optimization: all Swift sources parse, TypeScript queue and YouTube tests pass. A real playback timing test and IPA build still require the iPhone/GitHub macOS runner.


## 1.1.0 — Adaptive Intelligence (2026-11-22)

- Added `DVSIntelligence.swift`, a lightweight on-device preference model that scores candidates from favorites, listening time, play counts, skip signals, and session style.
- Skip feedback now records how much of the song was heard; early skips weigh more than near-end skips. The bounded local skip-event history is persisted with backward-compatible optional decoding.
- Recent listening session (3-hour window) gives a temporary style nudge, separate from longer-term taste.
- Expanded artist neighborhoods with rage, drill, melodic trap, alternative hip-hop, and cloud rap cold-start clusters.
- Wired the profile into recommendation ranking and Smart Shuffle; player, catalog, UI, and existing storage formats remain compatible.
- No cloud AI/API, subscription, audio analysis, or telemetry: all learning is local.
- Added an offline regression test for positive preference learning, skip timing, and session adaptation.

Verification in this work session: new Intelligence 1.1 test passed; Swift syntax checks passed. Full Xcode IPA build remains unavailable in Linux.
