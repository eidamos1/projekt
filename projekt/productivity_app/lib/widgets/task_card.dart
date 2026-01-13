import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isProcessing = false;

  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.daily: return Colors.blueAccent;
      case TaskType.weekly: return Colors.orangeAccent;
      case TaskType.monthly: return Colors.purpleAccent;
    }
  }

  Future<void> _savePhoto() async {
    final picker = ImagePicker();
    
    // Změna: Na webu je lepší použít Gallery, protože 'Camera' nemusí být v prohlížeči spolehlivá.
    // Ale ImageSource.camera by mělo fungovat (otevře to webkameru nebo výběr souboru).
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera, 
      maxWidth: 500, // Zmenšeno na 500px (bezpečné pro limit 1MB)
      imageQuality: 40, // Kvalita 40%
    );

    if (image == null) return;
    
    setState(() => _isProcessing = true);

    try {
      // KLÍČOVÁ OPRAVA PRO WEB:
      // Místo File(image.path).readAsBytes() musíme použít přímo image.readAsBytes()
      final bytes = await image.readAsBytes();
      
      // Kontrola velikosti (Firestore limit je 1MB, Base64 přidá 33%)
      // Takže bajty musí být menší než cca 750kB.
      if (bytes.lengthInBytes > 750000) {
        throw Exception("Obrázek je i po zmenšení moc velký. Zkus jiný.");
      }

      String base64Image = base64Encode(bytes);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(widget.task.id)
          .update({'imageBase64': base64Image});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Důkaz uložen!')));
      }
    } catch (e) {
      print("Chyba nahrávání: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: ${e.toString().replaceAll("Exception:", "")}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _shareTask() {
    if (widget.task.imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musíš nejdřív vyfotit důkaz! 📸'), backgroundColor: Colors.red),
      );
      return;
    }

    // Odkazy pro sdílení
    String mobileLink = 'adamapp://confirm?code=${widget.task.code}';
    // Pokud testuješ lokálně:
    String webLink = 'https://calendar-mot.web.app/#/confirm?code=${widget.task.code}';
    // Až to nasadíš na Firebase Hosting, změníš to na:
    // String webLink = 'https://tvoje-appka.web.app/#/confirm?code=${widget.task.code}';

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
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _getTypeColor(widget.task.type), width: 5)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${widget.task.typeLabel} • ${widget.task.xp} XP • ${widget.task.coins} Mincí'),
            
            if (widget.task.imageBase64 != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(children: const [
                  Icon(Icons.image, size: 16, color: Colors.green), 
                  SizedBox(width: 4), 
                  Text("Důkaz připojen", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                ]),
              ),

            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton.icon(
                    onPressed: _savePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(widget.task.imageBase64 == null ? "Vyfotit" : "Přefotit"),
                  ),
                ElevatedButton.icon(
                  onPressed: _shareTask,
                  icon: const Icon(Icons.send),
                  label: const Text("Poslat k potvrzení"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getTypeColor(widget.task.type), 
                    foregroundColor: Colors.white
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}