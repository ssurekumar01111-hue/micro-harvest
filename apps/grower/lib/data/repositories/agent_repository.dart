import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgentRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<Map<String, dynamic>> processListing({
    required String rawInput,
    required String growerId,
    required GeoPoint plotLocation,
    required DateTime harvestWindowEnd,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('agentProcessListing');
      final result = await callable.call({
        'rawInput': rawInput,
        'growerId': growerId,
        'plotLocation': {
          'latitude': plotLocation.latitude,
          'longitude': plotLocation.longitude,
        },
        'harvestWindowEnd': harvestWindowEnd.toIso8601String(),
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> processConversationTurn({
    String? conversationId,
    required String message,
    required String growerId,
    required GeoPoint plotLocation,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('processConversationTurn');
      final result = await callable.call({
        'conversationId': conversationId,
        'message': message,
        'growerId': growerId,
        'plotLocation': {
          'latitude': plotLocation.latitude,
          'longitude': plotLocation.longitude,
        },
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      rethrow;
    }
  }
}
