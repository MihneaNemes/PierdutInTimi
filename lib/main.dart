import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  // Configure Firebase Database with Europe region URL
  FirebaseDatabase.instance.databaseURL =
  'https://pierdutintimi-default-rtdb.europe-west1.firebasedatabase.app';

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  runApp(const PierdutInTimiApp());
}

class PierdutInTimiApp extends StatelessWidget {
  const PierdutInTimiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pierdut în Timi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

// Start Screen
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _nameController = TextEditingController();
  List<String> _previousNames = [];
  String? _selectedName;

  @override
  void initState() {
    super.initState();
    _loadPreviousNames();
  }

  Future<void> _loadPreviousNames() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _previousNames = prefs.getStringList('player_names') ?? [];
    });
  }

  Future<void> _savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_previousNames.contains(name)) {
      _previousNames.add(name);
      await prefs.setStringList('player_names', _previousNames);
    }
  }

  void _startGame() async {
    String playerName = _selectedName ?? _nameController.text.trim();

    if (playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te rog introdu un nume!')),
      );
      return;
    }

    await _savePlayerName(playerName);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(playerName: playerName),
      ),
    );
  }

  void _showHighScores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HighScoresScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade700],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.map,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pierdut în Timi',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text(
                          'Introdu numele tău:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Nume',
                            prefixIcon: Icon(Icons.person),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value.isNotEmpty) {
                                _selectedName = null;
                              }
                            });
                          },
                          onSubmitted: (_) => _startGame(),
                        ),
                        if (_previousNames.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'sau selectează un nume anterior:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _previousNames.map((name) {
                              return ChoiceChip(
                                label: Text(name),
                                selected: _selectedName == name,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedName = selected ? name : null;
                                    if (selected) {
                                      _nameController.clear();
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: const Text(
                      'Începe Jocul',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _showHighScores,
                    icon: const Icon(Icons.emoji_events, size: 28),
                    label: const Text(
                      'Scoruri Înalte',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

// High Scores Screen
class HighScoresScreen extends StatefulWidget {
  const HighScoresScreen({super.key});

  @override
  State<HighScoresScreen> createState() => _HighScoresScreenState();
}

class _HighScoresScreenState extends State<HighScoresScreen> {
  final DatabaseReference _scoresRef =
  FirebaseDatabase.instance.ref('highscores');
  List<Map<String, dynamic>> _highScores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    try {
      final snapshot = await _scoresRef
          .orderByChild('totalScore')
          .limitToLast(5)
          .get();

      if (snapshot.exists) {
        final List<Map<String, dynamic>> scores = [];
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          scores.add({
            'playerName': value['playerName'],
            'totalScore': value['totalScore'],
            'timestamp': value['timestamp'],
          });
        });

        scores.sort((a, b) => b['totalScore'].compareTo(a['totalScore']));

        setState(() {
          _highScores = scores.take(5).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Eroare la încărcarea scorurilor: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoruri Înalte'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _highScores.isEmpty
          ? const Center(
        child: Text(
          'Niciun scor încă!\nFii primul care joacă!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _highScores.length,
        itemBuilder: (context, index) {
          final score = _highScores[index];
          final rank = index + 1;

          IconData medalIcon;
          Color medalColor;

          switch (rank) {
            case 1:
              medalIcon = Icons.looks_one;
              medalColor = Colors.amber;
              break;
            case 2:
              medalIcon = Icons.looks_two;
              medalColor = Colors.grey;
              break;
            case 3:
              medalIcon = Icons.looks_3;
              medalColor = Colors.brown;
              break;
            default:
              medalIcon = Icons.emoji_events;
              medalColor = Colors.blue;
          }

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                medalIcon,
                size: 40,
                color: medalColor,
              ),
              title: Text(
                score['playerName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Scor Total: ${score['totalScore'].toStringAsFixed(0)} puncte',
              ),
              trailing: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: medalColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Game Screen with 5 rounds
class GameScreen extends StatefulWidget {
  final String playerName;

  const GameScreen({super.key, required this.playerName});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _currentMapillaryImageId;
  final String mapillaryAccessToken =
      dotenv.env['MAPILLARY_ACCESS_TOKEN'] ?? 'MAPILLARY_TOKEN_ERROR';
  final String mapsApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'GOOGLE_API_KEY_ERROR';
  late final WebViewController _webViewController;
  bool _isInitialized = false;

  final MapController _mapController = MapController();
  LatLng? _actualLocation;
  LatLng? _guessedLocation;
  double? _distanceInMeters;
  bool _showResults = false;

  int _currentRound = 1;
  final int _totalRounds = 5;
  List<double> _roundScores = [];
  double _totalScore = 0;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _loadAssetsAndStartRound();
  }

  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                'Eroare WebView: ${error.description}, URL: ${error.url}');
          },
          onPageFinished: (String url) {
            debugPrint('WebView Page Finished Loading: $url');
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint('JS Console [${message.level.name}]: ${message.message}');
      });
  }

  void _loadAssetsAndStartRound() async {
    try {
      setState(() {
        _isInitialized = true;
      });
      await _startNewRound();
    } catch (e) {
      debugPrint('Eroare la pornirea rundei: $e');
      setState(() {
        _isInitialized = true;
        _currentMapillaryImageId = 'ASSET_LOAD_ERROR';
      });
    }
  }

  double _calculateScore(double distanceInMeters) {
    // Score calculation: max 5000 points for 0m, decreasing with distance
    // 0m = 5000 points, 5000m = 0 points
    const maxDistance = 5000.0;
    const maxScore = 5000.0;

    if (distanceInMeters >= maxDistance) return 0;

    return maxScore * (1 - (distanceInMeters / maxDistance));
  }

  Future<void> _startNewRound() async {
    setState(() {
      _currentMapillaryImageId = null;
      _actualLocation = null;
      _guessedLocation = null;
      _distanceInMeters = null;
      _showResults = false;
    });

    const double minLon = 21.17;
    const double maxLon = 21.28;
    const double minLat = 45.72;
    const double maxLat = 45.79;

    const double boxSizeLat = 0.01;
    const double boxSizeLon = 0.01;

    final double startLon =
        minLon + _random.nextDouble() * (maxLon - minLon - boxSizeLon);
    final double startLat =
        minLat + _random.nextDouble() * (maxLat - minLat - boxSizeLat);

    final double endLon = startLon + boxSizeLon;
    final double endLat = startLat + boxSizeLat;

    final String randomBbox = '$startLon,$startLat,$endLon,$endLat';

    final url = Uri.parse(
        'https://graph.mapillary.com/images?access_token=$mapillaryAccessToken&fields=id,geometry&bbox=$randomBbox&limit=100');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final images = data['data'] as List;

        if (images.isNotEmpty) {
          final randomIndex = _random.nextInt(images.length);
          final image = images[randomIndex];

          final String imageId = image['id'];
          final geometry = image['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final double longitude = coordinates[0] as double;
          final double latitude = coordinates[1] as double;

          setState(() {
            _currentMapillaryImageId = imageId;
            _actualLocation = LatLng(latitude, longitude);
          });
          debugPrint('Noua imagine Mapillary ID: $imageId');
          debugPrint('Locația actuală: $_actualLocation');
          return;
        } else {
          debugPrint('Cutia aleatorie era goală. Se reîncearcă...');
          _startNewRound();
          return;
        }
      }
      debugPrint(
          'Eroare la apelul Mapillary API. Status Code: ${response.statusCode}');
      _currentMapillaryImageId = 'AICI_ESTE_EROARE_API_SAU_LIPSA_IMAGINI';
    } catch (e) {
      debugPrint('Eroare rețea sau decodare JSON: $e');
      _currentMapillaryImageId = 'AICI_ESTE_EROARE_DE_RETEA';
    }
    setState(() {});
  }

  void _resetStreetViewPosition() {
    if (_currentMapillaryImageId != null) {
      final String script = '''
        if (typeof mly !== 'undefined') {
          mly.moveTo('$_currentMapillaryImageId');
        } else if (typeof viewer !== 'undefined') {
          viewer.moveTo('$_currentMapillaryImageId');
        } else {
          console.error('Mapillary viewer object (mly or viewer) not found.');
        }
      ''';
      _webViewController.runJavaScript(script);
      debugPrint('Resetting Mapillary view to ID: $_currentMapillaryImageId');
    }
  }

  Future<void> _loadMapillaryViewer(
      String imageKey, String accessToken) async {
    debugPrint('Loading Mapillary viewer with imageKey: $imageKey');

    String htmlTemplate =
    await rootBundle.loadString('assets/mapillary_template.html');
    String mapillaryJs = await rootBundle.loadString('assets/mapillary.js');
    String mapillaryCss = await rootBundle.loadString('assets/mapillary.css');

    String base64Js = base64.encode(utf8.encode(mapillaryJs));

    String finalHtml = htmlTemplate
        .replaceAll('MAPILLARY_CSS_CONTENT', mapillaryCss)
        .replaceAll('MAPILLARY_JS_BASE64', base64Js)
        .replaceAll('MAP_ACCESS_TOKEN_PLACEHOLDER', accessToken)
        .replaceAll('MAP_IMAGE_KEY_PLACEHOLDER', imageKey);

    await _webViewController.loadHtmlString(finalHtml);
  }

  void _handleMapTap(LatLng tappedPoint) {
    if (_showResults || _actualLocation == null) return;

    final distance = Geolocator.distanceBetween(
      tappedPoint.latitude,
      tappedPoint.longitude,
      _actualLocation!.latitude,
      _actualLocation!.longitude,
    );

    final roundScore = _calculateScore(distance);
    _roundScores.add(roundScore);
    _totalScore += roundScore;

    setState(() {
      _guessedLocation = tappedPoint;
      _distanceInMeters = distance;
      _showResults = true;
    });

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          _actualLocation!,
          tappedPoint,
        ),
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  Future<void> _saveGameScore() async {
    try {
      final DatabaseReference scoresRef =
      FirebaseDatabase.instance.ref('highscores');

      await scoresRef.push().set({
        'playerName': widget.playerName,
        'totalScore': _totalScore,
        'timestamp': ServerValue.timestamp,
        'rounds': _roundScores,
      });

      debugPrint('Scor salvat cu succes!');
    } catch (e) {
      debugPrint('Eroare la salvarea scorului: $e');
    }
  }

  void _nextRound() {
    if (_currentRound < _totalRounds) {
      setState(() {
        _currentRound++;
      });
      _startNewRound();
    } else {
      _saveGameScore();
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Joc Terminat!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scor Total: ${_totalScore.toStringAsFixed(0)} puncte',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(_totalRounds, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Runda ${index + 1}: ${_roundScores[index].toStringAsFixed(0)} puncte',
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Înapoi la Meniu'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentRound = 1;
                  _roundScores.clear();
                  _totalScore = 0;
                });
                _startNewRound();
              },
              child: const Text('Joacă Din Nou'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWebViewReady =
        _currentMapillaryImageId != null && _isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: Text('Runda $_currentRound/$_totalRounds - ${widget.playerName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Scor: ${_totalScore.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: isWebViewReady
                ? FutureBuilder<void>(
              future: _loadMapillaryViewer(
                  _currentMapillaryImageId!, mapillaryAccessToken),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      WebViewWidget(controller: _webViewController),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: IconButton(
                            onPressed: _resetStreetViewPosition,
                            tooltip: 'Resetează la pornire',
                            icon: const Icon(Icons.flag,
                                color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor:
                              Colors.black.withAlpha(77),
                              side: BorderSide(
                                color: Colors.white.withAlpha(179),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.all(12.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Eroare: ${snapshot.error}'));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            )
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(45.753, 21.225),
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) => _handleMapTap(point),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_guessedLocation != null)
                          Marker(
                            width: 80.0,
                            height: 80.0,
                            point: _guessedLocation!,
                            child: const Tooltip(
                              message: 'Ghiciul tău',
                              child: Icon(
                                Icons.location_pin,
                                color: Colors.blue,
                                size: 40.0,
                              ),
                            ),
                          ),
                        if (_showResults && _actualLocation != null)
                          Marker(
                            width: 80.0,
                            height: 80.0,
                            point: _actualLocation!,
                            child: const Tooltip(
                              message: 'Locația corectă',
                              child: Icon(
                                Icons.flag,
                                color: Colors.green,
                                size: 40.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_showResults &&
                        _guessedLocation != null &&
                        _actualLocation != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_actualLocation!, _guessedLocation!],
                            color: Colors.red,
                            strokeWidth: 3.0,
                          ),
                        ],
                      ),
                  ],
                ),
                if (_showResults)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.black.withAlpha(153),
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distanța: ${(_distanceInMeters! / 1000).toStringAsFixed(2)} km',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Puncte: ${_roundScores.last.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _nextRound,
                            icon: Icon(
                              _currentRound < _totalRounds
                                  ? Icons.arrow_forward
                                  : Icons.done,
                              size: 18,
                            ),
                            label: Text(
                              _currentRound < _totalRounds
                                  ? 'Următoarea'
                                  : 'Finalizează',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_showResults)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      color: Colors.black.withAlpha(128),
                      padding: const EdgeInsets.all(10.0),
                      margin: const EdgeInsets.all(10.0),
                      child: Text(
                        _actualLocation == null
                            ? 'Se încarcă...'
                            : 'Apasă pe hartă pentru a ghici!',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton.filled(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            _mapController.move(_mapController.camera.center,
                                _mapController.camera.zoom + 1);
                          },
                          tooltip: 'Mărește',
                        ),
                        const SizedBox(height: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            _mapController.move(_mapController.camera.center,
                                _mapController.camera.zoom - 1);
                          },
                          tooltip: 'Micșorează',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}