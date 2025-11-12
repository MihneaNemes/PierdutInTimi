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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

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

    debugPrint('All assets loaded successfully');
    debugPrint('Mapillary JS size: ${mapillaryJs.length} characters');
    debugPrint('Mapillary CSS size: ${mapillaryCss.length} characters');

    String base64Js = base64.encode(utf8.encode(mapillaryJs));
    debugPrint('Base64 JS size: ${base64Js.length} characters');

    String finalHtml = htmlTemplate
        .replaceAll('MAPILLARY_CSS_CONTENT', mapillaryCss)
        .replaceAll('MAPILLARY_JS_BASE64', base64Js)
        .replaceAll('MAP_ACCESS_TOKEN_PLACEHOLDER', accessToken)
        .replaceAll('MAP_IMAGE_KEY_PLACEHOLDER', imageKey);

    debugPrint(
        'Placeholders replaced, final HTML size: ${finalHtml.length} characters');
    debugPrint('Loading HTML string');

    await _webViewController.loadHtmlString(finalHtml);

    debugPrint('HTML string loaded into WebView');
  }

  void _handleMapTap(LatLng tappedPoint) {
    if (_showResults || _actualLocation == null) return;

    final distance = Geolocator.distanceBetween(
      tappedPoint.latitude,
      tappedPoint.longitude,
      _actualLocation!.latitude,
      _actualLocation!.longitude,
    );

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

  @override
  Widget build(BuildContext context) {
    final bool isWebViewReady =
        _currentMapillaryImageId != null && _isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pierdut în Timi'),
        actions: [
          if (_showResults)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startNewRound,
              tooltip: 'Joacă din nou',
            )
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
                              Colors.black.withAlpha(77), // <-- 0.3 opacity
                              side: BorderSide(
                                color:
                                Colors.white.withAlpha(179), // <-- 0.7 opacity
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
                      color: Colors.black.withAlpha(153), // <-- 0.6 opacity
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Distanța: ${(_distanceInMeters! / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (!_showResults)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      color: Colors.black.withAlpha(128), // <-- 0.5 opacity
                      padding: const EdgeInsets.all(10.0),
                      margin: const EdgeInsets.all(10.0),
                      child: Text(
                        _actualLocation == null
                            ? 'Se încarcă...'
                            : 'Apasă pe hartă pentru a ghici!',
                        style:
                        const TextStyle(color: Colors.white, fontSize: 16),
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