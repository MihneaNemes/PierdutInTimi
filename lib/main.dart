// lib/main.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Importul pentru setările Android este necesar, dar poate fi problematic.
// Folosim importul standard din 'webview_flutter' pentru a evita erorile de tip
// 'undefined_method' care apar din cauza conflictelor de versiune/implementare.
// Asigură-te că rulezi 'flutter pub get' după ce adaugi pachetul în pubspec.yaml.


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
      // Am folosit direct GameScreen (nu ai nevoie de 'const' la GameScreen() aici)
      home: GameScreen(),
    );
  }
}

// -----------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  // Adaugat 'const' constructor pentru a respecta 'info:'
  const GameScreen({super.key});

  // Schimbat tipul de retur la State<GameScreen> pentru a rezolva 'library_private_types_in_public_api'
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _currentMapillaryImageId;

  // Citirea cheilor din .env cu denumiri corecte (lowerCamelCase)
  final String mapillaryAccessToken = dotenv.env['MAPILLARY_ACCESS_TOKEN'] ?? 'MAPILLARY_TOKEN_ERROR';
  final String mapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'GOOGLE_API_KEY_ERROR';

  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _startNewRound();
  }

  // Simplificarea inițializării WebViewController pentru a evita erorile de implementare
  void _initializeWebViewController() {
    // În versiunile recente, setările specifice platformei sunt adesea aplicate
    // automat sau nu sunt necesare. Eliminăm apelurile problematice.

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

    // Odată ce _webViewController este inițializat, poți încărca prima pagină.
  }

  // Funcție pentru a apela API-ul Mapillary
  void _startNewRound() async {
    const String bbox = '21.17,45.72,21.28,45.79';

    // ATENȚIE: Folosim numele variabilei corecte: mapillaryAccessToken
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

  // Functia pentru a crea codul HTML/JS care va rula Mapillary Viewer
  String _buildMapillaryHtml(String imageKey, String accessToken) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="https://unpkg.com/mapillary-js/dist/mapillary.min.js"></script>
          <style>
              body { margin: 0; }
              #mly { width: 100vw; height: 100vh; }
          </style>
      </head>
      <body>
          <div id="mly"></div>
          <script>
              var mly = new Mapillary.Viewer({
                  container: "mly",
                  accessToken: "$accessToken",
                  imageId: "$imageKey",
                  // Opțiunile de navigație pot fi dezactivate pentru GeoGuessr-like
                  component: {
                    cover: false,
                    attribution: false,
                    zoom: false,
                    bearing: false,
                    compass: false,
                  }
              });
              // Asigură-te că vizualizatorul se redimensionează corect
              window.addEventListener("resize", () => mly.resize());
          </script>
      </body>
      </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    // LOGICĂ CORECTATĂ: Încarcă HTML-ul ÎN BUILD, folosind mapillaryAccessToken
    if (_currentMapillaryImageId != null) {
      _webViewController.loadHtmlString(
        _buildMapillaryHtml(
          _currentMapillaryImageId!,
          mapillaryAccessToken, // ATENȚIE: Variabilă corectă
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
            child: _currentMapillaryImageId == null
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : WebViewWidget(
              controller: _webViewController,
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