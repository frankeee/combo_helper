// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/favorites_model.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Type helpers ─────────────────────────────────────────────────────────────

enum _FileType { audio, image, text, other }

_FileType _detectType(String path) {
  final lower = path.toLowerCase();
  const audio = ['.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac', '.opus'];
  const image = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
  if (audio.any(lower.endsWith)) return _FileType.audio;
  if (image.any(lower.endsWith)) return _FileType.image;
  if (lower.endsWith('.txt')) return _FileType.text;
  return _FileType.other;
}

/// Pokédex accent colour per type.
Color _typeColor(_FileType t) => switch (t) {
      _FileType.audio => const Color.fromARGB(255, 214, 73, 7),
      _FileType.image => const Color.fromARGB(255, 63, 154, 235),
      _FileType.text  => const Color(0xFF43A047),
      _FileType.other => const Color(0xFF757575),
    };

/// Icon per type.
IconData _typeIcon(_FileType t) => switch (t) {
      _FileType.audio => Icons.headphones_rounded,
      _FileType.image => Icons.image_rounded,
      _FileType.text  => Icons.description_rounded,
      _FileType.other => Icons.insert_drive_file_rounded,
    };

/// Badge label per type.
String _typeLabel(_FileType t) => switch (t) {
      _FileType.audio => 'AUDIO',
      _FileType.image => 'IMAGE',
      _FileType.text  => 'TEXT',
      _FileType.other => 'FILE',
    };

// ── Main page ─────────────────────────────────────────────────────────────────

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
                        super.key,
                        required this.folderIndex
                      });
  final int folderIndex;
  @override
  Widget build(BuildContext context) {

    final model = context.watch<FavoritesModel>();

    if (model.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded,
                size: 72, color: Colors.black12),
            const SizedBox(height: 16),
            const Text(
              'No favorites yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black38),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + to get started',
              style: TextStyle(fontSize: 14, color: Colors.black26),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: model.favorites.length,
      onReorder: model.reorderFavorites,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
      itemBuilder: (context, index) {
        final (folderId, filePath, fileName) = model.favorites[index];
        return _FavoriteCard(
          key: ValueKey('$filePath$fileName$index'),
          filePath: filePath!,
          fileName: fileName!,
          index: index,
          model: model,
          folderId:folderId,
        );
      },
    );
  }
}

// ── Card widget ───────────────────────────────────────────────────────────────

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required super.key,
    required this.filePath,
    required this.fileName,
    required this.index,
    required this.model,
    required this.folderId
  });

  final String filePath;
  final String fileName;
  final int index;
  final FavoritesModel model;
  final folderId;

  @override
  Widget build(BuildContext context) {
    final type = _detectType(filePath);
    final color = _typeColor(type);
    final bool isEditing = model.editingIndex == index;

    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Colored left stripe ──────────────────────────────
              Container(
                width: 6,
                color: color,
              ),

              // ── Type icon block ──────────────────────────────────
              Container(
                width: 56,
                color: color.withOpacity(0.08),
                child: Center(
                  child: Icon(_typeIcon(type), color: color, size: 28),
                ),
              ),

              // ── Content ──────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name row + badge
                      Row(
                        children: [
                          Expanded(child: _NameSection(
                            fileName: fileName,
                            filePath: filePath,
                            index: index,
                            model: model,
                            isEditing: isEditing,
                            folderId: folderId,
                          )),
                          const SizedBox(width: 6),
                          _TypeBadge(type: type, color: color),
                        ],
                      ),

                      // Preview / controls
                      if (!isEditing) ...[
                        const SizedBox(height: 8),
                        _PreviewSection(
                          filePath: filePath,
                          fileName: fileName,
                          index: index,
                          model: model,
                          type: type,
                          color: color,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Action column ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionIcon(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red.shade300,
                      tooltip: 'Remove',
                      onTap: () =>
                          model.removeFavorite((filePath, fileName)),
                    ),
                    _ActionIcon(
                      icon: Icons.share_rounded,
                      color: Colors.blueGrey,
                      tooltip: 'Share',
                      onTap: () async {
                        try {
                          await SharePlus.instance.share(ShareParams(
                            files: [XFile(filePath)],
                            subject: 'Sharing: $fileName',
                          ));
                        } catch (e) {
                          debugPrint('Error sharing: $e');
                        }
                      },
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator_rounded,
                            color: Colors.black26, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Name / rename section ────────────────────────────────────────────────────

class _NameSection extends StatelessWidget {
  const _NameSection({
    required this.fileName,
    required this.filePath,
    required this.index,
    required this.model,
    required this.isEditing,
    required this.folderId,
  });

  final String fileName;
  final String filePath;
  final int index;
  final FavoritesModel model;
  final bool isEditing;
  final folderId;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return TextField(
        controller: TextEditingController(text: fileName),
        autofocus: true,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
        ),
        onSubmitted: (newName) {
          if (newName.isNotEmpty) {
            model.renameFavorite((folderId,filePath, fileName), newName);
          }
          model.setEditingIndex(-1);
        },
        onTapOutside: (_) => model.setEditingIndex(-1),
      );
    }

    return GestureDetector(
      onLongPress: () => model.setEditingIndex(index),
      child: Text(
        fileName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          overflow: TextOverflow.ellipsis,
        ),
        maxLines: 1,
      ),
    );
  }
}

// ── Type badge chip ──────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.color});

  final _FileType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _typeLabel(type),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ── Inline action icon ───────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ── Preview / controls per type ───────────────────────────────────────────────

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.filePath,
    required this.fileName,
    required this.index,
    required this.model,
    required this.type,
    required this.color,
  });

  final String filePath;
  final String fileName;
  final int index;
  final FavoritesModel model;
  final _FileType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      _FileType.audio  => _AudioControls(filePath: filePath, fileName: fileName, index: index, model: model, color: color),
      _FileType.image  => _ImagePreview(filePath: filePath, fileName: fileName),
      _FileType.text   => _TextPreview(filePath: filePath, fileName: fileName),
      _FileType.other  => const SizedBox.shrink(),
    };
  }
}

// ── Audio controls ────────────────────────────────────────────────────────────

class _AudioControls extends StatelessWidget {
  const _AudioControls({
    required this.filePath,
    required this.fileName,
    required this.index,
    required this.model,
    required this.color,
  });

  final String filePath;
  final String fileName;
  final int index;
  final FavoritesModel model;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = model.current == index;
    return Row(
      children: [
        InkWell(
          onTap: () {
            if (!isPlaying) {
              model.playAudio(
                  (filePath, fileName), model.getSliderPosition(index), index);
            } else {
              model.pauseAudio();
              model.setCurrent(-1);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
            ),
            child: Slider(
              value: model.getSliderPosition(index).clamp(0.0, 1.0),
              onChanged: (v) => model.setSliderPosition(index, v),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Image preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context, filePath, fileName),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(filePath),
          height: 60,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.black38),
        ),
      ),
    );
  }
}

// ── Text preview ──────────────────────────────────────────────────────────────

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTextViewer(context, filePath, fileName),
      onLongPress: () => _showTextEditor(context, filePath, fileName),
      child: FutureBuilder<String>(
        future: File(filePath).readAsString(),
        builder: (context, snap) {
          final preview = snap.data ?? '';
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Text(
              preview.isEmpty ? 'Tap to view…' : preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade900,
                fontStyle: preview.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Dialogs (unchanged logic, updated style) ──────────────────────────────────

void _showFullImage(
    BuildContext context, String filePath, String fileName) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(filePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64),
            ),
          ),
        ),
      ),
    ),
  );
}

void _showTextViewer(
    BuildContext context, String filePath, String fileName) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.description_rounded,
              color: Color(0xFF43A047), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fileName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: FutureBuilder<String>(
        future: File(filePath).readAsString(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()));
          }
          final text = snap.data ?? '';
          return SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableLinkify(
                text: text,
                onOpen: (link) async {
                  final uri = Uri.parse(link.url);
                  try {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch ${link.url}: $e');
                  }
                },
                options: const LinkifyOptions(humanize: false),
                style: const TextStyle(fontSize: 14),
                linkStyle: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _showTextEditor(context, filePath, fileName);
          },
          child: const Text('Edit'),
        ),
      ],
    ),
  );
}

void _showTextEditor(
    BuildContext context, String filePath, String fileName) async {
  String existing = '';
  try {
    existing = await File(filePath).readAsString();
  } catch (_) {}

  final controller = TextEditingController(text: existing);

  // ignore: use_build_context_synchronously
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.edit_rounded,
              color: Color(0xFF43A047), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Edit — $fileName',
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: TextField(
        controller: controller,
        maxLines: 10,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await File(filePath).writeAsString(controller.text);
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
