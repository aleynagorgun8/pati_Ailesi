import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pati_ailesi/ozellikler/aile/ekranlar/aile_sohbet_paneli.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase eklendi

import '../../ozellikler/aile/ekranlar/aile_paneli.dart';
import '../../ozellikler/kullanici/ekranlar/kullanici_profil_paneli.dart';
import '../../ozellikler/aile/ekranlar/gunluk_ozet_paneli.dart'; // Import yolu güncellendi

class AnaNavigasyonPaneli extends StatefulWidget {
  const AnaNavigasyonPaneli({super.key});

  @override
  State<AnaNavigasyonPaneli> createState() => _AnaNavigasyonPaneliDurumu();
}

class _AnaNavigasyonPaneliDurumu extends State<AnaNavigasyonPaneli> {
  int _seciliSayfaIndeksi = 0;
  final Color koyuMavi = const Color(0xFF0D47A1);

  // Kullanıcının aile_id'sini saklayacağımız değişken
  String? _kullaniciAileId;
  bool _yukleniyor = true;

  // YENİ: 4 Sekme olduğu için 4 adet Navigator Key oluşturuyoruz
  final List<GlobalKey<NavigatorState>> _navigatorAnahtarlari = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _kullaniciBilgisiniGetir();
  }

  // Kullanıcının aile_id değerini Supabase'den çekiyoruz
  Future<void> _kullaniciBilgisiniGetir() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final veri = await Supabase.instance.client
          .from('kullanicilar')
          .select('aile_id')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _kullaniciAileId = veri?['aile_id'];
          _yukleniyor = false;
        });
      }
    }
  }

  void _sayfaDegistir(int indeks) {
    if (_seciliSayfaIndeksi == indeks) {
      _navigatorAnahtarlari[indeks].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _seciliSayfaIndeksi = indeks);
    }
  }

  Widget _sekmeOlustur(int indeks, Widget sayfa) {
    return Navigator(
      key: _navigatorAnahtarlari[indeks],
      onGenerateRoute: (routeSettings) => MaterialPageRoute(builder: (context) => sayfa),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Veriler yüklenirken bir yükleme ekranı gösteriyoruz
    if (_yukleniyor) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: koyuMavi)));
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final aktifNavigator = _navigatorAnahtarlari[_seciliSayfaIndeksi].currentState!;
        if (aktifNavigator.canPop()) {
          aktifNavigator.pop();
        } else if (_seciliSayfaIndeksi != 0) {
          _sayfaDegistir(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _seciliSayfaIndeksi,
          children: [
            _sekmeOlustur(0, const AilePaneli()),
            _sekmeOlustur(1, const AileSohbetPaneli()), // YENİ: Sohbet sekmesi eklendi
            _sekmeOlustur(2, AileAkisPaneli(aileId: _kullaniciAileId ?? '')), // Geçmiş
            _sekmeOlustur(3, const KullaniciProfilPaneli()), // Profil en sağa alındı
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _seciliSayfaIndeksi,
          onTap: _sayfaDegistir,
          backgroundColor: Colors.white,
          selectedItemColor: koyuMavi,
          unselectedItemColor: Colors.grey[400],
          showUnselectedLabels: true,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ailem'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Sohbet'), // YENİ: Sohbet İkonu
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}