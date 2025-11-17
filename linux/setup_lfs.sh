#!/usr/bin/env bash
set -euo pipefail

echo "=== Git LFS: Initialisierung ==="
git lfs install --local

echo "=== Git LFS: Prüfe, ob LFS installiert wurde ==="
if ! git lfs version >/dev/null 2>&1; then
    echo "❌ Git LFS ist nicht installiert oder nicht verfügbar."
    exit 1
fi

echo "=== Git LFS: Hole alle LFS-Dateien für den aktuellen Checkout ==="
git lfs pull || {
    echo "❌ git lfs pull ist fehlgeschlagen."
    exit 1
}

echo "=== Git LFS: Ersetze Pointer durch echte Dateien ==="
git lfs checkout || {
    echo "❌ git lfs checkout ist fehlgeschlagen."
    exit 1
}

echo "=== Git LFS: Konsistenzcheck ==="
git lfs fsck || {
    echo "❌ Git LFS Integritätsprüfung fehlgeschlagen."
    exit 1
}

echo "=== Git LFS: Liste der LFS-Dateien ==="
git lfs ls-files || true   # nur informativ, kein Abbruch

echo "✔️ Git LFS Dateien erfolgreich geladen."
