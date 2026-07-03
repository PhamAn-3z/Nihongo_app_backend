import '../repositories/promo_code_repository.dart';

class PromoCodeService {
  final PromoCodeRepository promoCodeRepository;

  PromoCodeService(this.promoCodeRepository);

  Future<Map<String, dynamic>?> getByCode(String code) async {
    return await promoCodeRepository.getPromoCodeByCode(code);
  }

  Future<List<Map<String, dynamic>>> getActivePromoCodes() async {
    return await promoCodeRepository.getActivePromoCodes();
  }

  Future<List<Map<String, dynamic>>> getAllPromoCodes() async {
    return await promoCodeRepository.getAllPromoCodes();
  }

  Future<Map<String, dynamic>?> createPromoCode(Map<String, dynamic> data) async {
    // Validate required fields from Transaction.txt
    final requiredFields = ['sales', 'dayExpired'];
    
    for (var field in requiredFields) {
      if (data[field] == null) {
        throw Exception('Field "$field" is required');
      }
    }

    return await promoCodeRepository.createPromoCode(data);
  }

  Future<Map<String, dynamic>?> update(int id, Map<String, dynamic> data) async {
    data.remove('id');
    return await promoCodeRepository.updatePromoCode(id, data);
  }

  Future<Map<String, dynamic>?> toggleExpiredStatus(int id) async {
    final promo = await promoCodeRepository.getPromoCodeById(id);
    if (promo == null) {
      throw Exception('Promo code not found');
    }

    final bool currentStatus = promo['Expired'] ?? false;
    return await promoCodeRepository.updatePromoCode(id, {
      'Expired': !currentStatus,
    });
  }
}
