import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../../widgets/listing_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechInitialized = false;

  final List<String> _suggestions = [
    "Show me urgent Pinot Noir nearby",
    "Merlot under 3000 per ton within 50km",
    "Heavy loads, at least 15 tons",
    "Cheapest Cabernet available today",
    "What's available within 30km?",
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    // Request microphone permission on init
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechInitialized = await _speech.initialize(
        onError: (error) => debugPrint('STT error: $error'),
        onStatus: (status) => debugPrint('STT status: $status'),
      );
    } else {
      debugPrint('Microphone permission denied');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    // Check permission before listening
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required for voice search'),
            ),
          );
        }
        return;
      }
    }

    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize();
    }

    if (_speechInitialized) {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              _controller.text = val.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
        ),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      if (_controller.text.isNotEmpty) {
        _submitSearch(_controller.text);
      }
    }
  }

  void _submitSearch(String query) {
    if (query.trim().isEmpty) return;
    context.read<SearchBloc>().add(
      SearchQuerySubmitted(query.trim())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        title: const Text(
          'Smart Search',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF2C1F0E),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search input row
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Ask for listings naturally...',
                          hintStyle: TextStyle(color: Colors.grey.withAlpha(178)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withAlpha(51)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withAlpha(51)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4A7C59), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF4A7C59)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: _submitSearch,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Voice button
                  GestureDetector(
                    onTap: () {
                      if (_isListening) {
                        _stopListening();
                      } else {
                        _startListening();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red : const Color(0xFF4A7C59),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : const Color(0xFF4A7C59)).withAlpha(76),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search button
                  IconButton.filled(
                    onPressed: () => _submitSearch(_controller.text),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7C59),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state is SearchInitial) {
                    return _buildSuggestions();
                  }
                  if (state is SearchLoading) {
                    return _buildLoading(state.naturalReply);
                  }
                  if (state is SearchEmpty) {
                    return _buildEmpty(state);
                  }
                  if (state is SearchLoaded) {
                    return _buildResults(state);
                  }
                  if (state is SearchError) {
                    return _buildError(state.message);
                  }
                  return const SizedBox.expand();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Try asking...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8C7B6A),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestions.map((s) => GestureDetector(
              onTap: () {
                _controller.text = s;
                _submitSearch(s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF4A7C59).withAlpha(51),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A7C59),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Or type your own query above',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8C7B6A),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(String naturalReply) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF4A7C59)),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              naturalReply,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8C7B6A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(SearchEmpty state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Color(0xFF8C7B6A)),
            const SizedBox(height: 24),
            Text(
              state.resultSummary,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF2C1F0E)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                _controller.clear();
                context.read<SearchBloc>().add(SearchCleared());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C59),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try a new search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchLoaded state) {
    return Column(
      children: [
        // Result summary bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A7C59).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4A7C59).withAlpha(51)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF4A7C59), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.resultSummary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A7C59),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF4A7C59)),
                onPressed: () {
                  _controller.clear();
                  context.read<SearchBloc>().add(SearchCleared());
                },
              ),
            ],
          ),
        ),
        // Listing cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.listings.length,
            itemBuilder: (context, index) {
              final listing = state.listings[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListingCard(
                  listing: listing,
                  onTap: () => context.push(
                    '/listing/${listing.listingId}',
                    extra: listing,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.read<SearchBloc>().add(SearchCleared()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
