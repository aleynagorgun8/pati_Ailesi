import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// Çıkış yapıldığında gidilecek giriş paneli
import '../../kimlik_dogrulama/ekranlar/kayit_paneli.dart';
// Storage servisini içe aktarıyoruz
import 'package:pati_ailesi/cekirdek/servisler/storage_servisi.dart';

class KullaniciProfilPaneli extends StatefulWidget {
  const KullaniciProfilPaneli({super.key});

  @override
  State<KullaniciProfilPaneli> createState() => _KullaniciProfilPaneliDurumu();
}

class _KullaniciProfilPaneliDurumu extends State<KullaniciProfilPaneli>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final StorageServisi _storageServisi = StorageServisi();

  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  String _kullaniciAdi = 'Yükleniyor...';
  String _kullaniciEposta = '';
  String? _profilFotoUrl;
  String? _aileId;

  // Genel İstatistik Değişkenleri
  int _kullaniciAktiviteSayisi = 0;
  int _toplamAileAktiviteSayisi = 0;

  // Kategori Bazlı İstatistik Haritaları (Maps)
  // Hangi kategoride toplam kaç görev var ve kullanıcı kaçını yapmış tutacağız.
  Map<String, int> _aileKategoriSayilari = {};
  Map<String, int> _kullaniciKategoriSayilari = {};

  bool _istatistikYukleniyor = true;
  bool _yukleniyor = true;
  bool _fotoYukleniyor = false;

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;
  late Animation<Offset> _kaymaAnimasyon;

  @override
  void initState() {
    super.initState();
    _animasyonKontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimasyon = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );
    _kaymaAnimasyon = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );

    _kullaniciBilgileriniGetir();
  }

  @override
  void dispose() {
    _animasyonKontrol.dispose();
    super.dispose();
  }

  Future<void> _kullaniciBilgileriniGetir() async {
    try {
      final mevcutKullanici = _supabase.auth.currentUser;
      if (mevcutKullanici == null) return;

      setState(() {
        _kullaniciEposta = mevcutKullanici.email ?? 'E-posta bulunamadı';
      });

      final veri = await _supabase
          .from('kullanicilar')
          .select('ad_soyad, profil_foto_url, aile_id')
          .eq('id', mevcutKullanici.id)
          .maybeSingle();

      if (mounted && veri != null) {
        setState(() {
          _kullaniciAdi = veri['ad_soyad'] ?? 'Değerli Üye';
          _profilFotoUrl = veri['profil_foto_url'];
          _aileId = veri['aile_id'];
        });

        _animasyonKontrol.forward(from: 0.0);

        // Aile ID'si çekildikten sonra detaylı istatistikleri getir
        await _istatistikleriGetir(mevcutKullanici.id, _aileId);
      }
    } catch (e) {
      debugPrint("Kullanıcı bilgileri çekilirken hata oluştu: $e");
      if (mounted) {
        setState(() => _kullaniciAdi = 'Bilinmeyen Kullanıcı');
      }
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  // --- YENİLENEN İSTATİSTİK GETİRME FONKSİYONU ---
  // Artık sadece sayıyı değil, kategori isimlerini de alıp işliyoruz
  Future<void> _istatistikleriGetir(String kullaniciId, String? aileId) async {
    if (aileId == null) {
      if (mounted) setState(() => _istatistikYukleniyor = false);
      return;
    }

    try {
      // Aileye ait TÜM aktiviteleri çekiyoruz (kullanıcı ve aktivite tipi bilgisiyle)
      final cevap = await _supabase
          .from('aktivite_gunlugu')
          .select('id, kullanici_id, aktivite_tipi')
          .eq('aile_id', aileId);

      final List<dynamic> veriler = cevap as List<dynamic>;

      int toplam = veriler.length;
      int kullaniciToplam = 0;

      // Geçici map'ler oluşturup döngü içinde dolduracağız
      Map<String, int> aileKat = {};
      Map<String, int> kulKat = {};

      for (var satir in veriler) {
        String kategori = satir['aktivite_tipi'] ?? 'Diğer';
        String kId = satir['kullanici_id'].toString();

        // Aile geneli için bu kategorinin sayısını 1 artır
        aileKat[kategori] = (aileKat[kategori] ?? 0) + 1;

        // Eğer bu aktiviteyi giriş yapan kullanıcı yaptıysa
        if (kId == kullaniciId) {
          kullaniciToplam++;
          kulKat[kategori] = (kulKat[kategori] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _toplamAileAktiviteSayisi = toplam;
          _kullaniciAktiviteSayisi = kullaniciToplam;
          _aileKategoriSayilari = aileKat;
          _kullaniciKategoriSayilari = kulKat;
          _istatistikYukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint("İstatistikler çekilirken hata oluştu: $e");
      if (mounted) setState(() => _istatistikYukleniyor = false);
    }
  }

  void _duzenlemeFormunuAc() {
    final adKontrolcusu = TextEditingController(text: _kullaniciAdi);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext altBaglam) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(altBaglam).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '✏️ Profil Güncelle',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: anaMavi,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(altBaglam),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: adKontrolcusu,
                    decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      labelStyle: TextStyle(color: textGri),
                      prefixIcon: Icon(Icons.person, color: anaMaviLight),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: TextEditingController(text: _kullaniciEposta),
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'E-posta Adresi (Değiştirilemez)',
                      labelStyle: TextStyle(color: textGri),
                      prefixIcon: Icon(Icons.email, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    if (adKontrolcusu.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('⚠️ Lütfen ad soyad girin.'),
                          backgroundColor: Colors.orange.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(altBaglam);
                    setState(() => _yukleniyor = true);

                    try {
                      final mevcutKullanici = _supabase.auth.currentUser;
                      if (mevcutKullanici != null) {
                        await _supabase
                            .from('kullanicilar')
                            .update({'ad_soyad': adKontrolcusu.text.trim()})
                            .eq('id', mevcutKullanici.id);

                        if (mounted) {
                          setState(() {
                            _kullaniciAdi = adKontrolcusu.text.trim();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('✅ Profil güncellendi!'),
                              backgroundColor: Colors.green.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    } catch (hata) {
                      debugPrint('Veri güncelleme hatası: $hata');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('⚠️ Güncelleme hatası.'),
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: anaMavi,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'Değişiklikleri Kaydet',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sifreDegistirmeFormunuAc() {
    final sifreKontrolcusu = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext altBaglam) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(altBaglam).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 16),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🔐 Şifremi Değiştir',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: anaMavi,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () => Navigator.pop(altBaglam),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: sifreKontrolcusu,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre (En az 6 karakter)',
                    labelStyle: TextStyle(color: textGri),
                    prefixIcon: Icon(Icons.lock, color: anaMaviLight),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () async {
                  if (sifreKontrolcusu.text.trim().length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('⚠️ Şifre en az 6 karakter olmalıdır.'),
                        backgroundColor: Colors.orange.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(altBaglam);
                  setState(() => _yukleniyor = true);

                  try {
                    await _supabase.auth.updateUser(
                      UserAttributes(password: sifreKontrolcusu.text.trim()),
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('✅ Şifre güncellendi!'),
                          backgroundColor: Colors.green.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } catch (hata) {
                    debugPrint('Şifre güncelleme hatası: $hata');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('⚠️ Şifre güncellenirken hata oluştu.'),
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: anaMavi,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'Şifreyi Kaydet',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _profilFotografiDegistir(ImageSource kaynak) async {
    try {
      final secilenDosya = await _storageServisi.fotografSec(kaynak);
      if (secilenDosya == null) return;

      setState(() => _fotoYukleniyor = true);

      final mevcutKullanici = _supabase.auth.currentUser;
      if (mevcutKullanici == null) return;

      final url = await _storageServisi.profilFotografiYukle(
          secilenDosya, mevcutKullanici.id);

      if (url != null) {
        await _supabase
            .from('kullanicilar')
            .update({'profil_foto_url': url})
            .eq('id', mevcutKullanici.id);

        if (mounted) {
          setState(() {
            _profilFotoUrl = url;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📸 Profil fotoğrafı güncellendi!'),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Fotoğraf güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Fotoğraf güncellenirken hata oluştu.'),
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
        setState(() => _fotoYukleniyor = false);
      }
    }
  }

  void _fotografSecimMenusuGoster() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext baglam) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profil Fotoğrafı',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: anaMavi,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _secenekKarti(
                        icon: Icons.photo_library,
                        label: 'Galeri',
                        color: Colors.blue.shade100,
                        iconColor: Colors.blue.shade700,
                        onTap: () {
                          Navigator.of(context).pop();
                          _profilFotografiDegistir(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _secenekKarti(
                        icon: Icons.camera_alt,
                        label: 'Kamera',
                        color: Colors.amber.shade100,
                        iconColor: Colors.amber.shade700,
                        onTap: () {
                          Navigator.of(context).pop();
                          _profilFotografiDegistir(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _secenekKarti({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cikisYap() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const KimlikDogrulamaPaneli()),
            (route) => false,
      );
    }
  }

  void _hakkindaGoster() {
    showAboutDialog(
      context: context,
      applicationName: 'Pati Ailesi',
      applicationVersion: 'v1.0',
      applicationIcon: Icon(Icons.pets, size: 50, color: anaMavi),
      children: [
        const SizedBox(height: 10),
        Text(
          'Ailemizin patili bireylerinin ortak takibine olanak sağlayan modern bir mobil çözümdür.\nGeliştirici: Aleyna Görgün',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      ],
    );
  }

  // --- GENEL İSTATİSTİK (Önceki Kart) ---
  Widget _istatistikKartiOlustur() {
    if (_istatistikYukleniyor) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: vurguRengi),
      );
    }

    if (_toplamAileAktiviteSayisi == 0 || _aileId == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kartBeyazi,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.auto_graph, color: anaMavi, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Ailede henüz bir aktivite kaydedilmemiş. İlk aktiviteyi sen oluştur! 🐾',
                style: GoogleFonts.poppins(fontSize: 14, color: textGri),
              ),
            ),
          ],
        ),
      );
    }

    double katilimOrani = _kullaniciAktiviteSayisi / _toplamAileAktiviteSayisi;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [anaMavi, anaMaviLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: anaMavi.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.2)),
                ),
                CircularProgressIndicator(
                  value: katilimOrani,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(vurguRengi),
                ),
                Center(
                  child: Text(
                    '%${(katilimOrani * 100).toInt()}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kişisel Özet',
                  style: GoogleFonts.poppins(
                    color: vurguRengi,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ailedeki toplam $_toplamAileAktiviteSayisi görevin $_kullaniciAktiviteSayisi tanesini sen tamamladın.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  katilimOrani > 0.5
                      ? 'Harika bir iş çıkarıyorsun! 💙'
                      : 'Hadi patililere daha çok vakit ayıralım! 🐾',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
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

  // --- YENİ EKLENEN: KATEGORİ BAZLI İSTATİSTİKLER ---
  // Kategorileri yatay kaydırılabilir küçük kartlar olarak listeler
  Widget _kategoriIstatistikleriOlustur() {
    if (_istatistikYukleniyor || _toplamAileAktiviteSayisi == 0) {
      return const SizedBox.shrink(); // Veri yoksa veya yükleniyorsa bu alanı gizle
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Kategori Bazlı Dağılım',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: anaMavi,
            ),
          ),
        ),
        SizedBox(
          height: 130, // Kartların yüksekliği
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _aileKategoriSayilari.length,
            itemBuilder: (context, index) {
              String kategoriAdi = _aileKategoriSayilari.keys.elementAt(index);
              int aileKategoriToplami = _aileKategoriSayilari[kategoriAdi]!;
              int kullaniciKategoriToplami = _kullaniciKategoriSayilari[kategoriAdi] ?? 0;

              // 0'a bölme hatasını önlemek için kontrol yapıyoruz
              double oran = aileKategoriToplami > 0
                  ? kullaniciKategoriToplami / aileKategoriToplami
                  : 0.0;

              return _kategoriKarti(kategoriAdi, kullaniciKategoriToplami, aileKategoriToplami, oran);
            },
          ),
        ),
        const SizedBox(height: 24), // Alt elemanlarla boşluk
      ],
    );
  }

  // Her bir kategorinin dairesel grafiğini barındıran küçük kart
  Widget _kategoriKarti(String kategori, int kullaniciYapti, int toplamYapildi, double oran) {
    return Container(
      width: 120, // Kart genişliği
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kartBeyazi,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Küçük dairesel grafik
          SizedBox(
            width: 45,
            height: 45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
                ),
                CircularProgressIndicator(
                  value: oran,
                  strokeWidth: 5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(vurguRengi), // Sarı renk
                ),
                Center(
                  child: Text(
                    '%${(oran * 100).toInt()}',
                    style: GoogleFonts.poppins(
                      color: anaMavi, // Lacivert yazı
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Kategori ismi
          Text(
            kategori,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: anaMavi,
            ),
          ),
          const SizedBox(height: 4),
          // Yapılan görev sayısı detayı (örn: 2/5 görev)
          Text(
            '$kullaniciYapti / $toplamYapildi',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: textGri,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimasyon,
      child: Scaffold(
        backgroundColor: arkaPlan,
        appBar: AppBar(
          title: Text(
            '👤 Profilim',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          backgroundColor: anaMavi,
          elevation: 0,
          centerTitle: true,
          leading: Container(
            margin: const EdgeInsets.only(left: 8),
          ),
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
                'Profil yükleniyor... 🐾',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )
            : SlideTransition(
          position: _kaymaAnimasyon,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Profil Fotoğrafı
                Stack(
                  alignment: Alignment.bottomRight,
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
                        radius: 60,
                        backgroundColor: Colors.blue.shade50,
                        backgroundImage: _profilFotoUrl != null
                            ? NetworkImage(_profilFotoUrl!)
                            : null,
                        child: _profilFotoUrl == null && !_fotoYukleniyor
                            ? Text(
                          _kullaniciAdi.isNotEmpty
                              ? _kullaniciAdi[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.poppins(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: anaMavi,
                          ),
                        )
                            : null,
                      ),
                    ),
                    if (_fotoYukleniyor)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _fotografSecimMenusuGoster,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [anaMavi, anaMaviLight],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: anaMavi.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // İsim
                Text(
                  _kullaniciAdi,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: anaMavi,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _kullaniciEposta,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: textGri,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Ayarlar Kartı
                Container(
                  decoration: BoxDecoration(
                    color: kartBeyazi,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        _ayarSecenegiOlustur(
                          icon: Icons.manage_accounts,
                          baslik: 'Kişisel Bilgileri Güncelle',
                          altBaslik: 'Ad soyad değiştir',
                          renk: anaMavi,
                          onTap: _duzenlemeFormunuAc,
                        ),
                        _ayarAyrac(),
                        _ayarSecenegiOlustur(
                          icon: Icons.lock_reset,
                          baslik: 'Şifremi Değiştir',
                          altBaslik: 'Hesap güvenliğini güncelle',
                          renk: anaMavi,
                          onTap: _sifreDegistirmeFormunuAc,
                        ),
                        _ayarAyrac(),
                        _ayarSecenegiOlustur(
                          icon: Icons.info_outline,
                          baslik: 'Uygulama Hakkında',
                          altBaslik: 'Versiyon 1.0',
                          renk: anaMavi,
                          onTap: _hakkindaGoster,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- İSTATİSTİK BÖLÜMÜ ---
                // Genel özet kartı
                _istatistikKartiOlustur(),

                // Kategorilere göre yatay liste dağılımı
                _kategoriIstatistikleriOlustur(),

                // Çıkış Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cikisYap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                    icon: Icon(Icons.logout, color: Colors.red.shade700),
                    label: Text(
                      'Hesaptan Çıkış Yap',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ayarSecenegiOlustur({
    required IconData icon,
    required String baslik,
    required String altBaslik,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: renk.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: renk, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: renk,
                      ),
                    ),
                    Text(
                      altBaslik,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: textGri,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ayarAyrac() {
    return Container(
      height: 1,
      color: Colors.grey.shade100,
    );
  }
}