import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/membership_service.dart';

class MembershipController {
  final MembershipService membershipService;

  MembershipController(this.membershipService);

  Future<Response> getAll(Request request) async {
    try {
      final memberships = await membershipService.getAllMemberships();
      return Response.ok(
        jsonEncode({'status': 'success', 'data': memberships}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> getById(Request request, String id) async {
    try {
      final membershipId = int.tryParse(id);
      if (membershipId == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Invalid ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final membership = await membershipService.getMembershipById(membershipId);
      if (membership == null) {
        return Response.notFound(
          jsonEncode({'status': 'error', 'message': 'Membership not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'status': 'success', 'data': membership}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> create(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final newMembership = await membershipService.createMembership(data);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': newMembership}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> update(Request request, String id) async {
    try {
      final membershipId = int.tryParse(id);
      if (membershipId == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Invalid ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      final updatedMembership = await membershipService.update(membershipId, data);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': updatedMembership}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> toggleActive(Request request, String id) async {
    try {
      final membershipId = int.tryParse(id);
      if (membershipId == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Invalid ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final updatedMembership = await membershipService.toggleActiveStatus(membershipId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': updatedMembership}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
