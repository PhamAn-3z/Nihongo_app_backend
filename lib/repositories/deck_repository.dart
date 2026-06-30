import 'package:supabase/supabase.dart';

class DeckRepository {
  final SupabaseClient _client;

  DeckRepository(this._client);

  Future<Map<String, dynamic>> bulkImportCreateDeck({
    required dynamic userId,
    required String title,
    required String publicStatus,
    int? parentId,
    required List<Map<String, dynamic>> headers,
    required List<Map<String, dynamic>> rows,
  }) async {
    try {
      // Bước 1: INSERT vào bảng decks
      final deckResponse = await _client.from('decks').insert({
        'user_id': userId,
        'title': title,
        'public_status': publicStatus,
        'parent_id': parentId,
      }).select().single();

      final int deckId = deckResponse['deck_id'];

      // Bước 2: INSERT vào bảng user_decks
      await _client.from('user_decks').insert({
        'user_id': userId,
        'deck_id': deckId,
        'is_favorite': false,
        'last_studied_at': DateTime.now().toIso8601String(),
      });

      // Bước 3: INSERT vào bảng groups (Headers)
      final List<Map<String, dynamic>> groupsToInsert = headers.map((h) => {
        'deck_id': deckId,
        'group_name': h['name'],
        'position': h['position'],
      }).toList();

      final List<dynamic> groupsResponse = await _client.from('groups').insert(groupsToInsert).select();
      
      // Map key từ payload với group_id vừa tạo
      // Giả định thứ tự trả về khớp với thứ tự insert hoặc dựa vào group_name/position
      Map<String, int> groupMap = {};
      for (var i = 0; i < headers.length; i++) {
        final key = headers[i]['key'];
        final groupName = headers[i]['name'];
        final group = groupsResponse.firstWhere((g) => g['group_name'] == groupName);
        groupMap[key] = group['group_id'];
      }

      // Bước 4: INSERT vào bảng users_groups (Lexicographical rank)
      final List<Map<String, dynamic>> usersGroupsToInsert = [];
      for (var i = 0; i < groupsResponse.length; i++) {
        usersGroupsToInsert.add({
          'user_id': userId,
          'group_id': groupsResponse[i]['group_id'],
          'rank': String.fromCharCode(65 + i), // 'A', 'B', 'C'...
        });
      }
      await _client.from('users_groups').insert(usersGroupsToInsert);

      // Bước 5: INSERT vào bảng positions (Mỗi row là một position/thẻ)
      final List<Map<String, dynamic>> positionsToInsert = [];
      for (var i = 0; i < rows.length; i++) {
        positionsToInsert.add({
          'deck_id': deckId,
          'col_index': i + 1,
        });
      }
      final List<dynamic> positionsResponse = await _client.from('positions').insert(positionsToInsert).select();
      // Sắp xếp lại positionsResponse theo col_index để đảm bảo thứ tự
      positionsResponse.sort((a, b) => (a['col_index'] as int).compareTo(b['col_index'] as int));

      // Bước 6: INSERT vào bảng terms và users_positions
      final List<Map<String, dynamic>> termsToInsert = [];
      final List<Map<String, dynamic>> usersPositionsToInsert = [];

      for (var i = 0; i < rows.length; i++) {
        final positionId = positionsResponse[i]['position_id'];
        final rowData = rows[i];

        // Tạo terms cho từng group trong row
        groupMap.forEach((key, groupId) {
          if (rowData.containsKey(key)) {
            final dynamic value = rowData[key];
            Map<String, dynamic> contentNode;

            // Xử lý linh hoạt dựa trên kiểu dữ liệu gửi lên
            if (value is Map) {
              // TRƯỜNG HỢP 1: Frontend gửi Object đầy đủ {"text": "...", "image_url": "...", "audio_url": "..."}
              contentNode = {
                'text': value['text']?.toString() ?? '',
                'image_url': value['image_url']?.toString(),
                'audio_url': value['audio_url']?.toString(),
              };
            } else if (value is String) {
              final String valStr = value.trim();
              
              // TRƯỜNG HỢP 2: Nhận diện link thông minh
              final bool isAudio = valStr.contains('r2.dev') || valStr.toLowerCase().endsWith('.mp3');
              final bool isImage = valStr.contains('cloudinary.com') || valStr.toLowerCase().endsWith('.jpg');

              if (isAudio) {
                contentNode = {'text': '', 'audio_url': valStr, 'image_url': null};
              } else if (isImage) {
                contentNode = {'text': '', 'audio_url': null, 'image_url': valStr};
              } else {
                contentNode = {'text': valStr, 'audio_url': null, 'image_url': null};
              }
            } else {
              contentNode = {'text': value?.toString() ?? '', 'audio_url': null, 'image_url': null};
            }

            termsToInsert.add({
              'group_id': groupId,
              'position_id': positionId,
              'content': contentNode,
            });
          }
        });

        // Tạo trạng thái ghi nhớ mặc định cho user
        usersPositionsToInsert.add({
          'user_id': userId,
          'position_id': positionId,
          'status': 'NEW',
          'ease_factor': 2.5,
          'interval': 0,
          'review_count': 0,
          'next_review': DateTime.now().toIso8601String(),
        });
      }

      // Bulk insert terms và users_positions
      await Future.wait([
        _client.from('terms').insert(termsToInsert),
        _client.from('users_positions').insert(usersPositionsToInsert),
      ]);

      return {
        'deckId': deckId,
        'title': title,
        'totalCardsImported': rows.length,
      };
    } catch (e) {
      // Trong thực tế, nếu lỗi ở bước nào đó, bạn cần logic xóa các dữ liệu đã tạo (Rollback thủ công)
      // hoặc sử dụng Stored Procedure để DB tự rollback.
      rethrow;
    }
  }

  Future<List<dynamic>> getAllDecks() async {
    return await _client.from('decks').select();
  }

  Future<List<Map<String, dynamic>>> getUserDecks(int userId) async {
    try {
      // Truy vấn bốc toàn bộ thông tin Deck, Author và dữ liệu SM-2 của người học
      // 🌟 SỬA LỖI: Chỉ định rõ foreign key 'decks_user_id_fkey' để lấy tác giả (owner)
      // vì giữa decks và users có nhiều hơn một mối quan hệ (FK trực tiếp và qua bảng trung gian).
      final response = await _client
          .from('user_decks')
          .select('''
            is_favorite,
            last_studied_at,
            decks (
              deck_id,
              title,
              parent_id,
              public_status,
              author:users!decks_user_id_fkey (
                username,
                user_profiles (avatar_url)
              ),
              positions (
                position_id,
                users_positions (
                  user_id,
                  status,
                  next_review
                )
              )
            )
          ''')
          .eq('user_id', userId);

      if (response == null) return [];
      
      // Chuyển đổi an toàn sang List<Map>
      return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('❌ Repository Error in getUserDecks: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDeckStudyData(int deckId, int userId) async {
    // Luồng 1: Lấy Headers (groups) kèm rank cá nhân hóa
    final groupsResponse = await _client
        .from('groups')
        .select('group_id, group_name, position, users_groups(rank)')
        .eq('deck_id', deckId)
        .eq('users_groups.user_id', userId);

    // Luồng 2: Lấy Thẻ (positions), nội dung (terms) và SM-2
    // Lưu ý: Ta lấy toàn bộ positions của deck, filter users_positions theo userId
    final positionsResponse = await _client
        .from('positions')
        .select('''
          position_id, 
          col_index, 
          users_positions(status, ease_factor, interval, review_count, next_review),
          terms(term_id, group_id, content)
        ''')
        .eq('deck_id', deckId)
        .eq('users_positions.user_id', userId);

    // Lấy thông tin cơ bản của Deck
    final deckInfo = await _client.from('decks').select('title').eq('deck_id', deckId).single();

    return {
      'deckId': deckId,
      'title': deckInfo['title'],
      'userId': userId,
      'groups': groupsResponse,
      'positions': positionsResponse,
    };
  }

  Future<void> deleteDeck(int deckId, int userId) async {
    // Thực hiện xóa deck. Do đã cấu hình ON DELETE CASCADE nên các bảng liên quan sẽ tự động bị xóa.
    // Kiểm tra thêm user_id để đảm bảo chỉ chủ sở hữu mới có quyền xóa.
    final response = await _client
        .from('decks')
        .delete()
        .eq('deck_id', deckId)
        .eq('user_id', userId)
        .select();

    if ((response as List).isEmpty) {
      throw Exception('Không tìm thấy bộ đề hoặc bạn không có quyền xóa bộ đề này.');
    }
  }

  Future<void> updateFavoriteStatus(int deckId, int userId, bool isFavorite) async {
    // Sử dụng UPDATE để đánh dấu yêu thích
    // Bắt buộc bản ghi phải tồn tại trong user_decks (nghĩa là user đã lưu hoặc là chủ sở hữu)
    final response = await _client
        .from('user_decks')
        .update({'is_favorite': isFavorite})
        .eq('user_id', userId)
        .eq('deck_id', deckId)
        .select();

    if ((response as List).isEmpty) {
      throw Exception('Hành động không hợp lệ! Bạn phải lưu bộ đề này vào thư viện trước khi đánh dấu yêu thích.');
    }
  }

  Future<List<dynamic>> getDeckComments(int deckId) async {
    // Lồng user_profiles vào trong users để tránh lỗi alias cột
    final response = await _client
        .from('deck_comments')
        .select('''
          comment_id,
          content,
          created_at,
          user_id,
          parent_comment_id,
          users:user_id (
            username,
            user_profiles (avatar_url)
          ),
          comment_likes (user_id)
        ''')
        .eq('deck_id', deckId)
        .order('created_at', ascending: false);

    return response as List<dynamic>;
  }

  Future<Map<String, dynamic>> addComment({
    required int deckId,
    required int userId,
    int? parentCommentId,
    required String content,
  }) async {
    // Nếu có parentCommentId, kiểm tra sự tồn tại của nó
    if (parentCommentId != null) {
      final parentCheck = await _client
          .from('deck_comments')
          .select('comment_id')
          .eq('comment_id', parentCommentId)
          .eq('deck_id', deckId)
          .maybeSingle();

      if (parentCheck == null) {
        throw Exception('Bình luận gốc không tồn tại hoặc không thuộc bộ đề này!');
      }
    }

    // Insert comment mới
    final response = await _client.from('deck_comments').insert({
      'deck_id': deckId,
      'user_id': userId,
      'parent_comment_id': parentCommentId,
      'content': content.trim(),
    }).select().single();

    return response;
  }

  Future<Map<String, dynamic>?> getCommentById(int commentId) async {
    final response = await _client
        .from('deck_comments')
        .select('comment_id, deck_id, user_id')
        .eq('comment_id', commentId)
        .maybeSingle();
    return response;
  }

  Future<int?> getDeckOwnerId(int deckId) async {
    final response = await _client
        .from('decks')
        .select('user_id')
        .eq('deck_id', deckId)
        .maybeSingle();
    return response != null ? response['user_id'] as int : null;
  }

  Future<void> deleteComment(int commentId) async {
    await _client.from('deck_comments').delete().eq('comment_id', commentId);
  }

  Future<List<Map<String, dynamic>>> getExploreDecks({
    String? search,
    String sortBy = 'trending',
    required int page,
    required int limit,
  }) async {
    final from = (page - 1) * limit;
    final to = from + limit - 1;

    // Bắt đầu query từ bảng decks (Sử dụng dynamic để tránh lỗi type mismatch của Supabase Builder)
    dynamic query = _client.from('decks').select('''
          deck_id,
          title,
          created_at,
          author:users!user_id (
            username,
            user_profiles (avatar_url)
          )
        ''');

    // Chỉ lấy deck công khai
    query = query.eq('public_status', 'public');

    // Áp dụng tìm kiếm nếu có (Bỏ description vì không tồn tại trong DB)
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }

    // Áp dụng sắp xếp
    if (sortBy == 'latest') {
      query = query.order('created_at', ascending: false);
    } else {
      // Mặc định là trending: Vì không có view_count, ta tạm thời sắp xếp theo mới nhất 
      // hoặc bạn có thể thêm tiêu chí khác sau này.
      query = query.order('created_at', ascending: false);
    }

    // Phân trang
    final response = await query.range(from, to);

    // Tính toán số lượng người học hôm nay và tổng số người từng học cho từng deck
    final List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);
    
    final today = DateTime.now().toIso8601String().substring(0, 10); // Lấy yyyy-MM-dd

    for (var deck in results) {
      final int deckId = deck['deck_id'];
      
      // 1. Tính active_learners_today (Số người học DUY NHẤT hôm nay)
      final logsToday = await _client
          .from('flashcard_study_logs')
          .select('user_id')
          .eq('deck_id', deckId)
          .gte('studied_at', '$today 00:00:00')
          .lte('studied_at', '$today 23:59:59');
      
      final Set<int> uniqueUsersToday = {};
      for (var log in (logsToday as List)) {
        uniqueUsersToday.add(log['user_id'] as int);
      }
      deck['active_learners_today'] = uniqueUsersToday.length;

      // 2. Tính view_count (Số người học DUY NHẤT từ trước đến nay)
      final logsAllTime = await _client
          .from('flashcard_study_logs')
          .select('user_id')
          .eq('deck_id', deckId);

      final Set<int> uniqueUsersAllTime = {};
      for (var log in (logsAllTime as List)) {
        uniqueUsersAllTime.add(log['user_id'] as int);
      }
      deck['view_count'] = uniqueUsersAllTime.length;
    }

    return results;
  }

  Future<void> saveDeckLink({
    required int userId,
    required int deckId,
  }) async {
    // Thực hiện chèn một dòng mới vào bảng user_decks
    // Nếu cặp (user_id, deck_id) đã tồn tại, Supabase sẽ ném ra ngoại lệ Unique Constraint
    await _client.from('user_decks').insert({
      'user_id': userId,
      'deck_id': deckId,
      'is_favorite': false,
      'last_studied_at': DateTime.now().toIso8601String(),
    });
  }
}
