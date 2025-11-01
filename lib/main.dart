// lib/main.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

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
  final String mapillaryAccessToken = dotenv.env['MAPILLARY_ACCESS_TOKEN'] ?? 'MAPILLARY_TOKEN_ERROR';
  final String mapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'GOOGLE_API_KEY_ERROR';

  late final WebViewController _webViewController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _loadAssetsAndStartRound();
  }

  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('Eroare WebView: ${error.description}, URL: ${error.url}');
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

  // Load Mapillary viewer with inlined JavaScript using base64
  Future<void> _loadMapillaryViewer(String imageKey, String accessToken) async {
    debugPrint('Loading Mapillary viewer with imageKey: $imageKey');

    // Load all required assets
    String htmlTemplate = await rootBundle.loadString('assets/mapillary_template.html');
    String mapillaryJs = await rootBundle.loadString('assets/mapillary.js');
    String mapillaryCss = await rootBundle.loadString('assets/mapillary.css');

    debugPrint('All assets loaded successfully');
    debugPrint('Mapillary JS size: ${mapillaryJs.length} characters');
    debugPrint('Mapillary CSS size: ${mapillaryCss.length} characters');

    // Base64 encode the JavaScript to safely embed it
    String base64Js = base64.encode(utf8.encode(mapillaryJs));
    debugPrint('Base64 JS size: ${base64Js.length} characters');

    // Replace placeholders
    String finalHtml = htmlTemplate
        .replaceAll('MAPILLARY_CSS_CONTENT', mapillaryCss)
        .replaceAll('MAPILLARY_JS_BASE64', base64Js)
        .replaceAll('MAP_ACCESS_TOKEN_PLACEHOLDER', accessToken)
        .replaceAll('MAP_IMAGE_KEY_PLACEHOLDER', imageKey);

    debugPrint('Placeholders replaced, final HTML size: ${finalHtml.length} characters');
    debugPrint('Loading HTML string');

    // Load HTML directly
    await _webViewController.loadHtmlString(finalHtml);

    debugPrint('HTML string loaded into WebView');
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = _currentMapillaryImageId != null && _isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pierdut în Timi'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: isReady
                ? FutureBuilder<void>(
              future: _loadMapillaryViewer(_currentMapillaryImageId!, mapillaryAccessToken),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return WebViewWidget(controller: _webViewController);
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
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: Text('Aici va veni harta interactivă.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}