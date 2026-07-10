import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class HijyenTakipPaneli extends StatefulWidget {
  final Map<String, dynamic> hayvanVerisi;

  const HijyenTakipPaneli({Key? key, required this.hayvanVerisi})
      : super(key: key);

  @override
  State<HijyenTakipPaneli> createState() => _HijyenTakipPaneliDurumu();
}

class _HijyenTakipPaneliDurumu extends State<HijyenTakipPaneli>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // Modern renk paleti 💙💛
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  // Genişletilmiş hijyen işlemleri listesi
  final List<String> _hijyenIslemleri = [
    'Kum Temizleme',
    'Tırnak Kesme',
    'Tüy Tarama',
    'Diş Fırçalama',
    'Banyo',
    'Göz ve Kulak Temizliği',
    'Pati Bakımı'
  ];

  final Map<String, IconData> _islemIkonlari = {
    'Kum Temizleme': Icons.cleaning_services,
    'Tırnak Kesme': Icons.content_cut,
    'Tüy Tarama': Icons.brush,
    'Diş Fırçalama': Icons.medical_services,
    'Banyo': Icons.bathtub,
    'Göz ve Kulak Temizliği': Icons.visibility,
    'Pati Bakımı': Icons.pets,
  };

  final Map<String, Color> _islemRenkleri = {
    'Kum Temizleme': const Color(0xFF00BFA5),
    'Tırnak Kesme': const Color(0xFFFF6B35),
    'Tüy Tarama': const Color(0xFF9C27B0),
    'Diş Fırçalama': const Color(0xFF2196F3),
    'Banyo': const Color(0xFF4FC3F7),
    'Göz ve Kulak Temizliği': const Color(0xFF7B1FA2),
    'Pati Bakımı': const Color(0xFFFF9800),
  };

  List<Map<String, dynamic>> _hijyenGecmisi = [];
  bool _yukleniyor = true;
  String _gecerliKullaniciId = '';

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;

  @override
  void initState() {
    super.initState();
    _gecerliKullaniciId = _supabase.auth.currentUser?.id ?? '';
    _animasyonKontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimasyon = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );
    _verileriGetir();
  }

  @override
  void dispose() {
    _animasyonKontrol.dispose();
    super.dispose();
  }

  Future<void> _verileriGetir() async {
    try {
      setState(() => _yukleniyor = true);
      final hayvanId = widget.hayvanVerisi['id'];

      final gecmis = await _supabase
          .from('aktivite_gunlugu')
          .select('''
            id,
            islem_detayi,
            gerceklesme_zamani,
            kullanicilar (ad_soyad)
          ''')
          .eq('hayvan_id', hayvanId)
          .eq('aktivite_tipi', 'Hijyen')
          .order('gerceklesme_zamani', ascending: false);

      if (mounted) {
        setState(() {
          _hijyenGecmisi = List<Map<String, dynamic>>.from(gecmis);
          _animasyonKontrol.forward(from: 0.0);
        });
      }
    } catch (e) {
      debugPrint('Hijyen verileri getirme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Kayıtlar yüklenemedi: $e'),
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

  String _bildirimMetniOlustur(String hayvanAdi, String kisi, String islem) {
    switch (islem) {
      case 'Kum Temizleme':
        return "$hayvanAdi dostumuzun kumu $kisi tarafından temizlendi.";
      case 'Tırnak Kesme':
        return "$hayvanAdi dostumuzun tırnakları $kisi tarafından kesildi.";
      case 'Tüy Tarama':
        return "$hayvanAdi dostumuzun tüyleri $kisi tarafından tarandı.";
      case 'Diş Fırçalama':
        return "$hayvanAdi dostumuzun dişleri $kisi tarafından fırçalandı.";
      case 'Banyo':
        return "$hayvanAdi dostumuz $kisi tarafından yıkandı.";
      case 'Göz ve Kulak Temizliği':
        return "$hayvanAdi dostumuzun göz/kulak temizliği $kisi tarafından yapıldı.";
      case 'Pati Bakımı':
        return "$hayvanAdi dostumuzun pati bakımı $kisi tarafından yapıldı.";
      default:
        return "$hayvanAdi dostumuza $kisi tarafından $islem işlemi uygulandı.";
    }
  }

  void _islemFormunuAc({Map<String, dynamic>? mevcutKayit}) {
    String seciliIslem = mevcutKayit?['islem_detayi'] ?? _hijyenIslemleri.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext baglam) {
        return StatefulBuilder(
          builder: (BuildContext formBaglami, StateSetter formSetState) {
            Color islemRengi = _islemRenkleri[seciliIslem] ?? anaMavi;
            IconData islemIkon = _islemIkonlari[seciliIslem] ?? Icons.cleaning_services;

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
                bottom: MediaQuery.of(baglam).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık çubuğu
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
                        mevcutKayit == null
                            ? '🧹 Yeni Hijyen İşlemi'
                            : '✏️ Kaydı Düzenle',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: anaMavi,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade600),
                        onPressed: () => Navigator.pop(baglam),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // İşlem Seçimi
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: seciliIslem,
                      decoration: InputDecoration(
                        labelText: 'Yapılan İşlem',
                        labelStyle: TextStyle(color: textGri),
                        prefixIcon: Icon(islemIkon, color: islemRengi),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _hijyenIslemleri.map((islem) {
                        Color renk = _islemRenkleri[islem] ?? anaMavi;
                        IconData ikon = _islemIkonlari[islem] ?? Icons.cleaning_services;
                        return DropdownMenuItem(
                          value: islem,
                          child: Row(
                            children: [
                              Icon(ikon, color: renk, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                islem,
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (y) {
                        formSetState(() {
                          seciliIslem = y!;
                        });
                      },
                      style: GoogleFonts.poppins(fontSize: 14, color: anaMavi),
                      icon: Icon(Icons.keyboard_arrow_down, color: anaMaviLight),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kaydet Butonu
                  ElevatedButton(
                    onPressed: () async {
                      setState(() => _yukleniyor = true);
                      Navigator.pop(context);

                      try {
                        final kayitVerisi = {
                          'aile_id': widget.hayvanVerisi['aile_id'],
                          'hayvan_id': widget.hayvanVerisi['id'],
                          'kullanici_id': _gecerliKullaniciId,
                          'aktivite_tipi': 'Hijyen',
                          'islem_detayi': seciliIslem,
                        };

                        if (mevcutKayit == null) {
                          await _supabase.from('aktivite_gunlugu').insert(kayitVerisi);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('✅ Hijyen kaydı eklendi!'),
                              backgroundColor: Colors.green.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        } else {
                          await _supabase
                              .from('aktivite_gunlugu')
                              .update(kayitVerisi)
                              .eq('id', mevcutKayit['id']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('✅ Kayıt güncellendi!'),
                              backgroundColor: Colors.green.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }

                        await _verileriGetir();
                      } catch (e) {
                        debugPrint('Kayıt hatası: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚠️ Kayıt hatası: $e'),
                            backgroundColor: Colors.red.shade400,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
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
                          mevcutKayit == null ? 'Kaydet' : 'Güncelle',
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
      },
    );
  }

  Future<void> _kayitSil(String id) async {
    try {
      setState(() => _yukleniyor = true);
      await _supabase.from('aktivite_gunlugu').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Kayıt silindi'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _verileriGetir();
    } catch (e) {
      debugPrint('Silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Silme hatası: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayvanAdi = widget.hayvanVerisi['ad'] ?? 'İsimsiz';

    return Scaffold(
      backgroundColor: arkaPlan,
      appBar: AppBar(
        title: Text(
          '$hayvanAdi · Hijyen',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: anaMavi,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
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
              'Hijyen kayıtları yükleniyor... 🐾',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : _hijyenGecmisi.isEmpty
          ? _bosListeTasarimi()
          : FadeTransition(
        opacity: _fadeAnimasyon,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          itemCount: _hijyenGecmisi.length,
          itemBuilder: (context, indeks) {
            final kayit = _hijyenGecmisi[indeks];
            final kisi = kayit['kullanicilar']?['ad_soyad'] ??
                'Bir Üye';
            final islem = kayit['islem_detayi'] ?? 'Bilinmeyen İşlem';

            Color islemRengi = _islemRenkleri[islem] ?? anaMavi;
            IconData islemIkon = _islemIkonlari[islem] ??
                Icons.cleaning_services;

            DateTime tarih = DateTime.parse(
                kayit['gerceklesme_zamani']).toLocal();
            String saatMetni =
                "${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}";
            String gunMetni =
                "${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}";

            final bildirimMetni = _bildirimMetniOlustur(
                hayvanAdi, kisi, islem);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kartBeyazi,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // İkon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: islemRengi.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            islemIkon,
                            color: islemRengi,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // İçerik
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                islem,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: anaMavi,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 12,
                                    color: textGri,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    kisi,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: textGri,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color:
                                      textGri.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: textGri,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$gunMetni $saatMetni',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: textGri,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Menü Butonu
                        PopupMenuButton<String>(
                          onSelected: (deger) {
                            if (deger == 'duzenle') {
                              _islemFormunuAc(mevcutKayit: kayit);
                            }
                            if (deger == 'sil') {
                              _kayitSil(kayit['id']);
                            }
                          },
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade400,
                          ),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'duzenle',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      color: anaMavi, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Düzenle',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'sil',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red.shade400,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sil',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
        child: FloatingActionButton.extended(
          onPressed: () => _islemFormunuAc(),
          backgroundColor: anaMavi,
          icon: const Icon(Icons.cleaning_services, color: Colors.white),
          label: Text(
            'İşlem Ekle',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
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
              Icons.cleaning_services,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz hijyen kaydı yok 🧹',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kayıt eklemek için "İşlem Ekle" butonuna dokun.',
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
}