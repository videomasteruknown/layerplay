import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/playback_engine.dart';
import 'offset_lane.dart';
import 'theme.dart';

Future<void> showAudioPanel(BuildContext context, PlaybackEngine engine) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.of(context).size.height * 0.92,
    ),
    builder: (_) => _AudioPanel(engine: engine),
  );
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.engine});
  final PlaybackEngine engine;

  Future<void> _import(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: false,
      withReadStream: false,
    );
    final f = res?.files.single;
    if (f?.path == null) return;
    await engine.loadAudio(f!.path!, f.name);
  }

  Future<void> _exactOffset(BuildContext context) async {
    final ctl =
        TextEditingController(text: engine.audioOffsetMs.value.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        title: const Text('Audio offset (ms)'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
          decoration: const InputDecoration(
            helperText: 'Positive delays the audio, negative starts it earlier',
          ),
          onSubmitted: (s) => Navigator.pop(ctx, int.tryParse(s)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text)),
              child: const Text('Apply')),
        ],
      ),
    );
    if (v != null) engine.setOffset(v);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Palette.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Audio layer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            // file row
            ValueListenableBuilder<String?>(
              valueListenable: engine.audioName,
              builder: (ctx, name, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      name ?? 'No audio file added',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: name == null ? Palette.textDim : Palette.text),
                    ),
                  ),
                  if (name != null)
                    TextButton(
                        onPressed: engine.clearAudio,
                        child: const Text('Remove')),
                  FilledButton.tonalIcon(
                    onPressed: () => _import(ctx),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(name == null ? 'Add audio' : 'Replace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _VolumeRow(
              icon: Icons.movie_outlined,
              label: 'Video sound',
              notifier: engine.videoVolume,
              onChanged: engine.setVideoVolume,
            ),
            _VolumeRow(
              icon: Icons.music_note_outlined,
              label: 'Added audio',
              notifier: engine.audioVolume,
              onChanged: engine.setAudioVolume,
            ),
            const SizedBox(height: 14),

            // offset
            ValueListenableBuilder<int>(
              valueListenable: engine.audioOffsetMs,
              builder: (ctx, ms, _) => Row(
                children: [
                  const Text('Sync offset',
                      style: TextStyle(color: Palette.textDim)),
                  const Spacer(),
                  InkWell(
                    onTap: () => _exactOffset(ctx),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        fmtOffset(ms),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Palette.accent,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                      onPressed: () => engine.setOffset(0),
                      child: const Text('Reset')),
                ],
              ),
            ),
            OffsetLane(engine: engine),
            const SizedBox(height: 12),
            _nudgeRow(const [-1000, -100, -10, -1]),
            const SizedBox(height: 8),
            _nudgeRow(const [1, 10, 100, 1000]),
          ],
        ),
      ),
    );
  }

  Widget _nudgeRow(List<int> steps) => Row(
        children: [
          for (final s in steps)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.text,
                    side: const BorderSide(color: Palette.line),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () =>
                      engine.setOffset(engine.audioOffsetMs.value + s),
                  child: Text(s > 0 ? '+$s' : '$s'),
                ),
              ),
            ),
        ],
      );
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.notifier,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final ValueNotifier<double> notifier;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (_, v, __) => Row(
        children: [
          Icon(v == 0 ? Icons.volume_off : icon,
              size: 20, color: Palette.textDim),
          SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
          ),
          Expanded(
            child: Slider(value: v, min: 0, max: 100, onChanged: onChanged),
          ),
          SizedBox(
            width: 38,
            child: Text('${v.round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Palette.textDim, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
