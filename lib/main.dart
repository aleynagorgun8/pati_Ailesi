import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// Gerekli sayfaların içe aktarılması
import 'ozellikler/kimlik_dogrulama/ekranlar/kayit_paneli.dart';
import 'package:pati_ailesi/cekirdek/navigasyon/ana_navigasyon_paneli.dart';

// Uygulamanın çalışmaya başladığı ana fonksiyon
Future<void> main() async {
  // Supabase gibi asenkron işlemler yapmadan önce
  // Flutter motorunun (widget tree) hazır olduğundan emin oluyoruz.
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ DÜZELTME: Türkçe takvim formatını uygulamaya tanıtıyoruz.
  // Bu kod sayesinde Anı Köşesi veya diğer sayfalarda tarihleri
  // Türkçe ay isimleriyle hatasız bir şekilde gösterebileceğiz.
  await initializeDateFormatting('tr_TR', null);

  // Supabase veritabanımız ile bağlantıyı kuruyoruz
  await Supabase.initialize(
    url: 'https://ridvmudmahymxkgikguk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpZHZtdWRtYWh5bXhrZ2lrZ3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzMjE5NzksImV4cCI6MjA5ODg5Nzk3OX0.s9DWO_IuXJcPLOW-mAAYfmE5OsnDuB_RvSNxJpJUt_A',
  );

  // Bağlantı başarılı olduktan sonra uygulamamızı başlatıyoruz
  runApp(const PatiAilesiUygulamasi());
}

// Uygulamamızın temel yapısını (Material Design) kurduğumuz sınıf
class PatiAilesiUygulamasi extends StatelessWidget {
  const PatiAilesiUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase üzerinden aktif bir oturum (giriş yapmış kullanıcı) var mı kontrol ediyoruz
    final aktifOturum = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Pati Ailesi',
      debugShowCheckedModeBanner: false, // Sağ üstteki kırmızı "DEBUG" şeridini kaldırır
      theme: ThemeData(
        // Uygulamanın ana renk paletini belirliyoruz
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true, // Modern Flutter tasarım dilini aktif ediyoruz
      ),
      // AKILLI YÖNLENDİRME:
      // Eğer oturum varsa doğrudan Navbar'ın olduğu kapsayıcıya, yoksa kimlik doğrulama paneline yönlendiriyoruz.
      home: aktifOturum != null ? const AnaNavigasyonPaneli() : const KimlikDogrulamaPaneli(),
    );
  }
}

// Bağlantıyı test etmek için hazırladığımız geçici ilk sayfa (Artık yönlendirmeyi akıllı yaptığımız için burası yedek kalabilir)
class BaslangicEkrani extends StatelessWidget {
  const BaslangicEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pati Ailesi'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Supabase bağlantısı başarıyla kuruldu!\nArtık kodlamaya hazırız.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}