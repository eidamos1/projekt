import 'dart:convert'; // Pro dekódování obrázku
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfirmTaskPage extends StatefulWidget {
  const ConfirmTaskPage({super.key});

  @override
  State<ConfirmTaskPage> createState() => _ConfirmTaskPageState();
}

class _ConfirmTaskPageState extends State<ConfirmTaskPage> {
  final _codeController = TextEditingController();
  bool _isInit = true;
  bool _isLoading = false;
  
  Map<String, dynamic>? _taskData;
  DocumentReference? _taskRef;
  DocumentReference? _userRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _codeController.text = args;
        WidgetsBinding.instance.addPostFrameCallback((_) => _findTask());
      }
      _isInit = false;
    }
  }

  // 1. Najít úkol a ukázat náhled
  Future<void> _findTask() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() { _isLoading = true; _taskData = null; });

    try {
      // Hledáme napříč všemi uživateli (neefektivní pro miliony, ok pro školu)
      final users = await FirebaseFirestore.instance.collection('users').get();
      
      for (var userDoc in users.docs) {
        final tasks = await userDoc.reference.collection('tasks').where('code', isEqualTo: code).get();
        if (tasks.docs.isNotEmpty) {
          var tDoc = tasks.docs.first;
          var data = tDoc.data();
          if (!(data['completed'] ?? false)) {
            setState(() {
              _taskData = data;
              _taskRef = tDoc.reference;
              _userRef = userDoc.reference;
            });
          } else {
             _showSnack('Tento kód už byl použit.');
          }
          break; // Našli jsme
        }
      }
      if (_taskData == null && mounted) _showSnack('Úkol s tímto kódem nenalezen.');
    } catch (e) {
      _showSnack('Chyba: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Potvrdit a přičíst odměny
  Future<void> _confirm() async {
    if (_taskRef == null || _userRef == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final userSnap = await tx.get(_userRef!);
        final userData = userSnap.data() as Map<String, dynamic>;

        // Aktuální stav
        int currentXp = userData['xp'] ?? 0;
        int currentCoins = userData['coins'] ?? 0;
        
        // Odměna z úkolu
        int rewardXp = _taskData!['xp'] ?? 0;
        int rewardCoins = _taskData!['coins'] ?? 0;

        // Nový stav
        int newXp = currentXp + rewardXp;
        int newCoins = currentCoins + rewardCoins;
        
        // VÝPOČET LEVELU: (Celkové XP děleno 100) + 1
        // 0-99 XP = Level 1, 100-199 XP = Level 2, atd.
        int newLevel = (newXp ~/ 100) + 1;

        tx.update(_userRef!, {
          'xp': newXp,
          'coins': newCoins,
          'level': newLevel,
        });
        
        // Smazat úkol (nebo nastavit completed: true)
        tx.update(_taskRef!, {
          'completed': true,
        });
      });

      if (mounted) {
        _showSnack('Potvrzeno! Odměna připsána.');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Chyba transakce: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Potvrzení úkolu')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Kód úkolu', 
                border: OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: _findTask)
              ),
            ),
            SizedBox(height: 20),
            if (_isLoading) CircularProgressIndicator(),

            if (_taskData != null && !_isLoading) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text("Potvrzuješ úkol:", style: TextStyle(color: Colors.grey)),
                      Text(_taskData!['title'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      
                      // Zobrazení obrázku z Base64
                      if (_taskData!['imageBase64'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_taskData!['imageBase64']),
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(height: 100, color: Colors.grey[200], child: Center(child: Text("Bez fotky"))),

                      SizedBox(height: 20),
                      Text("Odměna: ${_taskData!['xp']} XP | ${_taskData!['coins']} Mincí", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.all(16)),
                          child: Text("POTVRDIT SPLNĚNÍ", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}