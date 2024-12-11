import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(StockTrackerApp());
}

class StockTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? LoginPage()
          : HomePage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> loginUser(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => loginUser(context),
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController stockController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> stockData = [];
  String? apiKey = "your_finnhub_api_key"; // Replace with your API key

  Future<void> fetchStockData(String symbol) async {
    final url = Uri.parse('https://finnhub.io/api/v1/quote?symbol=$symbol&token=$apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          stockData.add({
            'symbol': symbol,
            'currentPrice': data['c'],
            'high': data['h'],
            'low': data['l'],
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching stock data: $e')),
      );
    }
  }

  Future<void> addToWatchlist(String symbol) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('watchlist')
          .add({'symbol': symbol});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: stockController,
              decoration: InputDecoration(
                labelText: 'Enter Stock Symbol',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => fetchStockData(stockController.text.trim()),
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: stockData.length,
                itemBuilder: (context, index) {
                  final stock = stockData[index];
                  return ListTile(
                    title: Text('${stock['symbol']}'),
                    subtitle: Text('Current Price: \$${stock['currentPrice']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => addToWatchlist(stock['symbol']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
