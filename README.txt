OFFLINEKIT - QUICK INSTRUCTIONS
================================

WHAT IT DOES
-------------
OfflineKit downloads and organizes the files needed to keep your AI,
development, automation and documentation tools usable when the Internet
is unstable or unavailable.

Before starting:
1. Run OfflineKit_Downloader_v2_STREAMING.bat
2. Choose the storage location.
3. Review the package list.
4. Confirm with Y to start.

MAIN FILES / APPS
-----------------
- Ollama
- Python
- Node.js / npm
- Docker Desktop
- Git for Windows
- Wireshark
- WireGuard
- SQLite
- Kiwix
- llama.cpp
- Open WebUI
- OpenCode
- Continue VSIX
- yt-dlp
- Local AI models: Qwen3, DeepSeek-R1, Gemma 3, BGE-M3
- Docker images: n8n, Open WebUI, Forgejo, PostgreSQL, Redis

OFFLINE STORAGE
----------------
The program creates an organized OfflineKit folder with separate areas for:
AI/models, n8n, development, documentation, Obsidian, security tools,
Docker images, media/courses and recovery files.

.PART FILES
-----------
A file ending in .part means the download is incomplete.
DO NOT delete it if you want to resume the download.
Run the downloader again and it will try to continue from the partial file.
When the download finishes, .part is renamed to the final file name.

ERRORS / FAILED DOWNLOADS
--------------------------
If a download fails, check:
_meta\FAILED_ITEMS.txt

The program also keeps:
_meta\offlinekit.log              -> download log
_meta\DEFERRED_RUNTIME_ITEMS.txt -> items waiting for a runtime
_meta\SHA256_MANIFEST.txt        -> file checksums

If a download fails because GitHub, a CDN, or another source is blocked,
use a trusted filter/VPN connection and retry the same item manually if needed.
Do not use unknown mirror files when an official source is available.

RUNTIME-DEPENDENT ITEMS
------------------------
Some items are prepared by helper BAT files after the runtime is installed:
- Ollama models
- Docker images
- Python offline wheelhouse
- npm offline cache
- n8n backup

SHA-256 VERIFICATION
---------------------
Use OfflineKit_SHA256_Verifier.bat to verify downloaded files against a
SHA-256 manifest. A matching hash means the local file matches the expected
reference hash.

IMPORTANT
---------
OfflineKit is a download/archive tool. It does NOT silently install software.
Always review the package list and the generated failure log after a run.
