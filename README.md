# Phase 2 Flutter patient + physiotherapist app

Aplikasi Android/iOS/Web Flutter dengan dua peran:
1. **Pasien**: Menjalankan pose estimation dan scoring secara offline on-device setelah mengunduh recipe via kode latihan (share code) atau import JSON.
2. **Physiotherapist**: Merekam demonstrasi atau memilih video, mengirimnya ke Motorix PhysioAI Pipeline API (Google Cloud Run / lokal), memantau progress ekstraksi pose, meninjau hasil & preview video skeleton, menyesuaikan parameter recipe, memublikasikan recipe, dan membagikan share code 8-karakter ke pasien.

## Cara Menjalankan

```bash
cd apps/phase2_flutter
flutter pub get
flutter test
flutter run
```

### Konfigurasi Endpoint API Backend

Aplikasi secara default terhubung ke **Google Cloud Run API**:
- **Default Production**: `https://motorix-pipeline-api-1031020302062.asia-southeast1.run.app`

Anda juga dapat mengatur URL saat build/run atau mengubahnya langsung di dalam aplikasi melalui tombol **Pengaturan Server API**:

```bash
# Menghubungkan ke server lokal
flutter run --dart-define=PIPELINE_API_BASE_URL=http://127.0.0.1:8000

# Menghubungkan ke Android Emulator
flutter run --dart-define=PIPELINE_API_BASE_URL=http://10.0.2.2:8000

# Menghubungkan ke IP LAN
flutter run --dart-define=PIPELINE_API_BASE_URL=http://192.168.1.50:8000
```

## Fitur Integrasi API

- **Health & Model Status**: Memeriksa kesiapan engine MediaPipe (`pose_heavy.task`, `pose_lite.task`, `hand.task`) dan tool `ffmpeg`.
- **Pembuatan Job**: Mengunggah video demonstrasi dokter via `POST /v1/jobs` (multipart).
- **Polling Status**: Memantau tahapan ekstraksi biomekanik secara berkala via `GET /v1/jobs/{job_id}`.
- **Tinjauan & Streaming Preview**: Memutar video skeleton overlay (`GET /v1/jobs/{job_id}/preview`) dan repetisi panduan (`GET /v1/jobs/{job_id}/guide`).
- **Modifikasi Parameter (Patch)**: Mengubah batas repetisi, sets, istirahat, serta instruksi suara/keamanan via `PATCH /v1/jobs/{job_id}/recipe`.
- **Publikasi & Share Code**: Memublikasikan recipe via `POST /v1/jobs/{job_id}/publish` dan memperoleh 8-digit kode latihan (contoh: `MX-E44D3752`).
- **Pengambilan Recipe Pasien**: Pasien memasukkan kode share untuk mengunduh recipe JSON via `GET /v1/recipes/code/{share_code}`. Sesi latihan selanjutnya berjalan 100% on-device.

## Verifikasi Build & Test

```bash
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --simulator
```
