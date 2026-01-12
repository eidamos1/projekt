import 'dart:convert'; // Pro base64Encode
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  TaskCard({required this.task});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isProcessing = false;

  // Barvy podle typu
  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.daily: return Colors.blueAccent;
      case TaskType.weekly: return Colors.orangeAccent;
      case TaskType.monthly: return Colors.purpleAccent;
    }
  }

  // Funkce pro uložení fotky přímo do DB (Base64)
  Future<void> _savePhoto() async {
    final picker = ImagePicker();
    // Důležité: imageQuality a maxWidth drasticky sníží velikost, aby se to vešlo do DB!
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera, 
      maxWidth: 600, 
      imageQuality: 50
    );

    if (image == null) return;
    setState(() => _isProcessing = true);

    try {
      // Převedeme soubor na bajty a pak na String
      final bytes = await File(image.path).readAsBytes();
      String base64Image = base64Encode(bytes);

      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Uložíme string do dokumentu úkolu
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(widget.task.id) // Firestore ID dokumentu
          .update({'imageBase64': base64Image});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Důkaz uložen!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: fotka je asi moc velká.')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _shareTask() {
    // Kontrola: Bez fotky nepustíme dál
    if (widget.task.imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Musíš nejdřív vyfotit důkaz! 📸'), backgroundColor: Colors.red),
      );
      return;
    }

    String mobileLink = 'adamapp://confirm?code=${widget.task.code}';
    // Pokud máš web hosting, dej sem svou URL, jinak třeba localhost pro demo
    String webLink = 'https://calendar-mot.web.app/#/confirm?code=${widget.task.code}';

    Share.share(
      'Čau! Mám hotovo: "${widget.task.title}".\n'
      'Koukni na fotku v appce a potvrď mi to!\n\n'
      '📱 V aplikaci: $mobileLink\n'
      '💻 Na webu: $webLink'
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _getTypeColor(widget.task.type), width: 5)),
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('${widget.task.typeLabel} • ${widget.task.xp} XP • ${widget.task.coins} Mincí'),
            
            // Indikátor, že fotka je nahraná
            if (widget.task.imageBase64 != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(children: [Icon(Icons.image, size: 16, color: Colors.green), SizedBox(width: 4), Text("Důkaz připojen", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
              ),

            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isProcessing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton.icon(
                    onPressed: _savePhoto,
                    icon: Icon(Icons.camera_alt),
                    label: Text(widget.task.imageBase64 == null ? "Vyfotit" : "Přefotit"),
                  ),
                ElevatedButton.icon(
                  onPressed: _shareTask,
                  icon: Icon(Icons.send),
                  label: Text("Poslat k potvrzení"),
                  style: ElevatedButton.styleFrom(backgroundColor: _getTypeColor(widget.task.type), foregroundColor: Colors.white),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}