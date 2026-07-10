import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AileAkisPaneli extends StatefulWidget {
  final String aileId;
  const AileAkisPaneli({Key? key, required this.aileId}) : super(key: key);

  @override
  State<AileAkisPaneli> createState() => _AileAkisPaneliState();
}

class _AileAkisPaneliState extends State<AileAkisPaneli>
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

  RealtimeChannel? _abonelik;

  List<Map<String, dynamic>> _tumAktiviteler = [];
  List<Map<String, dynamic>> _aileUyeleri = [];
  bool _yukleniyor = true;

  String _seciliFiltre = 'Tümü';
  String? _seciliUyeId;
  bool _yeniEskiSirala = false;

  final Set<String> _acikTarihler = {};

  final Map<String, Color> _tipRenkleri = {
    'Beslenme': const Color(0xFFFF6B35),
    'Su': const Color(0xFF2196F3),
    'Hijyen': const Color(0xFF00BFA5),
    'Sağlık': const Color(0xFFE53935),
    'İlaç Kullanımı': const Color(0xFF7B1FA2),
  };

  final Map<String, IconData> _tipIkonlari = {
    'Beslenme': Icons.restaurant,
    'Su': Icons.water_drop,
    'Hijyen': Icons.clean_hands,
    'Sağlık': Icons.medical_services,
    'İlaç Kullanımı': Icons.medication,
  };

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;

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
    _hazirlik();
    _gercekZamanliDinlemeyiBaslat();
  }

  void _gercekZamanliDinlemeyiBaslat() {
    _abonelik = _supabase
        .channel('public:aktivite_gunlugu')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'aktivite_gunlugu',
      callback: (payload) {
        debugPrint('Veritabanında değişiklik algılandı, liste güncelleniyor...');
        _akisVerileriniGetir();
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    if (_abonelik != null) {
      _supabase.removeChannel(_abonelik!);
    }
    _animasyonKontrol.dispose();
    super.dispose();
  }

  Future<void> _hazirlik() async {
    try {
      final uyeler = await _supabase
          .from('kullanicilar')
          .select('id, ad_soyad')
          .eq('aile_id', widget.aileId);
      if (mounted) {
        setState(() => _aileUyeleri = List<Map<String, dynamic>>.from(uyeler));
      }
    } catch (e) {
      debugPrint("Üye çekme hatası: $e");
    }
    await _akisVerileriniGetir();
  }

  Future<void> _akisVerileriniGetir() async {
    if (!mounted) return;
    setState(() => _yukleniyor = true);

    try {
      var query = _supabase
          .from('aktivite_gunlugu')
          .select('*, evcil_hayvanlar(ad), kullanicilar(ad_soyad), besin_cesitleri(besin_adi)')
          .eq('aile_id', widget.aileId);

      if (_seciliFiltre == 'Sağlık') {
        query = query.inFilter('aktivite_tipi', ['Sağlık', 'İlaç Kullanımı']);
      } else if (_seciliFiltre != 'Tümü') {
        query = query.ilike('aktivite_tipi', _seciliFiltre);
      }

      if (_seciliUyeId != null) {
        query = query.eq('kullanici_id', _seciliUyeId!);
      }

      final veriler = await query.order('gerceklesme_zamani', ascending: _yeniEskiSirala);

      if (mounted) {
        setState(() => _tumAktiviteler = List<Map<String, dynamic>>.from(veriler));
        _animasyonKontrol.forward(from: 0.0);
      }
    } catch (e) {
      debugPrint('Akış hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _grupla() {
    Map<String, List<Map<String, dynamic>>> gruplar = {};
    for (var aktivite in _tumAktiviteler) {
      if (aktivite['gerceklesme_zamani'] == null) continue;
      try {
        String tarih = DateFormat('yyyy-MM-dd')
            .format(DateTime.parse(aktivite['gerceklesme_zamani']).toLocal());
        if (!gruplar.containsKey(tarih)) gruplar[tarih] = [];
        gruplar[tarih]!.add(aktivite);
      } catch (e) {
        debugPrint("Tarih ayrıştırma hatası: $e");
      }
    }
    return gruplar;
  }

  String _tarihFormatla(String tarih) {
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dun = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    if (tarih == bugun) return 'Bugün';
    if (tarih == dun) return 'Dün';

    try {
      final date = DateTime.parse(tarih);
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    } catch (e) {
      return tarih;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gruplar = _grupla();
    final siraliTarihler = gruplar.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: arkaPlan,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Aile Akışı',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: anaMavi,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _yeniEskiSirala ? Icons.arrow_upward : Icons.arrow_downward,
                  color: vurguRengi,
                  size: 22,
                ),
              ),
              onPressed: () {
                setState(() {
                  _yeniEskiSirala = !_yeniEskiSirala;
                  _akisVerileriniGetir();
                });
              },
              tooltip: _yeniEskiSirala ? 'Eskiden Yeniye' : 'Yeniden Eskiye',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.filter_list,
                  color: vurguRengi,
                  size: 22,
                ),
              ),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              onSelected: (deger) {
                if (deger.startsWith("TIP_")) {
                  setState(() => _seciliFiltre = deger.substring(4));
                } else if (deger.startsWith("UYE_")) {
                  setState(() => _seciliUyeId = deger.substring(4));
                } else if (deger == "TEMIZLE") {
                  setState(() {
                    _seciliFiltre = 'Tümü';
                    _seciliUyeId = null;
                  });
                }
                _akisVerileriniGetir();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "TİP FİLTRESİ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                ...['Tümü', 'Beslenme', 'Su', 'Hijyen', 'Sağlık'].map(
                      (t) => PopupMenuItem(
                    value: "TIP_$t",
                    child: Row(
                      children: [
                        if (t != 'Tümü')
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _tipRenkleri[t] ?? Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (t != 'Tümü') const SizedBox(width: 8),
                        Text(
                          t,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: _seciliFiltre == t
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _seciliFiltre == t ? anaMavi : textGri,
                          ),
                        ),
                        if (_seciliFiltre == t)
                          const Spacer(),
                        if (_seciliFiltre == t)
                          Icon(Icons.check, color: anaMavi, size: 18),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    "ÜYE FİLTRESİ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                ..._aileUyeleri.map(
                      (uye) => PopupMenuItem(
                    value: "UYE_${uye['id']}",
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: anaMavi.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (uye['ad_soyad'] ?? 'B')
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: anaMavi,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          uye['ad_soyad'] ?? 'Bilinmiyor',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: _seciliUyeId == uye['id']
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _seciliUyeId == uye['id']
                                ? anaMavi
                                : textGri,
                          ),
                        ),
                        if (_seciliUyeId == uye['id'])
                          const Spacer(),
                        if (_seciliUyeId == uye['id'])
                          Icon(Icons.check, color: anaMavi, size: 18),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: "TEMIZLE",
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Filtreleri Temizle",
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _akisVerileriniGetir,
        color: anaMavi,
        backgroundColor: Colors.white,
        child: _yukleniyor
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
                'Aile akışı yükleniyor... 🐾',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )
            : _tumAktiviteler.isEmpty
            ? _bosListeTasarimi()
            : FadeTransition(
          opacity: _fadeAnimasyon,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            itemCount: siraliTarihler.length,
            itemBuilder: (context, index) {
              String tarih = siraliTarihler[index];
              String tarihMetni = _tarihFormatla(tarih);
              bool bugunMu = tarih ==
                  DateFormat('yyyy-MM-dd').format(DateTime.now());

              if (bugunMu) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tarihBasligi(tarihMetni, true),
                    const SizedBox(height: 8),
                    ...gruplar[tarih]!.map((a) => _aktiviteKarti(a)),
                    const SizedBox(height: 8),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tarihBasligi(tarihMetni, false),
                  const SizedBox(height: 4),
                  ...gruplar[tarih]!.map((a) => _aktiviteKarti(a)),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tarihBasligi(String tarihMetni, bool bugunMu) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (bugunMu)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [vurguRengi, vurguRengiLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tarihMetni,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: anaMavi,
                  fontSize: 14,
                ),
              ),
            )
          else
            Text(
              tarihMetni,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: textGri,
                fontSize: 14,
              ),
            ),
          if (!bugunMu) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
            ),
          ],
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
              Icons.notifications_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz aktivite yok 🐾',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçili kriterlerde etkinlik bulunamadı.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          if (_seciliFiltre != 'Tümü' || _seciliUyeId != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _seciliFiltre = 'Tümü';
                  _seciliUyeId = null;
                });
                _akisVerileriniGetir();
              },
              icon: Icon(Icons.clear_all, color: anaMavi),
              label: Text(
                'Filtreleri Temizle',
                style: GoogleFonts.poppins(
                  color: anaMavi,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: anaMavi.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aktiviteKarti(Map<String, dynamic> aktivite) {
    String tip = aktivite['aktivite_tipi'] ?? 'İşlem';
    Color kartRengi = _tipRenkleri[tip] ?? Colors.grey;
    IconData ikon = _tipIkonlari[tip] ?? Icons.circle;
    String hayvanAdi = aktivite['evcil_hayvanlar']?['ad'] ?? 'Pati';
    String yapan = aktivite['kullanicilar']?['ad_soyad'] ?? 'Biri';

    // Veritabanındaki detay verilerini çekiyoruz
    String islemDetayi = aktivite['islem_detayi']?.toString() ?? '';

    // ⭐ DÜZELTME: Eski kayıtlardan gelen karmaşık UUID kodlarını gizleme kontrolü
    bool hashMi = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(islemDetayi);
    if (hashMi) {
      islemDetayi = ''; // Eğer hash ise boşaltıyoruz ki aşağıda varsayılan düzgün yazı atansın
    }

    var miktarRaw = aktivite['miktar_numerik'];
    String miktar = '';
    if (miktarRaw != null) {
      double m = double.tryParse(miktarRaw.toString()) ?? 0;
      miktar = m == m.toInt() ? m.toInt().toString() : m.toString();
    }

    String birim = aktivite['olcu_birimi']?.toString() ?? '';
    String besinAdi = aktivite['besin_cesitleri']?['besin_adi'] ?? '';

    String detay = '';

    // Aktivite Tipine Göre Detay Oluşturma Mantığı
    switch (tip) {
      case 'Beslenme':
        if (miktar.isNotEmpty) {
          detay = '$miktar $birim $besinAdi'.trim();
          if (!detay.endsWith('verildi')) detay += ' verildi';
        } else {
          detay = islemDetayi.isNotEmpty ? islemDetayi : 'Beslenme takibi yapıldı';
        }
        break;
      case 'Su':
        if (miktar.isNotEmpty) {
          detay = '$miktar $birim su verildi'.trim();
        } else {
          detay = islemDetayi.isNotEmpty ? islemDetayi : 'Su takibi yapıldı';
        }
        break;
      case 'Hijyen':
      case 'Sağlık':
      case 'İlaç Kullanımı':
        detay = islemDetayi.isNotEmpty ? islemDetayi : '$tip takibi yapıldı';
        break;
      default:
        detay = islemDetayi.isNotEmpty ? islemDetayi : 'Aktivite takibi yapıldı';
    }

    String saat = DateFormat('HH:mm')
        .format(DateTime.parse(aktivite['gerceklesme_zamani']).toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kartRengi.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    ikon,
                    color: kartRengi,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hayvanAdi,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: anaMavi,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kartRengi.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tip,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: kartRengi,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: textGri,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            yapan,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: anaMavi,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: textGri.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              detay,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: textGri,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    saat,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textGri,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}