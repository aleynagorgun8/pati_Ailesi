import 'package:supabase_flutter/supabase_flutter.dart';

class VeriServisi {
  // Supabase istemcisine (client) sınıfın her yerinden kolayca erişmek için
  // gizli (private) bir değişken tanımlıyoruz.
  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------
  // 1. EVCİL HAYVANLARI GETİRME FONKSİYONU
  // ---------------------------------------------------------
  // Veritabanından belirli bir aileye ait evcil hayvanların listesini çeker.
  // İnternet işlemi olduğu için asenkron (Future ve async) olarak çalışır.
  Future<List<Map<String, dynamic>>> evcilHayvanlariGetir(String aileId) async {
    try {
      // 'evcil_hayvanlar' tablosuna gidiyoruz ve 'aile_id' sütunu
      // bizim fonksiyona gönderdiğimiz aileId ile eşleşen satırları seçiyoruz (select).
      final veriler = await _supabase
          .from('evcil_hayvanlar')
          .select()
          .eq('aile_id', aileId);

      // Çekilen verileri geri döndürüyoruz.
      return veriler;
    } catch (hata) {
      // Olası bir bağlantı veya yetki hatasında programın çökmemesi için
      // try-catch bloğu kullanıyoruz ve hatayı konsola yazdırıyoruz.
      print('Evcil hayvanları çekerken hata oluştu: $hata');
      return []; // Hata durumunda ekrana boş bir liste gönderiyoruz.
    }
  }

  // ---------------------------------------------------------
  // 2. YENİ AKTİVİTE (BESLENME/HİYJEN) EKLEME FONKSİYONU
  // ---------------------------------------------------------
  // Hayvan beslendiğinde, su verildiğinde veya kumu temizlendiğinde bu fonksiyon çağrılacak.
  // miktar ve islemDetayi parametreleri opsiyoneldir (köşeli parantez veya süslü parantez ile yapılabilir,
  // burada isimli opsiyonel parametre kullandık).
  Future<void> aktiviteEkle({
    required String hayvanId,
    required String kullaniciId,
    required String aktiviteTipi, // Örn: 'beslenme', 'su', 'hijyen'
    double? miktar,               // Gr veya Ml cinsinden (Opsiyonel)
    String? islemDetayi,          // Örn: 'Kum temizlendi' (Opsiyonel)
  }) async {
    try {
      // 'aktivite_gunlugu' tablosuna yeni bir satır (insert) ekliyoruz.
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