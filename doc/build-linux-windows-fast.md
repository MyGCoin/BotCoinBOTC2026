Schneller Linux+Windows Build (Qt, CLI, TX, Daemon)
=====================================================

Dieses Repository enthält jetzt ein Build-Skript, mit dem du reproduzierbar beide Targets bauen kannst:

- Linux (`botcoind`, `botcoin-cli`, `botcoin-tx`, `botcoin-qt`)
- Windows (`botcoind.exe`, `botcoin-cli.exe`, `botcoin-tx.exe`, `botcoin-qt.exe`)

Dateien:

- `contrib/crossbuild/build-matrix.sh`
- `contrib/crossbuild/targets.env`

Voraussetzungen auf Ubuntu/Debian
---------------------------------

```bash
sudo apt update
sudo apt install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils curl git \
  g++-mingw-w64-x86-64
```

> Hinweis: Das Skript nutzt das `depends`-System und baut dadurch Linux und Windows konsistent aus einer Linux-Umgebung.

Schnellstart
------------

1) Defaults anpassen (optional):

```bash
nano contrib/crossbuild/targets.env
```

2) Beide Plattformen bauen:

```bash
./contrib/crossbuild/build-matrix.sh all
```

3) Nur Linux oder nur Windows bauen:

```bash
./contrib/crossbuild/build-matrix.sh linux
./contrib/crossbuild/build-matrix.sh windows
```

Artefakte liegen danach unter:

- `out/artifacts/linux/`
- `out/artifacts/windows/`

Je Build erzeugt das Skript:

- installierten Baum unter `out/artifacts/<target>/root/`
- gepacktes Archiv (`.tar.gz` bzw. `.zip`) zum direkten Austauschen auf deinem Server

Inkremmenteller Workflow für Code-Änderungen
-------------------------------------------

Beim ersten Lauf dauert `depends` am längsten. Danach kannst du bei Code-Änderungen schnell neu bauen:

```bash
./contrib/crossbuild/build-matrix.sh all --skip-depends
```

Damit nutzt du die vorhandenen Dependencies wieder und baust nur dein Projekt neu.

Nützliche Optionen
------------------

```bash
./contrib/crossbuild/build-matrix.sh --help
```

Wichtige Flags:

- `--skip-depends` → überspringt Dependency-Build (schneller bei normalen Code-Änderungen)
- `--skip-package` → kein Archiv erstellen

Tipps für Server-Austausch
--------------------------

1. Build auf Build-Host ausführen.
2. Archiv aus `out/artifacts/<target>/` auf den Zielserver kopieren.
3. Vorher altes Binary-Set sichern.
4. Neues Archiv entpacken und Binärdateien austauschen.
5. Dienst neu starten und Version prüfen (`botcoind --version`).

So hast du einen wiederholbaren Prozess mit minimalem Aufwand pro Änderung.
