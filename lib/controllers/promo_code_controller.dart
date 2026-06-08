import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/promo_code_service.dart';

class PromoCodeController {
  final PromoCodeService promoCodeService;

  PromoCodeController(this.promoCodeService);

  Future<Response> getAll(Request request) async {
    try {
      final promos = await promoCodeService.getAllPromoCodes();
      return Response.ok(jsonEncode({'status': 'success', 'data': promos}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> getActive(Request request) async {
    try {
      final promos = await promoCodeService.getActivePromoCodes();
      return Response.ok(jsonEncode({'status': 'success', 'data': promos}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> getByCode(Request request, String code) async {
    try {
      final promo = await promoCodeService.getByCode(code);
      if (promo == null) return Response.notFound(jsonEncode({'status': 'error', 'message': 'Promo not found'}), headers: {'Content-Type': 'application/json'});
      return Response.ok(jsonEncode({'status': 'success', 'data': promo}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> create(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final promo = await promoCodeService.createPromoCode(data);
      return Response.ok(jsonEncode({'status': 'success', 'data': promo}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> update(Request request, String id) async {
    try {
      final promoId = int.tryParse(id);
      if (promoId == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid ID'}));
      final data = jsonDecode(await request.readAsString());
      final promo = await promoCodeService.update(promoId, data);
      return Response.ok(jsonEncode({'status': 'success', 'data': promo}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> toggleExpired(Request request, String id) async {
    try {
      final promoId = int.tryParse(id);
      if (promoId == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid ID'}));
      final promo = await promoCodeService.toggleExpiredStatus(promoId);
      return Response.ok(jsonEncode({'status': 'success', 'data': promo}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }
}
