import '../repositories/receipt_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/promo_code_repository.dart';

class ReceiptService {
  final ReceiptRepository receiptRepository;
  final MembershipRepository membershipRepository;
  final PromoCodeRepository promoCodeRepository;

  ReceiptService(
    this.receiptRepository,
    this.membershipRepository,
    this.promoCodeRepository,
  );

  Future<List<Map<String, dynamic>>> getByUserId(int userId) async {
    return await receiptRepository.getReceiptsByUserId(userId);
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    return await receiptRepository.getReceiptById(id);
  }

  Future<Map<String, dynamic>> createReceipt(Map<String, dynamic> data) async {
    // 1. Validate basic required fields
    final requiredFields = ['user_id', 'membershipId', 'paymentMethod'];
    for (var field in requiredFields) {
      if (data[field] == null) {
        throw Exception('Field "$field" is required');
      }
    }

    // 2. Fetch Membership price
    final membershipId = data['membershipId'];
    final membership = await membershipRepository.getMembershipById(membershipId);
    if (membership == null) {
      throw Exception('Membership with ID $membershipId not found');
    }
    double total = (membership['price'] as num).toDouble();

    // 3. Apply Promo Code if provided
    if (data['promoCodeId'] != null) {
      final promoId = data['promoCodeId'];
      final promo = await promoCodeRepository.getPromoCodeById(promoId);
      
      if (promo == null) {
        throw Exception('Promo code with ID $promoId not found');
      }
      
      if (promo['Expired'] == true) {
        throw Exception('Promo code has expired');
      }

      // Calculate: total = price * sales
      final double sales = (promo['sales'] as num).toDouble();
      total = total * sales;
    }

    // 4. Set the calculated total
    data['total'] = total;

    return await receiptRepository.createReceipt(data);
  }

  Future<Map<String, dynamic>> markAsPaid(int id) async {
    return await receiptRepository.updatePaymentStatus(id, true);
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async {
    data.remove('id');
    
    if (data.containsKey('total') && data['total'] < 0) {
      throw Exception('Total cannot be negative');
    }

    return await receiptRepository.updateReceipt(id, data);
  }

  Future<void> cleanupExpiredReceipts() async {
    await receiptRepository.deleteExpiredUnpaidReceipts();
  }
}
