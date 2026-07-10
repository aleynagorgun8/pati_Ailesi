import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'ozellikler/kimlik_dogrulama/ekranlar/kayit_paneli.dart';
import 'package:pati_ailesi/cekirdek/navigasyon/ana_navigasyon_paneli.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR', null);

  await Supabase.initialize(
    url: 'https://ridvmudmahymxkgikguk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpZHZtdWRtYWh5bXhrZ2lrZ3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzMjE5NzksImV4cCI6MjA5ODg5Nzk3OX0.s9DWO_IuXJcPLOW-mAAYfmE5OsnDuB_RvSNxJpJUt_A',
  );

  runApp(const PatiAilesiUygulamasi());
}

class PatiAilesiUygulamasi extends StatelessWidget {
  const PatiAilesiUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    final aktifOturum = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Pati Ailesi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: aktifOturum != null ? const AnaNavigasyonPaneli() : const KimlikDogrulamaPaneli(),
    );
  }
}

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