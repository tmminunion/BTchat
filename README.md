# BTchat — AI Development Chat Workspace

**BTchat** adalah aplikasi Flutter AI Development Chat berdesain modern seperti **Google Gemini** dan **Anthropic Claude** yang terhubung langsung ke:

1. **Google Gemini AI Studio API** (`generativelanguage.googleapis.com/v1beta`)
   - Mendukung model `gemini-2.5-flash`, `gemini-2.5-pro`, `gemini-2.0-flash`, atau custom model ID.
   - Mendukung multi-turn conversation history, `systemInstruction`, pengaturan `temperature`, dan `maxOutputTokens`.
2. **Microsoft Copilot Studio** (Direct Line REST API v3 & Custom Webhook/Token Endpoint)
   - Mendukung **Direct Line Secret / Token** (`https://directline.botframework.com/v3/directline`) dengan manajemen sesi konversasi otomatis & polling respons bot.
   - Mendukung **Copilot Studio Token Endpoint / Custom Webhook URL** untuk integrasi agent kustom Bungtemin / Enterprise.

## Fitur Utama
- **Dual Visual Persona (Gemini Mode & Claude Mode)**:
  - **Gemini Dark Nebula**: Aksen *blue-violet sparkle gradient*, pill composer mengambang, dan greeting dinamis.
  - **Claude Warm Studio**: Aksen *terracotta/amber hangat*, tipografi bersih nyaman dibaca untuk review kode panjang.
- **Rich Markdown & Code Artifact Renderer**:
  - Blok kode dilengkapi label bahasa, nomor baris opsional, tombol **Copy Code** 1-klik, dan tampilan *Artifact Card* ala Claude.
- **Multi-Session & Prompt Library**:
  - Riwayat percakapan tersimpan otomatis di perangkat (`SharedPreferences`), bisa buat sesi baru, ganti judul, ekspor percakapan, dan pilih template prompt cepat (Code Review, Debug Error, Refactor, SQL/API Architect, Copilot Flow).
- **CI/CD GitHub Actions → Google Drive & Telegram**:
  - Setiap push ke `main` otomatis mem-build signed Release APK, meng-upload ke Google Drive (via NUDB Proxy), dan mengirimkan file/link APK langsung ke Telegram.
