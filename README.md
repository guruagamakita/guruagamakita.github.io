# Website Guru Agama Katolik
Website pembelajaran untuk mendukung kegiatan belajar dan berbagi materi Pendidikan Agama Katolik. Situs ini menyediakan materi pengenalan, informasi artikel, galeri, video pembelajaran, serta tautan untuk menghubungi pengelola.

## Konten
- **Materi belajar:** Pengenalan Pendidikan Agama Katolik, tujuan pembelajaran, dan refleksi.
- **Artikel:** Bagian untuk artikel seputar Pendidikan Agama Katolik.
- **Galeri:** Bagian dokumentasi foto kegiatan.
- **Video:** Video tentang kesetiaan dalam perkawinan, pembaptisan Yesus, dan tugas pembuatan video pembelajaran.
- **Kontak:** Formulir kontak yang tersedia pada halaman utama.

## Teknologi
- HTML
- Bootstrap 5.3.2 (CSS dan JavaScript melalui jsDelivr CDN)

## Menjalankan secara lokal
Klon repositori, lalu buka `index.html` di browser. Tidak diperlukan proses build.

Halaman materi juga dapat dibuka langsung melalui `materi1.html`.

## Portal Moodle
Portal `moodle/` membaca `moodle/config.json` melalui HTTP; gunakan server lokal
untuk mengujinya, bukan membuka file langsung. Sebelum memakai skrip, commit
file portal dan skrip ke repositori, siapkan Moodle di `/var/www/html/moodle`,
serta instal `cloudflared`, `python3`, `sudo`, dan Git di WSL. Git harus sudah
dikonfigurasi untuk push ke upstream branch aktif.

Di WSL, jalankan `chmod +x toggle-moodle.sh` sekali, kemudian jalankan
`./toggle-moodle.sh online` atau `./toggle-moodle.sh offline`. Skrip mengubah
`$CFG->wwwroot`, meng-commit hanya konfigurasi portal, lalu melakukan push.
Pastikan konfigurasi portal tidak memiliki perubahan lokal atau staged sebelum
menjalankan skrip. Jika push gagal, perbaiki masalah Git lalu jalankan
`git push` kembali. Tunnel harus tetap berjalan di WSL selama mode online;
skrip offline hanya menghentikan tunnel yang dimulai oleh skrip ini.

Tautan lokal bawaan memakai `localhost`, yaitu komputer pengguna yang membuka
tautan, bukan otomatis komputer server. Untuk akses dari komputer lain di lab,
sesuaikan `local_url` dengan alamat server yang dapat dijangkau di jaringan.

## Situs
[https://guruagamakita.github.io](https://guruagamakita.github.io)

## Catatan
Bagian artikel dan galeri di halaman utama saat ini masih berupa placeholder. Formulir kontak juga belum dikonfigurasi untuk mengirim pesan.
