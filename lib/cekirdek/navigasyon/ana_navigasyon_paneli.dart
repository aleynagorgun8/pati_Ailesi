import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pati_ailesi/ozellikler/aile/ekranlar/aile_sohbet_paneli.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ozellikler/aile/ekranlar/aile_paneli.dart';
import '../../ozellikler/kullanici/ekranlar/kullanici_profil_paneli.dart';
import '../../ozellikler/aile/ekranlar/gunluk_ozet_paneli.dart';

class AnaNavigasyonPaneli extends StatefulWidget {
  const AnaNavigasyonPaneli({super.key});

  @override
  State<AnaNavigasyonPaneli> createState() => _AnaNavigasyonPaneliDurumu();
}

class _AnaNavigasyonPaneliDurumu extends State<AnaNavigasyonPaneli> {
  int _seciliSayfaIndeksi = 0;
  final Color koyuMavi = const Color(0xFF0D47A1);
  final Color fenerbahceSarisi = const Color(0xFFFFC107);

  String? _gecerliKullaniciId;
  String? _kullaniciAileId;
  bool _yukleniyor = true;
  bool _okunmamisMesajVar = false;

  StreamSubscription? _mesajAboneligi;
  Timer? _debounceTimer; // Bildirim yanıp sönmesini engellemek için zamanlayıcı

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

  @override
  void dispose() {
    _mesajAboneligi?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _kullaniciBilgisiniGetir() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _gecerliKullaniciId = userId;
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
        if (_kullaniciAileId != null) {
          _mesajDinleyiciyiBaslat();
        }
      }
    }
  }

  void _mesajDinleyiciyiBaslat() {
    _mesajAboneligi = Supabase.instance.client
        .from('aile_mesajlari')
        .stream(primaryKey: ['id'])
        .eq('aile_id', _kullaniciAileId!)
        .listen((mesajlar) {

      // 1. Sohbet ekranındaysan bildirimleri zaten gösterme
      if (_seciliSayfaIndeksi == 1) {
        setState(() => _okunmamisMesajVar = false);
        return;
      }

      // 2. Kendi okumadığın mesajları bul
      bool yeniOkunmamisVar = mesajlar.any((mesaj) {
        final List okuyanlar = List.from(mesaj['okuyanlar'] ?? []);
        return mesaj['gonderen_id'] != _gecerliKullaniciId && !okuyanlar.contains(_gecerliKullaniciId);
      });

      // 3. EĞER YENİ BİR MESAJ VARSA VE ZATEN BİLDİRİMİN VARSA, ONU SİLME!
      // Sadece 'yeniOkunmamisVar' true ise ve daha önce false ise bildirimi yak.
      if (yeniOkunmamisVar) {
        setState(() => _okunmamisMesajVar = true);
      }
      // NOT: Burada 'else' koymuyoruz!
      // Çünkü 'yeniOkunmamisVar' false olsa bile biz 'true'yu korumak istiyoruz
      // (Ta ki kullanıcı sohbet ekranına girene kadar).
    });
  }
  void _sayfaDegistir(int indeks) {
    // SOHBETE TIKLANDIĞI AN BİLDİRİMİ SIFIRLA
    if (indeks == 1) {
      setState(() => _okunmamisMesajVar = false);
    }

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
            _sekmeOlustur(1, const AileSohbetPaneli()),
            _sekmeOlustur(2, AileAkisPaneli(aileId: _kullaniciAileId ?? '')),
            _sekmeOlustur(3, const KullaniciProfilPaneli()),
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
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ailem'),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _okunmamisMesajVar,
                backgroundColor: fenerbahceSarisi,
                child: const Icon(Icons.chat),
              ),
              label: 'Sohbet',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}