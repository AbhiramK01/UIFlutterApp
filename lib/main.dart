import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_signup_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
   if(kIsWeb) {
     await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: "AIzaSyC6gFOv-ywT8pwdF3wmDieoVOKNYf6WjNc",
        authDomain: "uiflutter-75803.firebaseapp.com",
        projectId: "uiflutter-75803",
        storageBucket: "uiflutter-75803.firebasestorage.app",
        messagingSenderId: "21123554400",
        appId: "1:21123554400:web:444227c3831672e6923705",
        measurementId: "G-20TDXWVM6J"));
  }
  else{
     await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenFoodFacts Scanner',
      theme: ThemeData(primarySwatch: Colors.teal),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginSignupPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _scanResult = 'Scan a barcode to see product details';
  final List<Map<String, String>> _searchHistory = []; // To store search history
  String? _productImageUrl; // For product image

  Future<void> _scanBarcode() async {
    try {
      var scanResult = await BarcodeScanner.scan();
      if (scanResult.rawContent.isNotEmpty) {
        await _fetchProductDetails(scanResult.rawContent);
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Error scanning barcode: $e';
      });
    }
  }

  Future<void> _fetchProductDetails(String barcode) async {
    final apiUrl = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('product')) {
          final product = data['product'];
          final productName = product['product_name'] ?? 'Unknown Product';
          final formattedDetails = _formatProductDetails(product);

          // Save to history
          setState(() {
            _productImageUrl = product['image_url'];
            _searchHistory.add({'barcode': barcode, 'name': productName});
            if (_searchHistory.length > 10) {
              _searchHistory.removeAt(0); // Keep only the last 10 searches
            }
            _scanResult = formattedDetails;
          });
        } else {
          setState(() {
            _scanResult = 'Product not available in the OpenFoodFacts database.';
            _productImageUrl = null;
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _scanResult = 'Product not available in the OpenFoodFacts database.';
          _productImageUrl = null;
        });
      } else {
        setState(() {
          _scanResult =
          'Failed to fetch product details. Status code: ${response.statusCode}';
          _productImageUrl = null;
        });
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Error fetching product details: $e';
        _productImageUrl = null;
      });
    }
  }

  String _formatProductDetails(Map<String, dynamic> product) {
    final productName = product['product_name'] ?? 'Unknown Product';
    final barcode = product['code'] ?? 'Unknown Barcode';
    final imageUrl = product['image_url'] ?? 'No Image Available';
    final nutritionData = product['nutriments'] ?? {};

    // Extract nutritional values
    final energy = nutritionData['energy-kcal_100g'] ?? 'N/A';
    final protein = nutritionData['proteins_100g'] ?? 'N/A';
    final fat = nutritionData['fat_100g'] ?? 'N/A';
    final carbohydrates = nutritionData['carbohydrates_100g'] ?? 'N/A';

    return '''
Product Name: $productName
Barcode: $barcode

Nutritional Values (per 100g):
- Energy: $energy kcal
- Protein: $protein g
- Fat: $fat g
- Carbohydrates: $carbohydrates g
    ''';
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
  }

  void _showSearchHistory() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          children: [
            ListTile(
              title: const Text('Search History', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _clearHistory,
                tooltip: 'Clear History',
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchHistory.length,
                itemBuilder: (context, index) {
                  final entry = _searchHistory[index];
                  return ListTile(
                    title: Text(entry['name']!),
                    subtitle: Text('Barcode: ${entry['barcode']}'),
                    onTap: () {
                      Navigator.pop(context);
                      _fetchProductDetails(entry['barcode']!);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenFoodFacts Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_productImageUrl != null)
              Card(
                elevation: 4,
                child: Image.network(
                  _productImageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _scanResult,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _scanBarcode,
                  child: const Text('Scan Barcode'),
                ),
                ElevatedButton(
                  onPressed: _showSearchHistory,
                  child: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
