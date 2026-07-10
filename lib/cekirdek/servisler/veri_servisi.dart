import 'package:supabase_flutter/supabase_flutter.dart';

class VeriServisi {
  
  
  final _supabase = Supabase.instance.client;

  
  
  
  
  
  Future<List<Map<String, dynamic>>> evcilHayvanlariGetir(String aileId) async {
    try {
      
      
      final veriler = await _supabase
          .from('evcil_hayvanlar')
          .select()
          .eq('aile_id', aileId);

      
      return veriler;
    } catch (hata) {
      
      
      print('Evcil hayvanları çekerken hata oluştu: $hata');
      return []; 
    }
  }

  
  
  
  
  
  
  Future<void> aktiviteEkle({
    required String hayvanId,
    required String kullaniciId,
    required String aktiviteTipi, 
    double? miktar,               
    String? islemDetayi,          
  }) async {
    try {
      
      await _supabase.from('aktivite_gunlugu').insert({
        'hayvan_id': hayvanId,
        'kullanici_id': kullaniciId,
        'aktivite_tipi': aktiviteTipi,
        'miktar_numerik': miktar,
        'islem_detayi': islemDetayi,
      });
      print('Aktivite başarıyla veritabanına kaydedildi!');
    } catch (hata) {
      print('Aktivite eklenirken hata oluştu: $hata');
    }
  }
}