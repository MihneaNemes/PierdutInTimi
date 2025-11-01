// lib/main.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle; // NECESAR PENTRU A CITI ASSETS

// MODIFICARE: main() devine async și încarcă .env
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(const PierdutInTimiApp());
}

class PierdutInTimiApp extends StatelessWidget {
  const PierdutInTimiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pierdut în Timi',
      home: GameScreen(),
    );
  }
}

// -----------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _currentMapillaryImageId;

  // Citirea cheilor din .env (lowerCamelCase)
  final String mapillaryAccessToken = dotenv.env['MAPILLARY_ACCESS_TOKEN'] ?? 'MAPILLARY_TOKEN_ERROR';
  final String mapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'GOOGLE_API_KEY_ERROR';

  // Variabile pentru conținutul injectat
  String _mapillaryCssContent = '';
  String _mapillaryJsContent = '';

  late final WebViewController _webViewController;
  bool _isInitialized = false; // Flag pentru a urmări inițializarea assets-urilor

  @override
  void initState() {
    super.initState();
    _initializeWebViewController(); // Inițializăm controllerul
    _loadAssetsAndStartRound();    // Citim assets și pornim runda
  }

  // Inițializarea WebViewController
  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('Eroare WebView: ${error.description}, URL: ${error.url}');
          },
          onPageFinished: (String url) {
            debugPrint('WebView Page Finished Loading: $url');
          },
        ),
      );
  }

  // NOU: Citirea fișierelor și pornirea rundei
  void _loadAssetsAndStartRound() async {
    try {
      // 1. Citește conținutul CSS și JS din assets
      final css = await rootBundle.loadString('assets/mapillary.css');
      final js = await rootBundle.loadString('assets/mapillary.js');

      // 2. Setează conținutul și marchează inițializarea ca terminată
      setState(() {
        _mapillaryCssContent = css;
        _mapillaryJsContent = js;
        _isInitialized = true; // Assets-urile sunt gata
      });

      // 3. Pornește prima rundă (apel API)
      await _startNewRound();

    } catch (e) {
      debugPrint('Eroare la citirea asset-urilor locale (Verifică pubspec.yaml și calea): $e');
      setState(() {
        _isInitialized = true; // Marcăm ca inițializat, dar cu eroare
        _currentMapillaryImageId = 'ASSET_LOAD_ERROR';
      });
    }
  }

  // Funcție pentru a apela API-ul Mapillary (Logica rămâne aceeași)
  Future<void> _startNewRound() async {
    const String bbox = '21.17,45.72,21.28,45.79';

    final url = Uri.parse(
        'https://graph.mapillary.com/images?access_token=$mapillaryAccessToken&fields=id&bbox=$bbox&limit=100');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final images = data['data'] as List;

        if (images.isNotEmpty) {
          final randomIndex = (DateTime.now().millisecondsSinceEpoch % images.length).toInt();
          final imageId = images[randomIndex]['id'];
          setState(() {
            _currentMapillaryImageId = imageId;
          });
          debugPrint('Noua imagine Mapillary ID: $imageId');
          return;
        }
      }
      debugPrint('Eroare la apelul Mapillary API. Status Code: ${response.statusCode}');
      _currentMapillaryImageId = 'AICI_ESTE_EROARE_API_SAU_LIPSA_IMAGINI';
    } catch (e) {
      debugPrint('Eroare rețea sau decodare JSON: $e');
      _currentMapillaryImageId = 'AICI_ESTE_EROARE_DE_RETEA';
    }
    setState(() {});
  }

  // NOU: Funcție care injectează CSS și JS ca string-uri
  String _buildMapillaryHtml(String imageKey, String accessToken) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        
        <style>
            ${_mapillaryCssContent}
            body { margin: 0; }
            #mly { width: 100vw; height: 100vh; }
        </style>
        
    </head> 
    <body>
        <div id="mly"></div>
        <script>
            ${_mapillaryJsContent}
            
            // Codul tău de inițializare Mapillary Viewer (care rulează după codul injectat)
            var mly = new Mapillary.Viewer({
                accessToken: "$accessToken",
                container: "mly", 
                imageId: "$imageKey",
                // Opțiuni...
                component: {
                  cover: false,
                  attribution: false,
                  zoom: false,
                  bearing: false,
                  compass: false,
                }
            });
            window.addEventListener("resize", () => mly.resize());
        </script>
    </body>
    </html>
  ''';
  }

  @override
  Widget build(BuildContext context) {
    // Verifică dacă toate asset-urile și ID-ul Mapillary au fost încărcate
    final bool isReady = _currentMapillaryImageId != null && _isInitialized;

    // LOGICĂ CORECTATĂ: Încarcă HTML-ul doar dacă este gata
    if (isReady) {
      _webViewController.loadHtmlString(
        _buildMapillaryHtml(
          _currentMapillaryImageId!,
          mapillaryAccessToken,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pierdut în Timi'),
      ),
      body: Column(
        children: <Widget>[
          // Partea de sus: Vizualizatorul Mapillary (WebView)
          Expanded(
            flex: 2,
            child: isReady
                ? WebViewWidget(controller: _webViewController)
                : const Center(
              child: CircularProgressIndicator(),
            ),
          ),

          // Partea de jos: Harta de ghicit
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: Text(
                  'Aici va veni harta interactivă (Google Maps sau flutter_map) pentru ghicit.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}