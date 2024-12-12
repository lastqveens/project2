// ignore_for_file: use_build_context_synchronously

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const StockTrackerApp());
}

class StockTrackerApp extends StatelessWidget {
  const StockTrackerApp({super.key});

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

  LoginPage({super.key});

  Future<void> loginUser(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => loginUser(context),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController stockController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> stockData = [];
  List<Map<String, dynamic>> newsData = [];
  List<String> watchlist = [];
  String? apiKey = "ctd32j9r01qlc0uvurv0ctd32j9r01qlc0uvurvg"; // Replace with your API key
  String? newsApiKey = "YOUR_NEWS_API_KEY"; // Replace with your news API key

  @override
  void initState() {
    super.initState();
    fetchNews(); // Fetch news when the page is initialized
    loadWatchlist(); // Load watchlist when the page is initialized
  }

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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch stock data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching stock data: $e')),
      );
    }
  }

  Future<void> fetchNews() async {
    final url = Uri.parse('https://newsapi.org/v2/everything?q=finance&apiKey=$newsApiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          newsData = List<Map<String, dynamic>>.from(data['articles']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch news data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching news data: $e')),
      );
    }
  }

  Future<void> loadWatchlist() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final snapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('watchlist')
        .get();
    final loadedWatchlist = snapshot.docs.map((doc) => doc['symbol'] as String).toList();
    setState(() {
      watchlist = loadedWatchlist;
    });
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
      loadWatchlist(); // Refresh the watchlist after adding a stock
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.greenAccent,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Stock Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: stockController,
              decoration: InputDecoration(
                labelText: 'Enter Stock Symbol',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => fetchStockData(stockController.text.trim()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: stockData.length,
                itemBuilder: (context, index) {
                  final stock = stockData[index];
                  return ListTile(
                    title: Text('${stock['symbol']}'),
                    subtitle: Text('Current Price: \$${stock['currentPrice']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => addToWatchlist(stock['symbol']),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 40),
            const Text('Your Watchlist', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: watchlist.length,
                itemBuilder: (context, index) {
                  final symbol = watchlist[index];
                  return ListTile(
                    title: Text(symbol),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          final snapshot = await firestore
                              .collection('users')
                              .doc(user.uid)
                              .collection('watchlist')
                              .where('symbol', isEqualTo: symbol)
                              .get();
                          for (var doc in snapshot.docs) {
                            await doc.reference.delete(); // Remove from Firestore
                          }
                          loadWatchlist(); // Refresh the watchlist
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 40),
            const Text('Financial News', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: newsData.length,
                itemBuilder: (context, index) {
                  final news = newsData[index];
                  return ListTile(
                    title: Text(news['title']),
                    subtitle: Text(news['description'] ?? ''),
                    onTap: () {
                      // Optionally, you can open the news article in a browser
                    },
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