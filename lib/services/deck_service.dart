import 'package:flashcard_quiz_backend/repositories/user_stats_repository.dart';

import '../repositories/deck_repository.dart';

class DeckService {
  final DeckRepository _deckRepository;
  final UserStatsRepository _userStatsRepository;

  DeckService(this._deckRepository, this._userStatsRepository);

  /// Kiểm tra giới hạn số lượng bộ đề dựa trên gói Membership
  Future<void> _checkMembershipLimit(int userId) async {
    final userStats = await _userStatsRepository.getUserStatsWithMembership(userId);

    if (userStats != null && userStats['Membership'] != null) {
      final membership = userStats['Membership'];
      final int maxDecks = int.tryParse(membership['maxFlashcardSet']?.toString() ?? '') ?? 0;

      // Nếu maxDecks > 0, thực hiện kiểm tra số lượng hiện tại
      if (maxDecks > 0) {
        final int currentDecks = await _deckRepository.countUserCreatedDecks(userId);
        if (currentDecks >= maxDecks) {
          throw Exception('Bạn đã đạt giới hạn tối đa ($maxDecks bộ đề) của gói thành viên hiện tại. Vui lòng nâng cấp để tạo thêm!');
        }
      }
    }
  }

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

    // 1. Kiểm tra giới hạn Membership trước khi tạo
    await _checkMembershipLimit(formattedUserId);

    // 2. Thực hiện tạo bộ đề
    return await _deckRepository.bulkImportCreateDeck(
      userId: formattedUserId,
      title: title,
      publicStatus: publicStatus,
      parentId: parentId,
      headers: headers,
      rows: rows,
    );
  }

  Future<List<Map<String, dynamic>>> getExploreDecks({
    String? searchTerm,
    int page = 1,
    int limit = 10,
    String sortBy = 'created_at',
    bool ascending = false,
    int? currentUserId,
    String filter = 'all', // all, not_in_library, in_library
  }) async {
    // Gọi repo lấy dữ liệu
    final List<dynamic> rawData = await _deckRepository.getExploreDecks(
      searchTerm: searchTerm,
      page: page,
      limit: limit,
      sortBy: sortBy,
      ascending: ascending,
      currentUserId: currentUserId,
    );

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    var processedList = rawData.map((item) {
      final authorData = item['author'] as Map<String, dynamic>?;

      // Lấy profile
      final profilesRaw = authorData?['user_profiles'];
      Map<String, dynamic>? authorProfile;
      if (profilesRaw is List && profilesRaw.isNotEmpty) {
        authorProfile = profilesRaw[0] as Map<String, dynamic>;
      } else if (profilesRaw is Map) {
        authorProfile = Map<String, dynamic>.from(profilesRaw);
      }

      // Tính toán thông số thẻ và Anki Stats
      final List<dynamic> positions = item['positions'] ?? [];
      final int cardCount = positions.length;

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

        // Lọc đúng bản ghi của người đang xem (nếu có đăng nhập)
        final up = currentUserId == null
            ? null
            : upList.firstWhere((u) => u['user_id'] == currentUserId, orElse: () => null);

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

      // Đếm số người yêu thích và kiểm tra xem đã có trong thư viện chưa
      final List<dynamic> userDecks = item['user_decks'] ?? [];
      final int favoritesCount = userDecks.where((ud) => ud['is_favorite'] == true).length;

      final bool isInLibrary = currentUserId != null &&
          userDecks.any((ud) => ud['user_id'] == currentUserId);

      // Thống kê lượt xem (study logs)
      final List<dynamic> studyLogs = item['flashcard_study_logs'] ?? [];

      // Lấy tổng lượt xem từ thuộc tính total_views vừa thêm ở Repo
      final List<dynamic> totalViewsRaw = item['total_views'] ?? [];
      final int totalViews = totalViewsRaw.isNotEmpty ? totalViewsRaw[0]['count'] : studyLogs.length;

      final int viewsToday = studyLogs.where((log) {
        final String? studiedAt = log['studied_at'];
        return studiedAt != null && studiedAt.startsWith(todayStr);
      }).length;

      return {
        'deckId': item['deck_id'],
        'title': item['title'],
        'createdAt': item['created_at'],
        'publicStatus': item['public_status'],
        'isInLibrary': isInLibrary,
        'author': {
          'username': authorData?['username'] ?? 'Ẩn danh',
          'avatarUrl': authorProfile?['avatar_url']
        },
        'totalCards': cardCount,
        'ankiStats': {
          'newCount': newCount,
          'learningCount': learningCount,
          'dueCount': dueCount,
        },
        'stats': {
          'favoritesCount': favoritesCount,
          'totalViews': totalViews,
          'viewsToday': viewsToday,
        }
      };
    }).toList();

    // Bước 1: Lọc dữ liệu (Filtering)
    if (currentUserId != null) {
      if (filter == 'not_in_library') {
        processedList = processedList.where((d) => d['isInLibrary'] == false).toList();
      } else if (filter == 'in_library') {
        processedList = processedList.where((d) => d['isInLibrary'] == true).toList();
      }
    }

    // Bước 2: Sắp xếp (Sorting)
    // Nếu sortBy không phải là trường của DB, ta sắp xếp tại đây
    final dbSortableFields = ['created_at', 'title'];
    if (!dbSortableFields.contains(sortBy)) {
      processedList.sort((a, b) {
        dynamic valA;
        dynamic valB;

        if (sortBy == 'favorites') {
          valA = a['stats']['favoritesCount'];
          valB = b['stats']['favoritesCount'];
        } else if (sortBy == 'views') {
          valA = a['stats']['totalViews'];
          valB = b['stats']['totalViews'];
        } else if (sortBy == 'views_today') {
          valA = a['stats']['viewsToday'];
          valB = b['stats']['viewsToday'];
        } else if (sortBy == 'in_library') {
          valA = a['isInLibrary'] ? 1 : 0;
          valB = b['isInLibrary'] ? 1 : 0;
        } else {
          return 0;
        }

        return ascending ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    }

    // Bước 3: Phân trang (Pagination) - Luôn thực hiện ở Service nếu có Filter hoặc Custom Sort
    if (!dbSortableFields.contains(sortBy) || filter != 'all') {
      final int start = (page - 1) * limit;
      if (start >= processedList.length) return [];
      final int end = (start + limit) > processedList.length ? processedList.length : (start + limit);
      processedList = processedList.sublist(start, end);
    }

    return processedList;
  }

  /// Lấy thông tin giới hạn và số lượng bộ đề hiện tại của user
  Future<Map<String, dynamic>> getUserMembershipLimit(dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;

    final userStats = await _userStatsRepository.getUserStatsWithMembership(formattedUserId);
    final int currentDecks = await _deckRepository.countUserCreatedDecks(formattedUserId);

    int maxDecks = 0;
    String membershipName = 'N/A';

    if (userStats != null && userStats['Membership'] != null) {
      final membership = userStats['Membership'];
      maxDecks = int.tryParse(membership['maxFlashcardSet']?.toString() ?? '') ?? 0;
      membershipName = membership['membershipRank'] ?? 'Free';
    }

    return {
      'membershipName': membershipName,
      'currentDecks': currentDecks,
      'maxDecks': maxDecks,
      'canCreateMore': maxDecks == 0 || currentDecks < maxDecks,
    };
  }

  /// Đếm số lượng bộ đề của một người dùng (Dùng cho logic nội bộ)
  Future<int> countUserDecks(dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    return await _deckRepository.countUserCreatedDecks(formattedUserId);
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
        'totalCards': positions.length, // Bổ sung trường này
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
        // 'ZZ' đảm bảo những nhóm không được gán Rank sẽ luôn nằm ở cuối danh sách từ điển
        'personalizedRank': usersGroups.isNotEmpty ? usersGroups[0]['rank'] : 'ZZ'
      };
    }).toList();

    // Sắp xếp theo thứ tự từ điển (Lexicographical) ổn định
    personalizedHeaders.sort((a, b) {
      int cmp = (a['personalizedRank'] as String).compareTo(b['personalizedRank'] as String);
      if (cmp != 0) return cmp;
      // Nếu Rank bằng nhau (cùng là ZZ), sắp xếp theo vị trí vật lý ban đầu
      return (a['physicalPosition'] as int).compareTo(b['physicalPosition'] as int);
    });

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

  Future<void> updateCardContent({
    required dynamic userId,
    required int deckId,
    required int positionId,
    List<Map<String, dynamic>>? headers,
    List<Map<String, dynamic>>? terms,
  }) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;

    await _deckRepository.updateCardContent(
      userId: formattedUserId,
      deckId: deckId,
      positionId: positionId,
      headers: headers,
      terms: terms,
    );
  }

  Future<void> resetDeckProgress({
    required dynamic userId,
    required int deckId,
  }) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.resetDeckProgress(formattedUserId, deckId);
  }

  Future<void> setFavoriteStatus(int deckId, dynamic userId, bool isFavorite) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.updateFavoriteStatus(deckId, formattedUserId, isFavorite);
  }

  Future<void> updatePersonalizedRanks(int deckId, dynamic userId, List<Map<String, dynamic>> ranks) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.updatePersonalizedRanks(formattedUserId, ranks);
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

  Future<List<Map<String, dynamic>>> getRecentlyViewedDecks(dynamic userId, {int limit = 10}) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    final now = DateTime.now();

    final List<dynamic> rawData = await _deckRepository.getRecentlyViewedDecks(formattedUserId, limit: limit);

    // Bước 1: Lọc duy nhất deck_id (vì một deck có thể có nhiều log học tập)
    final Map<int, Map<String, dynamic>> uniqueDecks = {};

    for (var item in rawData) {
      final deckData = item['decks'];
      if (deckData == null) continue;

      final int deckId = deckData['deck_id'];
      if (!uniqueDecks.containsKey(deckId)) {
        uniqueDecks[deckId] = item;
      }

      // Dừng lại nếu đã đủ limit sau khi lọc unique
      if (uniqueDecks.length >= limit) break;
    }

    // Bước 2: Xử lý dữ liệu và tính toán Anki Stats
    return uniqueDecks.values.map((item) {
      final deck = item['decks'] as Map<String, dynamic>;
      final authorData = deck['author'] as Map<String, dynamic>?;

      // Lấy profile author
      final profilesRaw = authorData?['user_profiles'];
      Map<String, dynamic>? authorProfile;
      if (profilesRaw is List && profilesRaw.isNotEmpty) {
        authorProfile = profilesRaw[0] as Map<String, dynamic>;
      } else if (profilesRaw is Map) {
        authorProfile = Map<String, dynamic>.from(profilesRaw);
      }

      // Tính toán Anki Stats
      final List<dynamic> positions = deck['positions'] ?? [];
      int newCount = 0;
      int learningCount = 0;
      int dueCount = 0;

      for (var pos in positions) {
        final upRaw = pos['users_positions'];
        List<dynamic> upList = (upRaw is List) ? upRaw : (upRaw != null ? [upRaw] : []);

        final up = upList.firstWhere((u) => u['user_id'] == formattedUserId, orElse: () => null);

        if (up == null) {
          newCount++;
          continue;
        }

        final String status = up['status'] ?? 'NEW';
        if (status == 'NEW') newCount++;
        else if (status == 'LEARNING') learningCount++;
        else if (status == 'REVIEW') {
          final String? nextReviewStr = up['next_review'];
          if (nextReviewStr != null && DateTime.parse(nextReviewStr).isBefore(now)) {
            dueCount++;
          }
        }
      }

      // Kiểm tra trạng thái yêu thích từ bảng user_decks (nếu có)
      final List<dynamic> userDecksList = deck['user_decks'] ?? [];
      final userDeck = userDecksList.firstWhere(
        (ud) => ud['user_id'] == formattedUserId,
        orElse: () => null
      );

      return {
        'deckId': deck['deck_id'],
        'title': deck['title'],
        'lastStudiedAt': item['studied_at'],
        'isFavorite': userDeck != null ? (userDeck['is_favorite'] ?? false) : false,
        'authorName': authorData?['username'] ?? 'Ẩn danh',
        'authorAvatar': authorProfile?['avatar_url'],
        'totalCards': positions.length,
        'newCount': newCount,
        'learningCount': learningCount,
        'dueCount': dueCount,
        'lastSession': {
          'learned': item['cards_learned'] ?? 0,
          'reviewed': item['cards_reviewed'] ?? 0,
          'seconds': item['duration_seconds'] ?? 0,
        }
      };
    }).toList();
  }

  Future<void> saveDeckToLibrary(int deckId, dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.saveDeckToLibrary(formattedUserId, deckId);
  }

  Future<void> unsaveDeck(int deckId, dynamic userId) async {
    final int formattedUserId = userId is String ? int.parse(userId) : userId as int;
    await _deckRepository.unsaveDeck(formattedUserId, deckId);
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
