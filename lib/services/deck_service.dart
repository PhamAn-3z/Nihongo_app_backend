import '../repositories/deck_repository.dart';

class DeckService {
  final DeckRepository _deckRepository;

  DeckService(this._deckRepository);

  Future<Map<String, dynamic>> bulkImportCreateDeck({
    required dynamic userId,
    required String title,
    required String publicStatus,
    int? parentId,
    required List<Map<String, dynamic>> headers,
    required List<Map<String, dynamic>> rows,
  }) async {
    // Ép kiểu userId về int nếu nó là String (do JWT payload thường là String)
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;

    return await _deckRepository.bulkImportCreateDeck(
      userId: formattedUserId,
      title: title,
      publicStatus: publicStatus,
      parentId: parentId,
      headers: headers,
      rows: rows,
    );
  }

  Future<List<dynamic>> getAllDecks() async {
    return await _deckRepository.getAllDecks();
  }

  Future<List<Map<String, dynamic>>> getUserDecksTree(dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    
    final flatList = await _deckRepository.getUserDecks(formattedUserId);
    
    // Thuật toán dựng cây (Tree Building Algorithm)
    Map<int, Map<String, dynamic>> deckMap = {};
    List<Map<String, dynamic>> rootDecks = [];

    // Bước 1: Khởi tạo Map và danh sách subDecks trống
    for (var deck in flatList) {
      deck['subDecks'] = [];
      deckMap[deck['deckId']] = deck;
    }

    // Bước 2: Liên kết con vào cha
    for (var deck in flatList) {
      final parentId = deck['parentId'];
      if (parentId != null && deckMap.containsKey(parentId)) {
        deckMap[parentId]!['subDecks'].add(deck);
      } else {
        // Nếu không có parent hoặc parent không nằm trong danh sách sở hữu của user
        // (Trường hợp này hiếm nhưng vẫn có thể xảy ra nếu dữ liệu lỗi)
        rootDecks.add(deck);
      }
    }

    return rootDecks;
  }

  Future<Map<String, dynamic>> getDeckStudyData(int deckId, dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;

    final rawData = await _deckRepository.getDeckStudyData(deckId, formattedUserId);

    // 1. Định dạng lại personalizedHeaders
    final List<dynamic> groups = rawData['groups'];
    final personalizedHeaders = groups.map((g) {
      final List<dynamic> usersGroups = g['users_groups'] ?? [];
      return {
        'groupId': g['group_id'],
        'groupName': g['group_name'],
        'physicalPosition': g['position'],
        'personalizedRank': usersGroups.isNotEmpty ? usersGroups[0]['rank'] : 'M'
      };
    }).toList();

    // Sắp xếp headers theo rank (Lexicographical)
    personalizedHeaders.sort((a, b) => (a['personalizedRank'] as String).compareTo(b['personalizedRank'] as String));

    // 2. Định dạng lại flashcards
    final List<dynamic> positions = rawData['positions'];
    final flashcards = positions.map((p) {
      final List<dynamic> usersPositions = p['users_positions'] ?? [];
      final Map<String, dynamic> studyState = usersPositions.isNotEmpty 
          ? usersPositions[0] 
          : {
              'status': 'NEW',
              'ease_factor': 2.5,
              'interval': 0,
              'review_count': 0,
              'next_review': DateTime.now().toIso8601String(),
            };

      return {
        'positionId': p['position_id'],
        'colIndex': p['col_index'],
        'studyState': {
          'status': studyState['status'],
          'easeFactor': studyState['ease_factor'],
          'interval': studyState['interval'],
          'reviewCount': studyState['review_count'],
          'nextReview': studyState['next_review'] ?? DateTime.now().toIso8601String(),
        },
        'cardData': (p['terms'] as List).map((t) => {
          'termId': t['term_id'],
          'groupId': t['group_id'],
          'content': t['content']
        }).toList(),
      };
    }).toList();

    // Sắp xếp flashcards theo thuật toán Anki (Review -> Learning -> New)
    flashcards.sort((a, b) {
      int getPriority(String status) {
        if (status == 'REVIEW') return 1;
        if (status == 'LEARNING') return 2;
        return 3;
      }
      
      final pA = getPriority(a['studyState']['status']);
      final pB = getPriority(b['studyState']['status']);
      
      if (pA != pB) return pA.compareTo(pB);
      
      // Nếu cùng status, so sánh nextReview
      final nextA = DateTime.parse(a['studyState']['nextReview']);
      final nextB = DateTime.parse(b['studyState']['nextReview']);
      return nextA.compareTo(nextB);
    });

    return {
      'deckId': rawData['deckId'],
      'title': rawData['title'],
      'userId': rawData['userId'],
      'personalizedHeaders': personalizedHeaders,
      'flashcards': flashcards,
    };
  }

  Future<void> deleteDeck(int deckId, dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.deleteDeck(deckId, formattedUserId);
  }

  Future<void> setFavoriteStatus(int deckId, dynamic userId, bool isFavorite) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.updateFavoriteStatus(deckId, formattedUserId, isFavorite);
  }
}
