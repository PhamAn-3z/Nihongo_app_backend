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

  Future<Map<String, dynamic>> fullBulkImport({
    required dynamic userId,
    required Map<String, dynamic> payload,
  }) async {
    return await bulkImportCreateDeck(
      userId: userId,
      title: payload['deckTitle'],
      publicStatus: payload['publicStatus'] ?? 'private',
      parentId: payload['parentId'],
      headers: List<Map<String, dynamic>>.from(payload['headers']),
      rows: List<Map<String, dynamic>>.from(payload['rows']),
    );
  }

  Future<List<dynamic>> getAllDecks() async {
    return await _deckRepository.getAllDecks();
  }

  Future<List<Map<String, dynamic>>> getUserDecksTree(dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    final now = DateTime.now();
    
    final List<dynamic> rawData = await _deckRepository.getUserDecks(formattedUserId);
    
    // Bước 1: Làm phẳng và tính toán thông số Anki + Author cho từng Deck
    List<Map<String, dynamic>> processedList = [];
    
    for (var item in rawData) {
      final deck = item['decks'];
      if (deck == null) continue;

      final authorData = deck['author'] as Map<String, dynamic>?;
      
      // Lấy profile từ mảng lồng nhau (Nâng cao null-safety)
      final profiles = authorData?['user_profiles'];
      final authorProfile = (profiles is List && profiles.isNotEmpty) ? profiles[0] : null;
      
      final positions = deck['positions'];
      final List<dynamic> positionsList = (positions is List) ? positions : [];

      // Tính toán thông số Anki
      int newCount = 0;
      int learningCount = 0;
      int dueCount = 0;

      for (var pos in positionsList) {
        final upData = pos['users_positions'];
        final List<dynamic> upList = (upData is List) ? upData : [];
        
        // Lọc đúng bản ghi của người đang học
        Map<String, dynamic>? up;
        try {
          up = upList.firstWhere(
            (u) => u['user_id'] == formattedUserId, 
            orElse: () => null
          );
        } catch (_) {
          up = null;
        }

        if (up == null) {
          continue;
        }

        final String status = up['status']?.toString() ?? 'NEW';
        final String? nextReviewStr = up['next_review']?.toString();

        if (status == 'NEW') {
          newCount++;
        } else if (status == 'LEARNING') {
          learningCount++;
        } else if (status == 'REVIEW') {
          if (nextReviewStr != null && nextReviewStr.isNotEmpty) {
            try {
              final nextReview = DateTime.parse(nextReviewStr);
              if (nextReview.isBefore(now)) {
                dueCount++;
              }
            } catch (e) {
              print('⚠️ Error parsing date $nextReviewStr: $e');
            }
          }
        }
      }

      processedList.add({
        'deckId': deck['deck_id'],
        'title': deck['title'] ?? 'Không tiêu đề',
        'parentId': deck['parent_id'],
        'publicStatus': deck['public_status'] ?? 'private',
        'isFavorite': item['is_favorite'] ?? false,
        'lastStudiedAt': item['last_studied_at'],
        'author': {
          'username': authorData?['username'] ?? 'Ẩn danh',
          'avatarUrl': authorProfile?['avatar_url']
        },
        'ankiStats': {
          'newCount': newCount,
          'learningCount': learningCount,
          'dueCount': dueCount,
        },
        'subDecks': <Map<String, dynamic>>[]
      });
    }

    // Bước 2: Dựng cây phân cấp (Tree Algorithm)
    Map<int, Map<String, dynamic>> deckMap = {};
    for (var deck in processedList) {
      deckMap[deck['deckId']] = deck;
    }
    
    List<Map<String, dynamic>> rootDecks = [];

    for (var deck in processedList) {
      final parentId = deck['parentId'];
      if (parentId != null && deckMap.containsKey(parentId)) {
        // Đảm bảo không tự lồng vào chính mình để tránh đệ quy vô tận
        if (parentId != deck['deckId']) {
          deckMap[parentId]!['subDecks'].add(deck);
        } else {
          rootDecks.add(deck);
        }
      } else {
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

  Future<List<Map<String, dynamic>>> getDeckComments(int deckId, dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    
    final List<dynamic> rawComments = await _deckRepository.getDeckComments(deckId);

    return rawComments.map((item) {
      final List<dynamic> likes = item['comment_likes'] ?? [];
      final user = item['users'] ?? {};
      // Lấy profile từ mảng (Supabase trả về mảng cho quan hệ 1-1 nếu không dùng single)
      final profile = (user['user_profiles'] is List && (user['user_profiles'] as List).isNotEmpty)
          ? user['user_profiles'][0]
          : (user['user_profiles'] ?? {});

      return {
        'id': item['comment_id'],
        'parentId': item['parent_comment_id'],
        'content': item['content'],
        'createdAt': item['created_at'],
        'username': user['username'] ?? 'Người dùng',
        'avatarUrl': profile['avatar_url'], // Sẽ trả về null nếu không có ảnh, khớp với DB của bạn
        'totalLikes': likes.length,
        'isLikedByMe': likes.any((l) => l['user_id'] == formattedUserId),
      };
    }).toList();
  }

  Future<Map<String, dynamic>> addComment({
    required int deckId,
    required dynamic userId,
    int? parentCommentId,
    required String content,
  }) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    
    // Bước 1: Validate nội dung (trim)
    if (content.trim().isEmpty) {
      throw Exception('Nội dung bình luận không được để trống!');
    }

    // Bước 2 & 3: Gọi repository để kiểm tra parent và insert
    return await _deckRepository.addComment(
      deckId: deckId,
      userId: formattedUserId,
      parentCommentId: parentCommentId,
      content: content,
    );
  }

  Future<void> deleteComment({
    required int commentId,
    required dynamic userId,
  }) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;

    // Bước 1: Kiểm tra comment tồn tại
    final comment = await _deckRepository.getCommentById(commentId);
    if (comment == null) {
      throw Exception('Bình luận không tồn tại hoặc đã bị xóa trước đó!');
    }

    final int deckId = comment['deck_id'];
    final int commentAuthorId = comment['user_id'];

    // Bước 2: Lấy thông tin chủ sở hữu bộ đề
    final deckOwnerId = await _deckRepository.getDeckOwnerId(deckId);

    // Bước 3: Kiểm tra quyền xóa (Author của comment HOẶC Owner của deck)
    if (formattedUserId != commentAuthorId && formattedUserId != deckOwnerId) {
      throw Exception('FORBIDDEN: Bạn không có quyền xóa bình luận này!');
    }

    // Bước 4: Xóa
    await _deckRepository.deleteComment(commentId);
  }

  Future<List<Map<String, dynamic>>> getExploreDecks({
    String? search,
    String sortBy = 'trending',
    int page = 1,
    int limit = 10,
  }) async {
    final rawData = await _deckRepository.getExploreDecks(
      search: search,
      sortBy: sortBy,
      page: page,
      limit: limit,
    );

    // Chuyển đổi dữ liệu thô sang định dạng sạch hơn (Xử lý linh hoạt Map/List cho profiles)
    return rawData.map((deck) {
      final authorData = deck['author'] as Map<String, dynamic>?;
      final profiles = authorData?['user_profiles'];
      
      Map<String, dynamic>? authorProfile;
      if (profiles is List && profiles.isNotEmpty) {
        authorProfile = profiles[0] as Map<String, dynamic>;
      } else if (profiles is Map) {
        authorProfile = Map<String, dynamic>.from(profiles);
      }

      return {
        'deckId': deck['deck_id'],
        'title': deck['title'],
        'createdAt': deck['created_at'],
        'viewCount': deck['view_count'] ?? 0,
        'activeLearnersToday': deck['active_learners_today'] ?? 0,
        'author': {
          'username': authorData?['username'] ?? 'Ẩn danh',
          'avatarUrl': authorProfile?['avatar_url'],
        },
      };
    }).toList();
  }

  Future<void> saveDeckLink({
    required dynamic userId,
    required int deckId,
  }) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    
    await _deckRepository.saveDeckLink(
      userId: formattedUserId,
      deckId: deckId,
    );
  }
}
