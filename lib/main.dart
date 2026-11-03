import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'ui/player_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const LayerPlayApp());
}

class LayerPlayApp extends StatelessWidget {
  const LayerPlayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LayerPlay',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: false, // never pull a multi-GB file into memory
      withReadStream: false,
    );
    final f = res?.files.single;
    if (f?.path == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(path: f!.path!, name: f.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_outline,
                  size: 84, color: Palette.accent),
              const SizedBox(height: 16),
              const Text('LayerPlay',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Play a video with your own audio on top.',
                  style: TextStyle(color: Palette.textDim)),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open video'),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.accent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
