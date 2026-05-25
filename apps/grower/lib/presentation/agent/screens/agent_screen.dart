import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../bloc/agent_bloc.dart';
import '../bloc/agent_event.dart';
import '../bloc/agent_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/listing_model.dart';
import '../../../core/sync/sync_engine.dart';
import '../../widgets/bottom_nav.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Voice & TTS state
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;

  // UI state
  bool _isDraftExpanded = true;

  // Review Mode state
  Map<String, dynamic>? _editableData;
  late final TextEditingController _priceController;

  bool _isSameEnum(String? cloudValue, String enumName) {
    if (cloudValue == null) return false;
    return cloudValue.replaceAll('_', '').toUpperCase() == enumName.replaceAll('_', '').toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _setupTts();

    // FIX 2: Welcome message when agent opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgentBloc>().add(StartAgent());
    });

    // Listen to SyncEngine events
    SyncEngine().syncEvents.listen((event) {
      if (!mounted) return;
      
      if (event.type == 'LISTING_CREATED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(event.message)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      if (event.type == 'CONVERSATION_READY') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(event.message)),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  void _speak(String text) async {
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _priceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          listenOptions: stt.SpeechListenOptions(
            localeId: 'en_US',
          ),
          onResult: (val) => setState(() {
            _inputController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _updateWeight() {
    if (_editableData == null) return;
    
    const containerWeights = {
      'MACRO_BIN': 500,
      'HALF_BIN': 250,
      'LUG_BOX': 20,
      'BULK_BAG': 500,
    };

    final type = _editableData!['containerType']?.toString().toUpperCase();
    final count = (_editableData!['containerCount'] ?? 0) as int;
    final avgWeight = containerWeights[type];

    if (avgWeight != null && count > 0) {
      setState(() {
        _editableData!['weightKg'] = count * avgWeight;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }
    
    if (permission == LocationPermission.deniedForever) return Future.error('Location permissions are permanently denied');

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppColors.bark,
        bottomNavigationBar: const BottomNav(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/dashboard'),
          ),
          title: Row(
            children: [
              const Text('Harvest Agent', style: TextStyle(color: Colors.white)),
              const Spacer(),
              _buildSyncBadge(),
            ],
          ),
        ),
        body: BlocConsumer<AgentBloc, AgentState>(
          listener: (context, state) {
            if (state is AgentError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
            }
            if (state is AgentOfflineQueued) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.orange,
                  content: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                ),
              );
            }
            if (state is AgentNeedsReview) {
              setState(() {
                _editableData = Map<String, dynamic>.from(state.extractedData);
                _priceController.text = _editableData?['askingPricePerTon']?.toString() ?? '';
              });
              _speak(state.summary);
            }

            if (state is ConversationActive) {
               final lastMsg = state.messages.last;
               if (lastMsg['role'] == 'assistant') {
                 _speak(lastMsg['content']);
               }
            }
            // Auto-scroll chat
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
          builder: (context, state) {
            if (state is AgentNeedsReview) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildReviewState(context, state),
              );
            }
            
            if (state is AgentSuccess) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildSuccessState(context, state),
              );
            }

            return Column(
              children: [
                Expanded(child: _buildChatArea(context, state)),
                if (state is ConversationActive) _buildLiveDraftCard(state),
                _buildMessageInput(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveDraftCard(ConversationActive state) {
    final data = state.extractedData;
    if (data.isEmpty) return const SizedBox();

    final hasCrop = data['cropType'] != null;
    final hasWeight = data['weightKg'] != null;
    final hasPrice = data['askingPricePerTon'] != null;
    final hasUrgency = data['perishTier'] != null;

    if (!hasCrop && !hasWeight && !hasPrice && !hasUrgency) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isDraftExpanded = !_isDraftExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.wheat, size: 18),
                  const SizedBox(width: 8),
                  const Text('Draft Listing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(_isDraftExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white54, size: 18),
                ],
              ),
            ),
          ),
          if (_isDraftExpanded) ...[
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (hasCrop) _buildDraftItem(Icons.grass, data['cropType'].toString().replaceAll('_', ' ')),
                  if (hasWeight) _buildDraftItem(Icons.scale, '${data['weightKg']} kg'),
                  if (hasPrice) _buildDraftItem(Icons.payments, '₹${data['askingPricePerTon']}/ton'),
                  if (hasUrgency) _buildDraftItem(Icons.speed, data['perishTier'].toString().replaceAll('_', ' ')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDraftItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.moss2, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSyncBadge() {
    return StreamBuilder<SyncStatus>(
      stream: SyncEngine().statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.idle;
        if (status == SyncStatus.idle) return const SizedBox();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status == SyncStatus.offline ? Colors.orange : Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == SyncStatus.syncing ? Icons.sync : Icons.cloud_off,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                status == SyncStatus.syncing ? 'Syncing...' : 'Offline',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatArea(BuildContext context, AgentState state) {
    List<Map<String, dynamic>> messages = [];
    if (state is ConversationActive) messages = state.messages;
    if (state is ConversationThinking) messages = state.messages;

    if (messages.isEmpty && state is AgentInitial) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assistant, size: 64, color: AppColors.wheat),
            const SizedBox(height: 16),
            Text(
              'Ready to list your harvest?',
              style: AppTextStyles.headlineLarge.copyWith(color: AppColors.wheat),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tell me what you have, and I\'ll help you create a listing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (state is ConversationThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _buildThinkingBubble();
        }
        final msg = messages[index];
        final isUser = msg['role'] == 'user';
        return _buildMessageBubble(msg['content'], isUser);
      },
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.moss : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
        ),
        child: Text(
          content,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wheat),
        ),
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, AgentState state) {
    final bool isLoading = state is ConversationThinking || state is AgentLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none, 
                color: _isListening ? Colors.red : AppColors.wheat),
            onPressed: isLoading ? null : _listen,
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (val) => _sendMessage(context),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.wheat),
            onPressed: isLoading ? null : () => _sendMessage(context),
          ),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context) async {
    if (_inputController.text.trim().isEmpty) return;
    
    final message = _inputController.text;
    _inputController.clear();

    try {
      final pos = await _determinePosition();
      if (!context.mounted) return;
      context.read<AgentBloc>().add(
        SendConversationMessage(message, GeoPoint(pos.latitude, pos.longitude)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _onConfirmTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bark,
        title: const Text('List this crop?', style: TextStyle(color: AppColors.wheat)),
        content: const Text(
          'Your listing will go live and nearby producers '
          'will be notified immediately.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Review Again', style: TextStyle(color: AppColors.stone)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moss,
            ),
            child: const Text('Yes, List It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    
    if (confirmed == true && _editableData != null) {
      try {
        final pos = await _determinePosition();
        if (!mounted) return;
        context.read<AgentBloc>().add(ConfirmListing(_editableData!, GeoPoint(pos.latitude, pos.longitude)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildReviewState(BuildContext context, AgentNeedsReview state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.summary,
            style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (state.reasoning != null) ...[
            _buildReasoningCard(state.reasoning!),
            const SizedBox(height: 24),
          ],
          
          _buildReviewCard(
            label: 'Crop Type',
            child: Text(
              ListingModel.cropDisplayName(_editableData?['cropType']?.toString()),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          
          _buildReviewCard(
            label: 'Container Type',
            child: DropdownButton<String>(
              value: ListingModel.containerTypes
                  .firstWhere((ct) => _isSameEnum(_editableData?['containerType'], ct), orElse: () => 'MACRO_BIN'),
              dropdownColor: AppColors.bark,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: ListingModel.containerTypes.map((ct) {
                return DropdownMenuItem(value: ct, child: Text(ListingModel.containerDisplayName(ct)));
              }).toList(),
              onChanged: (val) => setState(() {
                _editableData?['containerType'] = val;
                _updateWeight();
              }),
            ),
          ),

          _buildReviewCard(
            label: 'Number of Containers',
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.wheat),
                  onPressed: () => setState(() {
                    if ((_editableData?['containerCount'] ?? 1) > 1) {
                      _editableData?['containerCount']--;
                      _updateWeight();
                    }
                  }),
                ),
                Text(
                  '${_editableData?['containerCount']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.wheat),
                  onPressed: () => setState(() {
                    _editableData?['containerCount']++;
                    _updateWeight();
                  }),
                ),
              ],
            ),
          ),

          _buildReviewCard(
            label: 'Total Weight (kg)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_editableData?['weightKg'] ?? 0} kg',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),

          _buildReviewCard(
            label: 'Urgency',
            child: Wrap(
              spacing: 8,
              children: PerishTier.values.map((pt) {
                final val = pt.name.toUpperCase();
                final isSelected = _isSameEnum(_editableData?['perishTier'], pt.name);
                return GestureDetector(
                  onTap: () => setState(() => _editableData?['perishTier'] = val),
                  child: Chip(
                    label: Text(val.replaceAll('_', ' '),
                        style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : AppColors.wheat)),
                    backgroundColor: isSelected ? AppColors.moss : Colors.transparent,
                    side: BorderSide(color: isSelected ? AppColors.moss : AppColors.wheat.withValues(alpha: 0.3)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          _buildReviewCard(
            label: 'Asking Price (Optional)',
            child: TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'e.g. 2500',
                hintStyle: TextStyle(color: Colors.white24),
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: Colors.white),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) => setState(() => _editableData?['askingPricePerTon'] = double.tryParse(val)),
            ),
          ),

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _onConfirmTapped,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss, minimumSize: const Size(double.infinity, 56)),
            child: const Text('✓ Confirm & Create Listing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<AgentBloc>().add(ResetAgent()),
            child: const Text('✗ Start Over', style: TextStyle(color: AppColors.wheat)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildReasoningCard(Map<String, dynamic> reasoning) {
    final urgency = (reasoning['urgencyScore'] ?? 0) as int;
    final factors = List<String>.from(reasoning['decisionFactors'] ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.moss.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.moss.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.wheat),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Operational Reasoning',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.wheat, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 90),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgency > 70 ? Colors.red.withValues(alpha: 0.2) : AppColors.moss.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Urg: $urgency%',
                  style: TextStyle(
                    color: urgency > 70 ? Colors.redAccent : AppColors.moss2,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...factors.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.moss2, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          )),
          const Divider(color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReasoningStat('Weather Risk', reasoning['weatherRisk'] ?? 'LOW'),
              _buildReasoningStat('Perishability', reasoning['perishabilityRisk'] ?? 'LOW'),
              _buildReasoningStat('Radius', '${reasoning['recommendedRadiusKm']}km'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildReviewCard({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.wheat, fontSize: 12)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, AgentSuccess state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.check_circle_outline, color: AppColors.moss2, size: 80),
          const SizedBox(height: 24),
          Text(
            'Listing Created!',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.wheat),
          ),
          const SizedBox(height: 16),
          Text(
            state.summary,
            style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.moss.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.moss.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping, color: AppColors.wheat, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Logistics Status',
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.wheat, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.matchedTransporters.isNotEmpty) ...[
                  const Text(
                    'Transporters Notified:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.matchedTransporters.join(', '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ] else
                  const Text(
                    'No transporters available nearby',
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => context.go('/listings/${state.listingId}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moss,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('View Listing Details', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<AgentBloc>().add(ResetAgent()),
            child: const Text('Create Another', style: TextStyle(color: AppColors.wheat)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
