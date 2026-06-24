import '../repositories/membership_repository.dart';

class MembershipService {
  final MembershipRepository membershipRepository;

  MembershipService(this.membershipRepository);

  Future<List<Map<String, dynamic>>> getAllMemberships() async {
    return await membershipRepository.getAllMemberships();
  }

  Future<Map<String, dynamic>?> getMembershipById(int id) async {
    return await membershipRepository.getMembershipById(id);
  }

  Future<Map<String, dynamic>> createMembership(Map<String, dynamic> data) async {
    // Validate required fields from Transaction.txt
    final requiredFields = ['Duration', 'membershipRank', 'price', 'maxFlashcardSet'];
    
    for (var field in requiredFields) {
      if (data[field] == null) {
        throw Exception('Field "$field" is required');
      }
    }

    if (data['price'] < 0) {
      throw Exception('Price cannot be negative');
    }

    if (data['maxFlashcardSet'] < 0) {
      throw Exception('maxFlashcardSet cannot be negative');
    }

    if (data['Duration'] is! int) {
      throw Exception('Duration must be an integer');
    }

    if (data['Duration'] <= 0) {
      throw Exception('Duration must be greater than zero');
    }

    return await membershipRepository.createMembership(data);
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async {
    // Prevent updating the ID
    data.remove('id');

    if (data.containsKey('price') && data['price'] < 0) {
      throw Exception('Invalid price');
    }
    if (data.containsKey('maxFlashcardSet') && data['maxFlashcardSet'] < 0) {
      throw Exception('Invalid max flashcard set');
    }
    if (data.containsKey('Duration')) {
      if (data['Duration'] is! int || data['Duration'] <= 0) {
        throw Exception('Duration must be an integer greater than zero');
      }
    }
    return await membershipRepository.updateMembership(id, data);
  }

  Future<Map<String, dynamic>> toggleActiveStatus(int id) async {
    final membership = await membershipRepository.getMembershipById(id);
    if (membership == null) {
      throw Exception('Membership not found');
    }

    final bool currentStatus = membership['isActive'] ?? true;
    return await membershipRepository.updateMembership(id, {
      'isActive': !currentStatus,
    });
  }
}
