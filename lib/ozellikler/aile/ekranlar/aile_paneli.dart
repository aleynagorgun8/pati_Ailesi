import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../cekirdek/servisler/veri_servisi.dart';
import '../../evcil_hayvan/ekranlar/hayvan_ekle_paneli.dart';
import '../../evcil_hayvan/ekranlar/hayvan_profil_paneli.dart';
import 'aile_secim_paneli.dart';

class AilePaneli extends StatefulWidget {
  const AilePaneli({super.key});

  @override
  State<AilePaneli> createState() => _AilePaneliState();
}

class _AilePaneliState extends State<AilePaneli>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final VeriServisi _veriServisi = VeriServisi();

  
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  late AnimationController _animasyonKontrolcusu;
  late Animation<double> _olcekAnimasyon;
  late ConfettiController _confettiKontrolcusu;

  List<Map<String, dynamic>> _evcilHayvanlar = [];
  List<Map<String, dynamic>> _aileUyeleri = [];

  List<Map<String, dynamic>> _bugunkuDogumGunleri = [];
  List<Map<String, dynamic>> _bugunkuAnmalar = [];

  String _aileAdi = 'Yükleniyor...';
  String _davetKodu = '';
  String? _kurucuId;
  String _gecerliAileId = '';
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animasyonKontrolcusu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _olcekAnimasyon = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrolcusu, curve: Curves.easeOut),
    );

    _confettiKontrolcusu = ConfettiController(duration: const Duration(seconds: 4));

    _verileriGetir();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animasyonKontrolcusu.dispose();
    _confettiKontrolcusu.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verileriGetir();
    }
  }

  Future<void> _verileriGetir() async {
    try {
      final mevcutKullaniciId = _supabase.auth.currentUser?.id;
      if (mevcutKullaniciId == null) return;

      final kullaniciVerisi = await _supabase
          .from('kullanicilar')
          .select('aile_id')
          .eq('id', mevcutKullaniciId)
          .maybeSingle();

      if (kullaniciVerisi == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ Profil verisi alınamadı.'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      if (kullaniciVerisi['aile_id'] == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AileSecimPaneli()),
          );
        }
        return;
      }

      _gecerliAileId = kullaniciVerisi['aile_id'];

      final aileVerisi = await _supabase
          .from('aileler')
          .select()
          .eq('id', _gecerliAileId)
          .maybeSingle();

      if (mounted && aileVerisi != null) {
        setState(() {
          _aileAdi = aileVerisi['aile_adi'] ?? 'İsimsiz Aile';
          _davetKodu = aileVerisi['davet_kodu'] ?? 'KOD YOK';
          _kurucuId = aileVerisi['kurucu_id'];
        });
      }

      final uyelerVerisi = await _supabase
          .from('kullanicilar')
          .select()
          .eq('aile_id', _gecerliAileId);

      final hayvanlarVerisi = await _veriServisi.evcilHayvanlariGetir(_gecerliAileId);

      if (mounted) {
        setState(() {
          _aileUyeleri = List<Map<String, dynamic>>.from(uyelerVerisi ?? []);
          _evcilHayvanlar = hayvanlarVerisi ?? [];
        });

        _ozelGunleriHesapla();
      }
    } catch (e) {
      debugPrint('HATA DETAYI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Sistem hatası: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
        _animasyonKontrolcusu.forward(from: 0.0);
      }
    }
  }

  void _ozelGunleriHesapla() {
    final bugun = DateTime.now();
    _bugunkuDogumGunleri.clear();
    _bugunkuAnmalar.clear();

    for (var hayvan in _evcilHayvanlar) {
      final durum = hayvan['durum'] ?? 'Aktif';
      final bool ayrilan = durum == 'Vefat' || durum == 'Kayıp';

      
      if (hayvan['dogum_tarihi'] != null) {
        try {
          final dogumTarihi = DateTime.parse(hayvan['dogum_tarihi']);
          if (dogumTarihi.month == bugun.month && dogumTarihi.day == bugun.day) {
            int yas = bugun.year - dogumTarihi.year;
            if (yas > 0) {
              hayvan['kutlanan_yas'] = yas;
              hayvan['ayrildi_mi'] = ayrilan;
              _bugunkuDogumGunleri.add(hayvan);
            }
          }
        } catch (e) {
          debugPrint('Tarih okuma hatası: $e');
        }
      }

      
      if (durum == 'Vefat' && hayvan['ayrilis_tarihi'] != null) {
        try {
          final vefatTarihi = DateTime.parse(hayvan['ayrilis_tarihi']);
          if (vefatTarihi.month == bugun.month && vefatTarihi.day == bugun.day) {
            int anmaYili = bugun.year - vefatTarihi.year;
            if (anmaYili > 0) {
              hayvan['anma_yili'] = anmaYili;
              _bugunkuAnmalar.add(hayvan);
            }
          }
        } catch (e) {
          debugPrint('Tarih okuma hatası: $e');
        }
      }
    }

    
    bool aktifDogumGunuVar = _bugunkuDogumGunleri.any((h) => h['ayrildi_mi'] == false);
    if (aktifDogumGunuVar) {
      _confettiKontrolcusu.stop();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _confettiKontrolcusu.play();
        }
      });
    }
  }

  Future<void> _koduKopyala() async {
    if (_davetKodu.isEmpty || _davetKodu == 'KOD YOK') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Geçerli bir kod bulunamadı!'),
          backgroundColor: Colors.orange.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: _davetKodu));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('🎉 $_davetKodu kopyalandı!'),
            ],
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _koduYenile() async {
    final yeniKod = (Random().nextInt(900000) + 100000).toString();
    setState(() => _yukleniyor = true);

    try {
      await _supabase
          .from('aileler')
          .update({'davet_kodu': yeniKod})
          .eq('id', _gecerliAileId);

      if (mounted) {
        setState(() => _davetKodu = yeniKod);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔄 Davet kodu yenilendi!'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Kod yenileme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Kod yenilenirken hata oluştu.'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _ailedenAyril() async {
    setState(() => _yukleniyor = true);
    try {
      final guncelId = _supabase.auth.currentUser?.id;
      if (guncelId == null) return;

      await _supabase
          .from('kullanicilar')
          .update({'aile_id': null})
          .eq('id', guncelId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('👋 Aileden ayrıldınız.'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AileSecimPaneli()),
        );
      }
    } catch (e) {
      debugPrint('Ayrılma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Ayrılma işlemi başarısız.'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _uyeyiAiledenCikar(String uyeId) async {
    setState(() => _yukleniyor = true);
    try {
      await _supabase
          .from('kullanicilar')
          .update({'aile_id': null})
          .eq('id', uyeId);

      if (mounted) {
        setState(() {
          _aileUyeleri.removeWhere((u) => u['id'] == uyeId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('👤 Üye çıkarıldı.'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        _animasyonKontrolcusu.forward(from: 0.0);
      }
    } catch (e) {
      debugPrint('Üye çıkarma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Üye çıkarılırken hata oluştu.'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  
  void _aileAdiDegistirmeDialogGoster() {
    final TextEditingController adKontrolcusu = TextEditingController(text: _aileAdi);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: anaMavi),
              const SizedBox(width: 8),
              Text(
                'Aile Adını Güncelle',
                style: GoogleFonts.poppins(
                  color: anaMavi,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: adKontrolcusu,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: 'Yeni Aile Adı',
              labelStyle: TextStyle(color: textGri),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: anaMavi),
              ),
            ),
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final yeniAd = adKontrolcusu.text.trim();
                if (yeniAd.isEmpty) return;
                Navigator.pop(context);
                await _aileAdiniGuncelle(yeniAd);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: anaMavi,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Kaydet',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _aileAdiniGuncelle(String yeniAd) async {
    setState(() => _yukleniyor = true);
    try {
      await _supabase
          .from('aileler')
          .update({'aile_adi': yeniAd})
          .eq('id', _gecerliAileId);

      if (mounted) {
        setState(() {
          _aileAdi = yeniAd;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Aile adı başarıyla güncellendi!'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Aile adı güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Aile adı güncellenirken bir hata oluştu.'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }


  void _uyeIslemleriMenusuGoster(Map<String, dynamic> uye) {
    final guncelKullaniciId = _supabase.auth.currentUser?.id;

    final bool benKurucuyum = guncelKullaniciId == _kurucuId;
    final bool tiklananKisiKurucuMu = uye['id'] == _kurucuId;
    final bool tiklananKisiBenMiyim = uye['id'] == guncelKullaniciId;

    final String isminIlkHarfi = (uye['ad_soyad'] != null &&
        uye['ad_soyad'].toString().trim().isNotEmpty)
        ? uye['ad_soyad'].toString().trim()[0].toUpperCase()
        : 'U';
    final profilFoto = uye['profil_foto_url'];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: anaMavi.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: kartBeyazi,
                    backgroundImage:
                    profilFoto != null ? NetworkImage(profilFoto) : null,
                    child: profilFoto == null
                        ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [anaMavi, anaMaviLight],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isminIlkHarfi,
                          style: GoogleFonts.poppins(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  uye['ad_soyad'] ?? 'İsimsiz Üye',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: anaMavi,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: tiklananKisiKurucuMu
                          ? [vurguRengi, vurguRengiLight]
                          : [Colors.blue.shade100, Colors.blue.shade200],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tiklananKisiKurucuMu ? '👑 Kurucu' : '👤 Aile Üyesi',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: tiklananKisiKurucuMu ? anaMavi : Colors.blue.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (tiklananKisiBenMiyim) ...[
                  if (benKurucuyum)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: vurguRengi.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: vurguRengi, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Bu ailenin kurucususun 🌟',
                            style: GoogleFonts.poppins(
                              color: anaMavi,
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _islemButonu(
                      icon: Icons.exit_to_app,
                      label: 'Aileden Ayrıl',
                      color: Colors.red,
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Ayrılma Onayı',
                                  style: GoogleFonts.poppins(
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Aileden ayrılmak istediğine emin misin? 🐾',
                              style: GoogleFonts.poppins(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'İptal',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _ailedenAyril();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Evet, Ayrıl',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ] else ...[
                  if (benKurucuyum)
                    _islemButonu(
                      icon: Icons.person_remove,
                      label: 'Aileden Çıkar',
                      color: Colors.red,
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Üyeyi Çıkar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              '${uye['ad_soyad']} adlı kişiyi aileden çıkarmak istediğine emin misin?',
                              style: GoogleFonts.poppins(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'İptal',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _uyeyiAiledenCikar(uye['id']);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Evet, Çıkar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Bu üye üzerinde işlem yapma yetkin yok',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Kapat',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _islemButonu({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  
  Widget _dogumGunuKarti(Map<String, dynamic> hayvan) {
    final int yas = hayvan['kutlanan_yas'];
    final String ad = hayvan['ad'] ?? 'Dostumuz';
    final bool ayrildi = hayvan['ayrildi_mi'] ?? false;
    final String durum = hayvan['durum'] ?? 'Aktif';
    final bool vefatMi = durum == 'Vefat';

    
    String mesaj;
    Color renk1, renk2;

    if (ayrildi) {
      if (vefatMi) {
        mesaj = '🕊️ Aramızdan ayrıldı ama kalbimizde... Bugün $yas yaşında olacaktı.';
        renk1 = Colors.grey.shade700;
        renk2 = Colors.grey.shade900;
      } else {
        mesaj = '🔍 Kayıp ama umutla bekliyoruz... Bugün $yas yaşında olacaktı.';
        renk1 = Colors.blue.shade700;
        renk2 = Colors.blue.shade900;
      }
    } else {
      mesaj = '🎂 Bugün tam $yas yaşına girdi! Birlikte nice mutlu yıllara...';
      renk1 = const Color(0xFFFF4081);
      renk2 = const Color(0xFFFF9100);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [renk1, renk2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: renk1.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(ayrildi ? (vefatMi ? '🕊️' : '🔍') : '🎉', style: const TextStyle(fontSize: 42)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ayrildi ? 'Doğum Günün Kutlu Olsun $ad!' : 'İyi ki Doğdun $ad!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  mesaj,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _anmaKarti(Map<String, dynamic> hayvan) {
    final int yil = hayvan['anma_yili'];
    final String ad = hayvan['ad'] ?? 'Dostumuz';
    final String durum = hayvan['durum'] ?? 'Vefat';
    final bool vefatMi = durum == 'Vefat';

    String emoji = vefatMi ? '🕊️' : '🔍';
    String mesaj = vefatMi
        ? 'Aramızdan ayrılalı tam $yil yıl oldu. Seni hiç unutmadık.'
        : 'Kaybolalı tam $yil yıl oldu. Umarız bir gün dönersin.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vefatMi
              ? [Colors.grey.shade800, Colors.grey.shade900]
              : [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 42)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vefatMi ? 'Kalbimizdesin $ad...' : 'Umarız dönersin $ad...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  mesaj,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayrilanlarBasligi() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              'Aramızdan Ayrılan Dostlarımız',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guncelKullaniciId = _supabase.auth.currentUser?.id;
    final aktifHayvanlar = _evcilHayvanlar.where((h) => h['durum'] == null || h['durum'] == 'Aktif').toList();
    final ayrilanHayvanlar = _evcilHayvanlar.where((h) => h['durum'] == 'Vefat' || h['durum'] == 'Kayıp').toList();

    return AnimatedBuilder(
      animation: _olcekAnimasyon,
      builder: (context, child) {
        return Transform.scale(
          scale: _olcekAnimasyon.value,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: arkaPlan,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  
                  title: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Text(
                        _aileAdi,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      
                      if (guncelKullaniciId == _kurucuId) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _aileAdiDegistirmeDialogGoster,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              color: vurguRengi, 
                              size: 18,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                  centerTitle: true,
                  backgroundColor: anaMavi,
                  elevation: 0,
                ),
                body: _yukleniyor
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF1A237E),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aile bilgileri yükleniyor... 🐾',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                    : Column(
                  children: [
                    _aileUstBilgiTasarimi(),
                    Expanded(
                      child: _evcilHayvanlar.isEmpty
                          ? _bosListeTasarimi()
                          : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          
                          if (_bugunkuDogumGunleri.isNotEmpty) ...[
                            ..._bugunkuDogumGunleri.map((h) => _dogumGunuKarti(h)).toList(),
                            const SizedBox(height: 8),
                          ],

                          
                          if (_bugunkuAnmalar.isNotEmpty) ...[
                            ..._bugunkuAnmalar.map((h) => _anmaKarti(h)).toList(),
                            const SizedBox(height: 16),
                          ],

                          
                          ...aktifHayvanlar.map((h) => _hayvanKarti(h)).toList(),

                          
                          if (ayrilanHayvanlar.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _ayrilanlarBasligi(),
                            const SizedBox(height: 8),
                            ...ayrilanHayvanlar.map((h) => _hayvanKarti(h)).toList(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                floatingActionButton: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: anaMavi.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () async {
                      final sonuc = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HayvanEklePaneli()),
                      );

                      if (sonuc == true) {
                        setState(() => _yukleniyor = true);
                        await _verileriGetir();
                      }
                    },
                    backgroundColor: anaMavi,
                    child: const Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
              ),

              
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiKontrolcusu,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.red,
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                    Colors.teal,
                  ],
                  createParticlePath: drawStar,
                  numberOfParticles: 50,
                  gravity: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  Widget _aileUstBilgiTasarimi() {
    final guncelKullaniciId = _supabase.auth.currentUser?.id;

    final kurucu = _aileUyeleri.isNotEmpty
        ? _aileUyeleri.firstWhere(
          (uye) => uye['id'] == _kurucuId,
      orElse: () => {'id': 'hata', 'ad_soyad': 'Bilinmiyor'},
    )
        : {'id': 'hata', 'ad_soyad': 'Bilinmiyor'};

    String kurucuMetni = kurucu['ad_soyad'] ?? 'Bilinmiyor';
    if (kurucu['id'] == guncelKullaniciId) {
      kurucuMetni = 'Ben ($kurucuMetni)';
    }

    final digerUyeler = _aileUyeleri.where((uye) => uye['id'] != kurucu['id']).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [anaMavi, anaMaviLight],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: anaMavi.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _koduKopyala,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.vpn_key,
                        color: vurguRengiLight,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _davetKodu.isNotEmpty ? _davetKodu : 'KOD BEKLENİYOR...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.copy,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (guncelKullaniciId == _kurucuId) ...[
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [vurguRengi, vurguRengiLight],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: vurguRengi.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: anaMavi),
                    onPressed: _koduYenile,
                    tooltip: 'Kodu Yenile',
                    iconSize: 22,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '📋 Kopyalamak için koda dokun',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 28),

          LayoutBuilder(
            builder: (context, constraints) {
              final double genislik = constraints.maxWidth;
              const double yukseklik = 240.0;
              final double merkezX = genislik / 2;
              final double merkezY = yukseklik / 2;
              const double yaricap = 100.0;

              List<Widget> yiginElemanlari = [];

              yiginElemanlari.add(
                CustomPaint(
                  size: Size(genislik, yukseklik),
                  painter: BaglantiRessami(digerUyeler.length, yaricap),
                ),
              );

              final double aciAdimi =
              digerUyeler.isNotEmpty ? (2 * pi) / digerUyeler.length : 0;
              for (int i = 0; i < digerUyeler.length; i++) {
                final uye = digerUyeler[i];
                final isminIlkHarfi = (uye['ad_soyad'] != null &&
                    uye['ad_soyad'].toString().trim().isNotEmpty)
                    ? uye['ad_soyad'].toString().trim()[0].toUpperCase()
                    : 'U';
                final profilFoto = uye['profil_foto_url'];
                final kisaIsim =
                (uye['ad_soyad'] ?? 'Bilinmeyen').toString().split(' ')[0];

                final double aci = i * aciAdimi;
                final double solKonum = merkezX + (yaricap * cos(aci)) - 40;
                final double ustKonum = merkezY + (yaricap * sin(aci)) - 35;

                final gecikme = (i * 0.12).clamp(0.0, 0.6);
                final uyeAnimasyonu = CurvedAnimation(
                  parent: _animasyonKontrolcusu,
                  curve: Interval(gecikme, 1.0, curve: Curves.elasticOut),
                );

                yiginElemanlari.add(
                  Positioned(
                    left: solKonum,
                    top: ustKonum,
                    child: ScaleTransition(
                      scale: uyeAnimasyonu,
                      child: GestureDetector(
                        onTap: () => _uyeIslemleriMenusuGoster(uye),
                        child: SizedBox(
                          width: 80,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 23,
                                    backgroundColor: Colors.blue.shade300,
                                    backgroundImage: profilFoto != null
                                        ? NetworkImage(profilFoto)
                                        : null,
                                    child: profilFoto == null
                                        ? Text(
                                      isminIlkHarfi,
                                      style: GoogleFonts.poppins(
                                        color: anaMavi,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                kisaIsim,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final kurucuIsminIlkHarfi = (kurucu['ad_soyad'] != null &&
                  kurucu['ad_soyad'].toString().trim().isNotEmpty)
                  ? kurucu['ad_soyad'].toString().trim()[0].toUpperCase()
                  : 'K';
              final kurucuFoto = kurucu['profil_foto_url'];
              final kurucuKisaIsim =
              (kurucu['ad_soyad'] ?? 'Bilinmiyor').toString().split(' ')[0];

              final kurucuAnimasyon = CurvedAnimation(
                parent: _animasyonKontrolcusu,
                curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
              );

              yiginElemanlari.add(
                Positioned(
                  left: merkezX - 55,
                  top: merkezY - 60,
                  child: ScaleTransition(
                    scale: kurucuAnimasyon,
                    child: GestureDetector(
                      onTap: () => _uyeIslemleriMenusuGoster(kurucu),
                      child: SizedBox(
                        width: 110,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: vurguRengi.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: vurguRengi,
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: kurucuFoto != null
                                      ? NetworkImage(kurucuFoto)
                                      : null,
                                  child: kurucuFoto == null
                                      ? Text(
                                    kurucuIsminIlkHarfi,
                                    style: GoogleFonts.poppins(
                                      color: anaMavi,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                    ),
                                  )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [vurguRengi, vurguRengiLight],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '👑 $kurucuKisaIsim',
                                style: GoogleFonts.poppins(
                                  color: anaMavi,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              return SizedBox(
                width: genislik,
                height: yukseklik,
                child: Stack(
                  children: yiginElemanlari,
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars, color: vurguRengi, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Kurucu: $kurucuMetni',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _bosListeTasarimi() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz pati eklemedin 🐾',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sağ alt köşedeki + butonu ile\nilk patini eklemeye başla!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hayvanKarti(Map<String, dynamic> hayvan) {
    final profilFoto = hayvan['profil_foto_url'];

    final String durum = hayvan['durum'] ?? 'Aktif';
    final bool vefatMi = durum == 'Vefat';
    final bool kayipMi = durum == 'Kayıp';
    final bool ayrilan = vefatMi || kayipMi;

    Widget kartIcerigi = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: kartBeyazi,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HayvanProfilPaneli(
                  hayvanVerisi: hayvan,
                ),
              ),
            );

            if (mounted) {
              setState(() => _yukleniyor = true);
              await _verileriGetir();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: anaMavi.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage:
                    profilFoto != null ? NetworkImage(profilFoto) : null,
                    child: profilFoto == null
                        ? Icon(
                      Icons.pets,
                      color: anaMavi.withOpacity(0.6),
                      size: 32,
                    )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hayvan['ad'] ?? 'İsimsiz Pati',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: anaMavi,
                            ),
                          ),
                          if (ayrilan) ...[
                            const SizedBox(width: 6),
                            Text(
                              vefatMi ? '🕊️' : '🔍',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.category,
                            size: 14,
                            color: textGri,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${hayvan['tur'] ?? 'Tür belirtilmemiş'}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: textGri,
                            ),
                          ),
                          if (hayvan['irk'] != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hayvan['irk'],
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: textGri,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: anaMavi.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: anaMavi.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ayrilan) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: kartIcerigi,
      );
    }

    return kartIcerigi;
  }
}

class BaglantiRessami extends CustomPainter {
  final int dugumSayisi;
  final double yaricap;

  BaglantiRessami(this.dugumSayisi, this.yaricap);

  @override
  void paint(Canvas tuval, Size boyut) {
    if (dugumSayisi == 0) return;

    final merkez = Offset(boyut.width / 2, boyut.height / 2);

    final firca = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFC107), Color(0xFFFFD54F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromCircle(center: merkez, radius: yaricap),
      )
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final double aciAdimi = (2 * pi) / dugumSayisi;

    for (int i = 0; i < dugumSayisi; i++) {
      final aci = i * aciAdimi;
      final hedefX = merkez.dx + yaricap * cos(aci);
      final hedefY = merkez.dy + yaricap * sin(aci);

      final path = Path();
      path.moveTo(merkez.dx, merkez.dy);
      path.lineTo(hedefX, hedefY);

      tuval.drawPath(path, firca);

      final noktaFircasi = Paint()
        ..color = const Color(0xFFFFC107).withOpacity(0.6)
        ..style = PaintingStyle.fill;

      tuval.drawCircle(Offset(hedefX, hedefY), 3, noktaFircasi);
    }

    final haloFircasi = Paint()
      ..color = const Color(0xFFFFC107).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    tuval.drawCircle(merkez, 20, haloFircasi);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}