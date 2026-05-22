import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart'; // <--- IMPORT THƯ VIỆN

void main() async {
  // 1. CẤU HÌNH ĐƯỜNG DÂY KẾT NỐI ĐẾN SUPABASE
  // (Thay 2 chuỗi này bằng URL và Anon Key thật trên trang web Supabase của nhóm bạn)
  final String supabaseUrl = 'https://xdekwfqnhrohydgejhdk.supabase.co';
  final String supabaseKey = 'sb_publishable_Mk288brWkRYpm14YH2xAOw_sAb6qcyW';

  // Khởi tạo thực thể Supabase Client ngay khi Server chạy
  final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
  print('🔌 Đang thiết lập đường dây kết nối đến Supabase Cloud...');

  final router = Router();

  // 2. API TRUY VẤN DỮ LIỆU THẬT TỪ DATABASE
  // Ví dụ: API lấy danh sách bộ thẻ từ bảng 'decks' dưới database Supabase
  router.get('/api/v1/decks', (Request request) async {
    try {
      // Chọc thẳng vào bảng 'decks' trên mây để lấy dữ liệu thật bằng lệnh của Supabase
      final List<dynamic> response = await supabaseClient.from('decks').select();

      return Response.ok(
        jsonEncode({"status": "success", "data": response}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"status": "error", "message": "Lỗi kết nối DB: $e"}), // Thêm body: vào đây 🌟
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // Cấu hình khởi chạy Server
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);

  print('🚀 THÀNH CÔNG: Server Docker đã thông mạch với Supabase tại cổng: :8080');
}