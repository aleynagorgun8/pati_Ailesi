import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AileSohbetPaneli extends StatefulWidget {
  const AileSohbetPaneli({super.key});

  @override
  State<AileSohbetPaneli> createState() => _AileSohbetPaneliDurumu();
}

class _AileSohbetPaneliDurumu extends State<AileSohbetPaneli> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _mesajKontrolcusu = TextEditingController();
  final ScrollController _kaydirmaKontrolcusu = ScrollController();

  final Color anaMavi = const Color(0xFF1A237E);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color arkaPlan = const Color(0xFFF8F9FA);

  String? _gecerliKullaniciId;
  String? _gecerliAileId;
  bool _bilgilerYukleniyor = true;

  final Map<String, Map<String, dynamic>> _aileUyeleriSozlugu = {};
  final Set<String> _anlikSilinenMesajlar = {};

  @override
  void initState() {
    super.initState();
    _baslangicVerileriniGetir();
  }

  @override
  void dispose() {
    _mesajKontrolcusu.dispose();
    _kaydirmaKontrolcusu.dispose();
    super.dispose();
  }

  Future<void> _baslangicVerileriniGetir() async {
    try {
      _gecerliKullaniciId = _supabase.auth.currentUser?.id;
      if (_gecerliKullaniciId == null) return;

      final kullaniciVerisi = await _supabase
          .from('kullanicilar')
          .select('aile_id')
          .eq('id', _gecerliKullaniciId!)
          .maybeSingle();

      if (kullaniciVerisi != null && kullaniciVerisi['aile_id'] != null) {
        _gecerliAileId = kullaniciVerisi['aile_id'];

        final uyelerVerisi = await _supabase
            .from('kullanicilar')
            .select('id, ad_soyad, profil_foto_url')
            .eq('aile_id', _gecerliAileId!);

        for (var uye in uyelerVerisi) {
          _aileUyeleriSozlugu[uye['id']] = {
            'ad_soyad': uye['ad_soyad'],
            'profil_foto_url': uye['profil_foto_url'],
          };
        }
      }
    } catch (e) {
      debugPrint('Sohbet verileri yüklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() {
          _bilgilerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _mesajGonder() async {
    final metin = _mesajKontrolcusu.text.trim();
    if (metin.isEmpty || _gecerliAileId == null || _gecerliKullaniciId == null) return;
    _mesajKontrolcusu.clear();

    try {
      await _supabase.from('aile_mesajlari').insert({
        'aile_id': _gecerliAileId,
        'gonderen_id': _gecerliKullaniciId,
        'mesaj_metni': metin,
        'okuyanlar': [_gecerliKullaniciId],
      });
    } catch (e) {
      debugPrint('Mesaj gönderme hatası: $e');
    }
  }

  void _mesajSilmeIletisimi(String mesajId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text('Mesajı Sil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red.shade400)),
          ],
        ),
        content: Text('Bu mesajı herkes için silmek istediğine emin misin?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('İptal', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() { _anlikSilinenMesajlar.add(mesajId); });
              try {
                await _supabase.from('aile_mesajlari').delete().eq('id', mesajId);
              } catch (e) {
                setState(() { _anlikSilinenMesajlar.remove(mesajId); });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _mesajiOkunduOlarakIsaretle(Map<String, dynamic> mesaj) async {
    final gonderenId = mesaj['gonderen_id'];
    List okuyanlar = List.from(mesaj['okuyanlar'] ?? []);
    if (gonderenId != _gecerliKullaniciId && !okuyanlar.contains(_gecerliKullaniciId)) {
      okuyanlar.add(_gecerliKullaniciId);
      await _supabase.from('aile_mesajlari').update({'okuyanlar': okuyanlar}).eq('id', mesaj['id']);
    }
  }

  Widget _mesajBalonuTasarimi(Map<String, dynamic> mesaj) {
    final bool benimMesajim = mesaj['gonderen_id'] == _gecerliKullaniciId;
    final gonderenBilgisi = _aileUyeleriSozlugu[mesaj['gonderen_id']] ?? {};
    final String gonderenAdi = gonderenBilgisi['ad_soyad'] ?? 'Bilinmeyen Kullanıcı';
    final String kisaAd = gonderenAdi.isNotEmpty ? gonderenAdi[0].toUpperCase() : 'U';
    final String? profilFotoUrl = gonderenBilgisi['profil_foto_url'];

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mesajiOkunduOlarakIsaretle(mesaj);
    });

    DateTime olusturulmaZamani = DateTime.parse(mesaj['olusturulma_tarihi']).toLocal();
    String saatFormatli = DateFormat('HH:mm').format(olusturulmaZamani);
    List okuyanlarDizisi = mesaj['okuyanlar'] ?? [];
    final bool herkesOkudu = okuyanlarDizisi.length >= _aileUyeleriSozlugu.length && (_aileUyeleriSozlugu.length > 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        mainAxisAlignment: benimMesajim ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!benimMesajim) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: profilFotoUrl != null ? NetworkImage(profilFotoUrl) : null,
              child: profilFotoUrl == null ? Text(kisaAd, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: anaMavi)) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: benimMesajim ? () => _mesajSilmeIletisimi(mesaj['id']) : null,
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: benimMesajim ? anaMavi : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                    bottomLeft: benimMesajim ? const Radius.circular(20) : Radius.zero,
                    bottomRight: benimMesajim ? Radius.zero : const Radius.circular(20),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: benimMesajim ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!benimMesajim) Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text(gonderenAdi, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: vurguRengi))),
                    Text(mesaj['mesaj_metni'] ?? '', style: GoogleFonts.poppins(fontSize: 14, color: benimMesajim ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(saatFormatli, style: GoogleFonts.poppins(fontSize: 10, color: benimMesajim ? Colors.white70 : Colors.grey.shade500)),
                        if (benimMesajim) ...[const SizedBox(width: 4), Icon(herkesOkudu ? Icons.done_all : Icons.done, size: 14, color: herkesOkudu ? Colors.blue.shade300 : Colors.white54)],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bilgilerYukleniyor) return Scaffold(backgroundColor: arkaPlan, body: Center(child: CircularProgressIndicator(color: vurguRengi)));
    if (_gecerliAileId == null) return Scaffold(backgroundColor: arkaPlan, body: Center(child: Text('Aileye katılmalısın.', style: GoogleFonts.poppins())));

    return Scaffold(
      backgroundColor: arkaPlan,
      appBar: AppBar(title: Text('Aile Sohbeti', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)), backgroundColor: anaMavi, centerTitle: true, elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('aile_mesajlari').stream(primaryKey: ['id']).eq('aile_id', _gecerliAileId!).order('olusturulma_tarihi', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final mesajlar = (snapshot.data ?? []).where((m) => !_anlikSilinenMesajlar.contains(m['id'])).toList();
                return ListView.builder(controller: _kaydirmaKontrolcusu, reverse: true, itemCount: mesajlar.length, itemBuilder: (context, index) => _mesajBalonuTasarimi(mesajlar[index]));
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(left: 12, right: 12, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)]),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
                    child: TextField(
                      controller: _mesajKontrolcusu,
                      decoration: const InputDecoration(hintText: 'Mesaj yaz...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(onTap: _mesajGonder, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: vurguRengi, shape: BoxShape.circle), child: Icon(Icons.send, color: anaMavi, size: 22))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}