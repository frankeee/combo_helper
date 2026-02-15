// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/favorites_model.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the FavoritesModel for changes
    final model = context.watch<FavoritesModel>();
    
    if (model.favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet'),
      );
    }

    Widget _buildFavoriteItem(BuildContext context, FavoritesModel model, int index) {
      var (filePath, fileName) = model.favorites[index];
      bool isEditing = model.editingIndex == index;
      
      return ListTile(
        key: ValueKey(filePath! + fileName!),
        title: Align(
          alignment: Alignment.centerLeft,
          child: isEditing
              ? TextField(
                  controller: TextEditingController(text: fileName),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  onSubmitted: (newName) {
                    if (newName.isNotEmpty) {
                      model.renameFavorite((filePath, fileName), newName);
                    }
                    model.setEditingIndex(-1);
                  },
                  onTapOutside: (_) {
                    model.setEditingIndex(-1);
                  },
                )
              : GestureDetector(
                  onLongPress: () {
                    model.setEditingIndex(index);
                  },
                  child: Text(fileName),
                ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.delete, color: Colors.black),
          onPressed: () {
            model.removeFavorite((filePath, fileName));
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAudioFile(filePath)) ...[
              IconButton(
                icon: Icon(
                  model.current == index ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                ),
                onPressed: () {
                  if (model.current != index) {
                    model.playAudio(
                      (filePath, fileName),
                      model.getSliderPosition(index),
                      index,
                    );
                  } else {
                    model.pauseAudio();
                    model.setCurrent(-1);
                  }
                },
              ),
              SizedBox(
                width: 100,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.black,
                    inactiveTrackColor: Colors.black26,
                    thumbColor: Colors.black,
                    overlayColor: Colors.black12,
                  ),
                  child: Slider(
                    value: model.getSliderPosition(index).clamp(0.0, 1.0),
                    onChanged: (value) => model.setSliderPosition(index, value),
                  ),
                ),
              ),
            ] else if (_isImageFile(filePath))
                SizedBox(
                  width: 148,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showFullImage(context, filePath, fileName),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, color: Colors.black54),
                      ),
                    ),
                  ),
                )
              else
                SizedBox( width: 148,
                          height: 40,
                          child: const Icon(Icons.insert_drive_file, color: Colors.black54)),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.black),
              onPressed: () async {
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(filePath)],
                      subject: 'Sharing: $fileName',
                    ),
                  );
                } catch (e) {
                  debugPrint('Error sharing file: $e');
                }
              },
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle_rounded, color: Colors.black),
            ),
          ],
        ),
      );
    }


    return ReorderableListView.builder(
      itemCount: model.favorites.length,
      onReorder: (oldIndex, newIndex) {
        model.reorderFavorites(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        return _buildFavoriteItem(context, model, index);
      },
    );
  }
}

bool _isAudioFile(String path) {
  const audioExtensions = ['.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac', '.opus'];
  final lower = path.toLowerCase();
  return audioExtensions.any((ext) => lower.endsWith(ext));
}

bool _isImageFile(String path) {
  const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
  final lower = path.toLowerCase();
  return imageExtensions.any((ext) => lower.endsWith(ext));
}

void _showFullImage(BuildContext context, String filePath, String fileName) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
          ),
        ),
      ),
    ),
  );
}