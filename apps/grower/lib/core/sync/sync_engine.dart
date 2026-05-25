import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:rxdart/rxdart.dart';
import 'models.dart';

enum SyncStatus { idle, syncing, error, offline }

class SyncEvent {
  final String type;
  final String message;
  final String? conversationId;
  final String? listingId;
  
  SyncEvent({
    required this.type,
    required this.message,
    this.conversationId,
    this.listingId,
  });
}

class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  Box? _actionBox;
  Box? _uploadBox;
  
  final _statusController = BehaviorSubject<SyncStatus>.seeded(SyncStatus.idle);
  Stream<SyncStatus> get statusStream => _statusController.stream;

  final _pendingCountController = BehaviorSubject<int>.seeded(0);
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  final _syncNotifier = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get syncEvents => _syncNotifier.stream;

  bool _isSyncing = false;
  Completer<void>? _initCompleter;

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      await Hive.initFlutter();
      
      // Register Adapters
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PendingActionAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PendingUploadAdapter());

      _actionBox = await Hive.openBox('pendingActions');
      _uploadBox = await Hive.openBox('pendingUploads');
      
      _updatePendingCount();

      Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        if (results.isNotEmpty && results.any((r) => r != ConnectivityResult.none)) {
          processQueue();
        } else {
          _statusController.add(SyncStatus.offline);
        }
      });
      
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initCompleter == null) await init();
    return _initCompleter!.future;
  }

  void _updatePendingCount() {
    if (_actionBox == null || _uploadBox == null) return;
    _pendingCountController.add(_actionBox!.length + _uploadBox!.length);
  }

  Future<void> queueAction(String type, Map<String, dynamic> data) async {
    await _ensureInitialized();
    await _actionBox!.add({
      'type': type,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
      'retries': 0,
      'nextRetry': DateTime.now().toIso8601String(),
    });
    _updatePendingCount();
    processQueue();
  }

  Future<void> queueUpload(String filePath, String storagePath, String hash) async {
    await _ensureInitialized();
    await _uploadBox!.add({
      'filePath': filePath,
      'storagePath': storagePath,
      'hash': hash,
      'createdAt': DateTime.now().toIso8601String(),
      'isCompleted': false,
      'retries': 0,
    });
    _updatePendingCount();
    processQueue();
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    await _ensureInitialized();
    
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _statusController.add(SyncStatus.offline);
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      // 1. Process Uploads
      final uploadKeys = List.from(_uploadBox!.keys);
      for (var key in uploadKeys) {
        final upload = Map<String, dynamic>.from(_uploadBox!.get(key));
        if (upload['isCompleted']) continue;

        try {
          final file = File(upload['filePath']);
          if (await file.exists()) {
            await FirebaseStorage.instance
                .ref(upload['storagePath'])
                .putFile(file, SettableMetadata(contentType: 'image/jpeg'));
            
            upload['isCompleted'] = true;
            await _uploadBox!.put(key, upload);
          } else {
            // File missing? Delete from queue
            await _uploadBox!.delete(key);
          }
        } catch (e) {
          debugPrint('[SyncEngine] Upload failed for $key: $e');
        }
      }

      // 2. Process Actions
      final actionKeys = List.from(_actionBox!.keys);
      for (var key in actionKeys) {
        final action = Map<String, dynamic>.from(_actionBox!.get(key));
        
        final nextRetry = DateTime.parse(action['nextRetry'] ?? action['createdAt']);
        if (DateTime.now().isBefore(nextRetry)) continue;

        try {
          if (action['type'] == 'CONVERSATION_TURN') {
            final data = action['data'];
            // Delete immediately and notify user to continue manually
            await _actionBox!.delete(key);
            
            _syncNotifier.add(SyncEvent(
              type: 'CONVERSATION_READY',
              message: 'Back online! You can continue your conversation.',
              conversationId: data['conversationId'],
            ));

          } else if (action['type'] == 'CREATE_LISTING') {
            final data = action['data'];
            final extracted = data['extractedData'];
            final plotLoc = data['plotLocation'];
            
            final geohash = GeoHasher().encode(plotLoc['longitude'], plotLoc['latitude']);
            final listingRef = FirebaseFirestore.instance.collection('listings').doc();
            
            await listingRef.set({
              'listingId': listingRef.id,
              'growerId': data['growerId'],
              'growerName': data['growerName'],
              'pickupAddress': 'Near ${plotLoc['latitude'].toStringAsFixed(3)}, ${plotLoc['longitude'].toStringAsFixed(3)}',
              'cropType': extracted['cropType'],
              'containerType': extracted['containerType'],
              'containerCount': extracted['containerCount'],
              'weightKg': extracted['weightKg'],
              'perishTier': extracted['perishTier'],
              'askingPricePerTon': extracted['askingPricePerTon'],
              'plotLocation': GeoPoint(plotLoc['latitude'], plotLoc['longitude']),
              'geohash': geohash,
              'harvestWindowEnd': DateTime.now().add(Duration(hours: extracted['harvestWindowHours'] ?? 24)),
              'status': 'OPEN',
              'producerId': null,
              'transporterId': null,
              'listingSource': 'AGENT_OFFLINE',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            await _actionBox!.delete(key);

            _syncNotifier.add(SyncEvent(
              type: 'LISTING_CREATED',
              message: 'Your offline listing is now live!',
              listingId: listingRef.id,
            ));

          } else {
            // Legacy handling
            final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable(action['type']);
            await callable.call(action['data']);
            await _actionBox!.delete(key);
          }
          
        } catch (e) {
          debugPrint('[SyncEngine] Action failed for $key: $e');
          
          action['retries']++;
          final delaySeconds = (1 << action['retries']) * 5;
          action['nextRetry'] = DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();
          
          if (action['retries'] > 8) {
             await _actionBox!.delete(key);
          } else {
            await _actionBox!.put(key, action);
          }
        }
      }

      _statusController.add(SyncStatus.idle);
    } catch (e) {
      _statusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      _updatePendingCount();
    }
  }
}
