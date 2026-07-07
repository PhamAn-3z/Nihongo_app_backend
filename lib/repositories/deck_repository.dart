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
      }).select().maybeSingle();

      if (deckResponse == null) {
        throw Exception('Failed to create deck');
      }

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
            termsToInsert.add({
              'group_id': groupId,
              'position_id': positionId,
              'content': {'text': rowData[key].toString()},
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
    // Truy vấn bốc toàn bộ thông tin Deck, Author và dữ liệu SM-2 của người học
    // 🌟 SỬA LỖI PGRST201: Chỉ định rõ khóa ngoại 'decks_user_id_fkey' để lấy tác giả
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

    return List<Map<String, dynamic>>.from(response as List);
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
    final deckInfo = await _client.from('decks').select('title').eq('deck_id', deckId).maybeSingle();

    if (deckInfo == null) {
      throw Exception('Deck not found');
    }

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
    }).select().maybeSingle();

    if (response == null) {
      throw Exception('Failed to add comment');
    }

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
}
