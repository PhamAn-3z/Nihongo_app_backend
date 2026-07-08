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
    final now = DateTime.now();
    
    final List<dynamic> rawData = await _deckRepository.getUserDecks(formattedUserId);
    
    // Bước 1: Làm phẳng và tính toán thông số Anki + Author cho từng Deck
    List<Map<String, dynamic>> processedList = rawData.map((item) {
      final deck = item['decks'] as Map<String, dynamic>;
      final authorData = deck['author'] as Map<String, dynamic>?;
      
      // Lấy profile - Xử lý linh hoạt cả List và Map
      final profilesRaw = authorData?['user_profiles'];
      Map<String, dynamic>? authorProfile;
      if (profilesRaw is List && profilesRaw.isNotEmpty) {
        authorProfile = profilesRaw[0] as Map<String, dynamic>;
      } else if (profilesRaw is Map) {
        authorProfile = Map<String, dynamic>.from(profilesRaw);
      }
      
      final positionsRaw = deck['positions'];
      final List<dynamic> positions = (positionsRaw is List) ? positionsRaw : [];

      // Tính toán thông số Anki
      int newCount = 0;
      int learningCount = 0;
      int dueCount = 0;

      for (var pos in positions) {
        final upRaw = pos['users_positions'];
        List<dynamic> upList = [];
        if (upRaw is List) {
          upList = upRaw;
        } else if (upRaw is Map) {
          upList = [upRaw];
        }

        // Lọc đúng bản ghi của người đang học
        final up = upList.firstWhere(
          (u) => u['user_id'] == formattedUserId, 
          orElse: () => null
        );

        // 🌟 SỬA LỖI: Nếu người dùng chưa bao giờ học thẻ này (chưa có record users_positions)
        // thì mặc định coi đây là thẻ MỚI (newCount).
        if (up == null) {
          newCount++;
          continue;
        }

        final String status = up['status'] ?? 'NEW';
        final String? nextReviewStr = up['next_review'];

        if (status == 'NEW') {
          newCount++;
        } else if (status == 'LEARNING') {
          learningCount++;
        } else if (status == 'REVIEW') {
          if (nextReviewStr != null) {
            final nextReview = DateTime.parse(nextReviewStr);
            if (nextReview.isBefore(now)) {
              dueCount++;
            }
          }
        }
      }

      return {
        'deckId': deck['deck_id'],
        'title': deck['title'],
        'parentId': deck['parent_id'],
        'publicStatus': deck['public_status'],
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
      };
    }).toList();

    // Bước 2: Dựng cây phân cấp (Tree Algorithm)
    Map<int, Map<String, dynamic>> deckMap = {
      for (var deck in processedList) deck['deckId']: deck
    };
    
    List<Map<String, dynamic>> rootDecks = [];

    for (var deck in processedList) {
      final parentId = deck['parentId'];
      if (parentId != null && deckMap.containsKey(parentId)) {
        deckMap[parentId]!['subDecks'].add(deck);
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

    // 3. Sắp xếp flashcards theo thuật toán ưu tiên Anki:
    // Ưu tiên 1: Trạng thái (REVIEW > LEARNING > NEW)
    // Ưu tiên 2: Thời gian hẹn gặp lại (Cái nào quá hạn lâu hơn xếp trước)
    // Ưu tiên 3: Vị trí gốc (col_index)
    flashcards.sort((a, b) {
      int getStatusPriority(String status) {
        switch (status) {
          case 'REVIEW': return 1;
          case 'LEARNING': return 2;
          case 'NEW': return 3;
          default: return 4;
        }
      }
      
      final stateA = a['studyState'];
      final stateB = b['studyState'];

      // So sánh theo mức độ ưu tiên trạng thái
      int priorityA = getStatusPriority(stateA['status']);
      int priorityB = getStatusPriority(stateB['status']);
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      // Nếu cùng trạng thái, so sánh theo ngày hẹn (nextReview)
      // Những thẻ có nextReview nhỏ hơn (quá hạn lâu hơn) sẽ hiện lên trước
      DateTime dateA = DateTime.parse(stateA['nextReview']);
      DateTime dateB = DateTime.parse(stateB['nextReview']);
      
      if (dateA != dateB) {
        return dateA.compareTo(dateB);
      }

      // Cuối cùng là so sánh theo vị trí sắp xếp gốc của bộ bài
      return (a['colIndex'] as int).compareTo(b['colIndex'] as int);
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
}
