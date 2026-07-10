import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Tarih formatlamaları için eklendi

import '../../beslenme/ekranlar/beslenme_takip_paneli.dart';
import '../../su/ekranlar/su_takip_paneli.dart';
import '../../hijyen/ekranlar/hijyen_takip_paneli.dart';
import '../../saglik/ekranlar/saglik_takip_paneli.dart';
import '../../../cekirdek/servisler/storage_servisi.dart';

class HayvanProfilPaneli extends StatefulWidget {
  final Map<String, dynamic> hayvanVerisi;

  const HayvanProfilPaneli({Key? key, required this.hayvanVerisi})
      : super(key: key);

  @override
  _HayvanProfilPaneliDurumu createState() => _HayvanProfilPaneliDurumu();
}

class _HayvanProfilPaneliDurumu extends State<HayvanProfilPaneli>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final StorageServisi _storageServisi = StorageServisi();

  // Modern renk paleti 💙💛
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  late Map<String, dynamic> _hayvanBilgisi;
  String? _profilFotoUrl;
  bool _fotoYukleniyor = false;
  late AnimationController _animasyonKontrol;
  late Animation<double> _olcekAnimasyon;

  @override
  void initState() {
    super.initState();
    _hayvanBilgisi = Map<String, dynamic>.from(widget.hayvanVerisi);
    _profilFotoUrl = _hayvanBilgisi['profil_foto_url'];

    _animasyonKontrol = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _olcekAnimasyon = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );
    _animasyonKontrol.forward();
  }

  @override
  void dispose() {
    _animasyonKontrol.dispose();
    super.dispose();
  }

  String _yasHesapla(String? tarihMetni) {
    if (tarihMetni == null) return "Bilinmiyor";
    try {
      final dogumTarihi = DateTime.parse(tarihMetni);
      final bugun = DateTime.now();
      int yasYil = bugun.year - dogumTarihi.year;
      int yasAy = bugun.month - dogumTarihi.month;

      if (yasAy < 0) {
        yasYil--;
        yasAy += 12;
      }

      if (yasYil > 0) {
        return "$yasYil Yıl $yasAy Ay";
      } else {
        return "$yasAy Aylık";
      }
    } catch (e) {
      return "Geçersiz Tarih";
    }
  }

  // --- ANI KÖŞESİ İŞLEMLERİ (YENİ EKLENDİ) ---
  Future<void> _ayrilisDurumunuGuncelle(String yeniDurum, DateTime tarih) async {
    try {
      await _supabase.from('evcil_hayvanlar').update({
        'durum': yeniDurum,
        'ayrilis_tarihi': tarih.toIso8601String(),
      }).eq('id', _hayvanBilgisi['id']);

      if (mounted) {
        setState(() {
          _hayvanBilgisi['durum'] = yeniDurum;
          _hayvanBilgisi['ayrilis_tarihi'] = tarih.toIso8601String();
          widget.hayvanVerisi['durum'] = yeniDurum;
          widget.hayvanVerisi['ayrilis_tarihi'] = tarih.toIso8601String();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(yeniDurum == 'Aktif'
                ? 'Durum normale çevrildi.'
                : 'Kayıt başarıyla anı köşesine taşındığı için dostumuz hep kalbimizde.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Durum güncelleme hatası: $e');
    }
  }

  void _ayrilisBildirimiGoster() {
    String seciliDurum = 'Vefat';
    DateTime seciliTarih = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Ayrılış Bildir',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: anaMavi),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dostunuzu kaybettiğiniz veya aramızdan ayrıldığı tarihi işaretleyerek onun anısını daima yaşatabilirsiniz.',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Vefat', label: Text('Melek Oldu')),
                      ButtonSegment(value: 'Kayıp', label: Text('Kayboldu')),
                    ],
                    selected: {seciliDurum},
                    onSelectionChanged: (Set<String> yeniSecim) {
                      setDialogState(() => seciliDurum = yeniSecim.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Tarih Seçin'),
                    subtitle: Text(DateFormat('dd MMMM yyyy', 'tr_TR').format(seciliTarih)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final tarih = await showDatePicker(
                        context: context,
                        initialDate: seciliTarih,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (tarih != null) {
                        setDialogState(() => seciliTarih = tarih);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: anaMavi),
                  onPressed: () {
                    Navigator.pop(context);
                    _ayrilisDurumunuGuncelle(seciliDurum, seciliTarih);
                  },
                  child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // ------------------------------------------

  Future<void> _profilFotografiDegistir(ImageSource kaynak) async {
    try {
      final secilenDosya = await _storageServisi.fotografSec(kaynak);
      if (secilenDosya == null) return;

      setState(() => _fotoYukleniyor = true);

      final hayvanId = _hayvanBilgisi['id'];
      final url = await _storageServisi.profilFotografiYukle(
          secilenDosya, 'hayvan_$hayvanId');

      if (url != null) {
        await _supabase
            .from('evcil_hayvanlar')
            .update({'profil_foto_url': url})
            .eq('id', hayvanId);

        if (mounted) {
          setState(() {
            _profilFotoUrl = url;
            _hayvanBilgisi['profil_foto_url'] = url;
            widget.hayvanVerisi['profil_foto_url'] = url;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🐾 Profil fotoğrafı güncellendi!'),
              backgroundColor: anaMavi,
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

  void _duzenlemeFormunuAc() {
    final adKontrolcusu = TextEditingController(text: _hayvanBilgisi['ad']);
    final turKontrolcusu = TextEditingController(text: _hayvanBilgisi['tur']);
    final irkKontrolcusu = TextEditingController(text: _hayvanBilgisi['irk']);
    final mikrocipKontrolcusu =
    TextEditingController(text: _hayvanBilgisi['mikrocip_no']?.toString() ?? '');

    String seciliCinsiyet = _hayvanBilgisi['cinsiyet'] ?? 'Belirtilmemiş';
    bool kronikHastalikVarMi = _hayvanBilgisi['kronik_hastalik_var_mi'] == true;
    DateTime? seciliDogumTarihi = _hayvanBilgisi['dogum_tarihi'] != null
        ? DateTime.parse(_hayvanBilgisi['dogum_tarihi'])
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext altBaglam) {
        return StatefulBuilder(
          builder: (BuildContext formBaglami, StateSetter formSetState) {
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
                bottom: MediaQuery.of(altBaglam).viewInsets.bottom,
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
                          'Pati Bilgilerini Güncelle',
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

                    _modernTextField(
                      controller: adKontrolcusu,
                      label: 'Pati Adı',
                      icon: Icons.pets,
                    ),
                    const SizedBox(height: 16),

                    _modernTextField(
                      controller: turKontrolcusu,
                      label: 'Tür',
                      icon: Icons.category,
                    ),
                    const SizedBox(height: 16),

                    _modernTextField(
                      controller: irkKontrolcusu,
                      label: 'Irk',
                      icon: Icons.biotech,
                    ),
                    const SizedBox(height: 16),

                    _modernTextField(
                      controller: mikrocipKontrolcusu,
                      label: 'Mikroçip Numarası',
                      icon: Icons.memory,
                      keyboardType: TextInputType.number,
                      optional: true,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: ['Dişi', 'Erkek', 'Belirtilmemiş']
                            .contains(seciliCinsiyet)
                            ? seciliCinsiyet
                            : 'Belirtilmemiş',
                        items: ['Dişi', 'Erkek', 'Belirtilmemiş'].map((cins) {
                          return DropdownMenuItem(
                            value: cins,
                            child: Row(
                              children: [
                                Icon(
                                  cins == 'Dişi'
                                      ? Icons.female
                                      : cins == 'Erkek'
                                      ? Icons.male
                                      : Icons.help_outline,
                                  color: anaMaviLight,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(cins),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (yeniCinsiyet) {
                          formSetState(() => seciliCinsiyet = yeniCinsiyet!);
                        },
                        decoration: InputDecoration(
                          labelText: 'Cinsiyet',
                          labelStyle: TextStyle(color: textGri),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          'Doğum Tarihi',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textGri,
                          ),
                        ),
                        subtitle: Text(
                          seciliDogumTarihi != null
                              ? "${seciliDogumTarihi!.day}.${seciliDogumTarihi!.month}.${seciliDogumTarihi!.year}"
                              : "Seçilmedi",
                          style: TextStyle(
                            color: seciliDogumTarihi != null ? anaMavi : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: anaMavi.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.calendar_month, color: anaMavi),
                        ),
                        onTap: () async {
                          DateTime? secilen = await showDatePicker(
                            context: context,
                            initialDate: seciliDogumTarihi ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (secilen != null) {
                            formSetState(() => seciliDogumTarihi = secilen);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: Row(
                          children: [
                            Icon(Icons.health_and_safety,
                                color: kronikHastalikVarMi ? Colors.red : textGri),
                            const SizedBox(width: 8),
                            Text(
                              'Kronik Hastalık / Alerji',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textGri,
                              ),
                            ),
                          ],
                        ),
                        value: kronikHastalikVarMi,
                        activeColor: anaMavi,
                        inactiveThumbColor: Colors.grey.shade400,
                        onChanged: (deger) {
                          formSetState(() => kronikHastalikVarMi = deger);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        if (adKontrolcusu.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Lütfen pati adını giriniz'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(altBaglam);
                        setState(() => _fotoYukleniyor = true);

                        try {
                          final guncelVeri = {
                            'ad': adKontrolcusu.text.trim(),
                            'tur': turKontrolcusu.text.trim(),
                            'irk': irkKontrolcusu.text.trim(),
                            'mikrocip_no': mikrocipKontrolcusu.text.trim().isEmpty
                                ? null
                                : mikrocipKontrolcusu.text.trim(),
                            'cinsiyet': seciliCinsiyet,
                            'kronik_hastalik_var_mi': kronikHastalikVarMi,
                            'dogum_tarihi': seciliDogumTarihi?.toIso8601String(),
                          };

                          await _supabase
                              .from('evcil_hayvanlar')
                              .update(guncelVeri)
                              .eq('id', _hayvanBilgisi['id']);

                          if (mounted) {
                            setState(() {
                              _hayvanBilgisi.addAll(guncelVeri);
                              widget.hayvanVerisi.addAll(guncelVeri);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('✅ Pati bilgileri güncellendi!'),
                                backgroundColor: Colors.green.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        } catch (hata) {
                          debugPrint('Veri güncelleme hatası: $hata');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('⚠️ Güncelleme sırasında hata oluştu.'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _fotoYukleniyor = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: anaMavi,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
      },
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool optional = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: optional ? '$label (Opsiyonel)' : label,
          labelStyle: TextStyle(color: textGri),
          prefixIcon: Icon(icon, color: anaMaviLight, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
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

  // --- ANI KÖŞESİ WIDGET'I (YENİ EKLENDİ) ---
  Widget _aniKosesiTasarimi() {
    String durum = _hayvanBilgisi['durum'] ?? 'Aktif';
    String? tarihString = _hayvanBilgisi['ayrilis_tarihi'];

    if (durum == 'Aktif' || tarihString == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: TextButton.icon(
          onPressed: _ayrilisBildirimiGoster,
          icon: Icon(Icons.favorite_border, color: Colors.grey.shade400),
          label: Text(
            'Anı Köşesine Taşı',
            style: GoogleFonts.poppins(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    DateTime ayrilisTarihi = DateTime.parse(tarihString);
    bool vefatMi = durum == 'Vefat';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vefatMi
              ? [Colors.grey.shade800, Colors.grey.shade900]
              : [const Color(0xFF1A237E).withOpacity(0.8), const Color(0xFF1A237E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            vefatMi ? Icons.pets : Icons.search_off,
            color: const Color(0xFFFFC107),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            vefatMi ? 'Hatırası Hep Bizimle' : 'Umudumuz Hep Seninle',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('d MMMM yyyy', 'tr_TR').format(ayrilisTarihi)} tarihinden beri anılarımızda...',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _ayrilisDurumunuGuncelle('Aktif', DateTime.now()),
            icon: const Icon(Icons.undo, color: Colors.white54, size: 16),
            label: const Text('Geri Al', style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        ],
      ),
    );
  }
  // -----------------------------------------

  @override
  Widget build(BuildContext context) {
    final ad = _hayvanBilgisi['ad'] ?? 'İsimsiz';
    final tur = _hayvanBilgisi['tur'] ?? 'Belirtilmemiş';
    final irk = _hayvanBilgisi['irk'] ?? 'Belirtilmemiş';
    final cinsiyet = _hayvanBilgisi['cinsiyet'] ?? 'Belirtilmemiş';
    final yasMetni = _yasHesapla(_hayvanBilgisi['dogum_tarihi']);
    final mikrocipNo = _hayvanBilgisi['mikrocip_no'];
    final kronikHastalik = _hayvanBilgisi['kronik_hastalik_var_mi'] == true;

    bool vefatMi = _hayvanBilgisi['durum'] == 'Vefat';

    // Fotoğraf tasarımı siyah beyaz filtresi
    Widget profilFotografi = CircleAvatar(
      radius: 70,
      backgroundColor: kartBeyazi,
      backgroundImage:
      _profilFotoUrl != null ? NetworkImage(_profilFotoUrl!) : null,
      child: _profilFotoUrl == null && !_fotoYukleniyor
          ? Icon(Icons.pets, size: 50, color: vurguRengi)
          : null,
    );

    if (vefatMi) {
      profilFotografi = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: profilFotografi,
      );
    }

    return AnimatedBuilder(
      animation: _olcekAnimasyon,
      builder: (context, child) {
        return Transform.scale(
          scale: _olcekAnimasyon.value,
          child: Scaffold(
            backgroundColor: arkaPlan,
            appBar: AppBar(
              title: Text(
                ad,
                style: GoogleFonts.poppins(
                  color: kartBeyazi,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              backgroundColor: anaMavi,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: vurguRengi.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_note, color: vurguRengi, size: 24),
                    ),
                    onPressed: _duzenlemeFormunuAc,
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                        child: profilFotografi, // Yeni filtreli fotoğrafımız burada kullanılıyor
                      ),
                      if (_fotoYukleniyor)
                        Container(
                          width: 140,
                          height: 140,
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: anaMavi,
                              shape: BoxShape.circle,
                              border: Border.all(color: kartBeyazi, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: anaMavi.withOpacity(0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: kartBeyazi,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // İsim ve Rozet
                  Column(
                    children: [
                      Text(
                        ad,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: anaMavi,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [vurguRengi, vurguRengiLight],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$tur · $irk',
                          style: GoogleFonts.poppins(
                            color: anaMavi,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bilgi Kartı
                  Container(
                    decoration: BoxDecoration(
                      color: kartBeyazi,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          _modernBilgiSatiri(
                            Icons.transgender,
                            'Cinsiyet',
                            cinsiyet,
                            iconColor: cinsiyet == 'Dişi'
                                ? Colors.pink.shade400
                                : cinsiyet == 'Erkek'
                                ? Colors.blue.shade400
                                : Colors.grey,
                          ),
                          _modernBilgiSatiri(
                            Icons.cake,
                            'Yaş',
                            yasMetni,
                            iconColor: Colors.orange.shade400,
                          ),
                          if (mikrocipNo != null && mikrocipNo.toString().isNotEmpty)
                            _modernBilgiSatiri(
                              Icons.memory,
                              'Mikroçip No',
                              mikrocipNo.toString(),
                              iconColor: Colors.purple.shade400,
                            ),
                          if (kronikHastalik)
                            _modernBilgiSatiri(
                              Icons.warning_amber_rounded,
                              'Sağlık Durumu',
                              '⚠️ Kronik Hastalık / Alerji',
                              iconColor: Colors.red.shade400,
                              isWarning: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Kategori Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _modernKategoriKarti(
                        context,
                        'Beslenme',
                        Icons.restaurant,
                        Colors.green.shade50,
                        Colors.green.shade700,
                        BeslenmeTakipPaneli(hayvanVerisi: _hayvanBilgisi),
                      ),
                      _modernKategoriKarti(
                        context,
                        'Su',
                        Icons.water_drop,
                        Colors.blue.shade50,
                        Colors.blue.shade700,
                        SuTakipPaneli(hayvanVerisi: _hayvanBilgisi),
                      ),
                      _modernKategoriKarti(
                        context,
                        'Hijyen',
                        Icons.clean_hands,
                        Colors.purple.shade50,
                        Colors.purple.shade700,
                        HijyenTakipPaneli(hayvanVerisi: _hayvanBilgisi),
                      ),
                      _modernKategoriKarti(
                        context,
                        'Sağlık',
                        Icons.medical_services,
                        Colors.red.shade50,
                        Colors.red.shade700,
                        SaglikTakipPaneli(hayvanVerisi: _hayvanBilgisi),
                      ),
                    ],
                  ),

                  // ANI KÖŞESİ EKLENTİSİ BURADA
                  _aniKosesiTasarimi(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _modernBilgiSatiri(
      IconData ikon,
      String baslik,
      String deger, {
        Color? iconColor,
        bool isWarning = false,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? vurguRengi).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, color: iconColor ?? vurguRengi, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 12,
                    color: textGri,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deger,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isWarning ? FontWeight.w600 : FontWeight.w500,
                    color: isWarning ? Colors.red.shade600 : anaMavi,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernKategoriKarti(
      BuildContext baglam,
      String baslik,
      IconData ikon,
      Color renk,
      Color ikonRengi,
      Widget hedefSayfa,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            baglam,
            MaterialPageRoute(builder: (context) => hedefSayfa),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: renk,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ikonRengi.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ikon,
                  size: 36,
                  color: ikonRengi,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                baslik,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: anaMavi,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 3,
                decoration: BoxDecoration(
                  color: ikonRengi.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}