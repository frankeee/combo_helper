// ignore_for_file: no_leading_underscores_for_local_identifiers, use_build_context_synchronously

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/favorites_model.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kBrown = Color(0xFF2C221E);
const _kBrownMid = Color(0xFF8A7A72);
const _kBrownLight = Color(0xFFB0A49C);
const _kBorder = Color(0xFFEDE8E2);

// ── Type helpers ──────────────────────────────────────────────────────────────

enum _FileType { audio, image, text, pdf, video, other }

_FileType _detectType(String path) {
  final lower = path.toLowerCase();
  const audio = ['.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac', '.opus'];
  const image = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
  const video = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp'];  // ← new
  if (audio.any(lower.endsWith)) return _FileType.audio;
  if (image.any(lower.endsWith)) return _FileType.image;
  if (video.any(lower.endsWith)) return _FileType.video; 
  if (lower.endsWith('.txt')) return _FileType.text;
  if (lower.endsWith('.pdf')) return _FileType.pdf;  
  return _FileType.other;
}

/// Accent color per type.
Color _typeColor(_FileType t) => switch (t) {
      _FileType.audio => const Color(0xFFD4724A),
      _FileType.image => const Color(0xFF4A8EC2),
      _FileType.text  => const Color(0xFF4CAF7D),
      _FileType.pdf   => const Color(0xFFD44A54),
      _FileType.video => const Color(0xFF7C4DFF), 
      _FileType.other => const Color(0xFF8A8EA0),
    };

/// Background tint per type.
Color _typeBg(_FileType t) => switch (t) {
      _FileType.audio => const Color(0xFFFFF3EE),
      _FileType.image => const Color(0xFFEFF5FF),
      _FileType.text  => const Color(0xFFF0FAF4),
      _FileType.pdf   => const Color(0xFFFFF0F0),
      _FileType.video => const Color(0xFFF3EEFF),
      _FileType.other => const Color(0xFFF2F2F6),
    };

/// Icon per type.
IconData _typeIcon(_FileType t) => switch (t) {
      _FileType.audio => Icons.headphones_rounded,
      _FileType.image => Icons.image_rounded,
      _FileType.text  => Icons.description_rounded,
      _FileType.pdf   => Icons.picture_as_pdf_rounded,
      _FileType.video => Icons.videocam_rounded,
      _FileType.other => Icons.insert_drive_file_rounded,
    };

/// Badge label per type.
String _typeLabel(_FileType t) => switch (t) {
      _FileType.audio => 'AUDIO',
      _FileType.image => 'IMAGE',
      _FileType.text  => 'TEXT',
      _FileType.pdf   => 'PDF',
      _FileType.video => 'VIDEO',      
      _FileType.other => 'FILE',
    };

// ── Main page ─────────────────────────────────────────────────────────────────

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.folderIndex,
    this.searchQuery = '',
  });
  final int folderIndex;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FavoritesModel>();

    final filtered = searchQuery.isEmpty
        ? model.favorites
        : model.favorites
            .where((f) =>
                (f.$3 ?? '').toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    if (searchQuery.isEmpty && model.favorites.isEmpty) {
      return _EmptyState(
        icon: Icons.attach_file_rounded,
        title: 'No files yet',
        subtitle: 'Tap + to add files or notes',
      );
    }

    if (searchQuery.isNotEmpty && filtered.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try a different search term',
      );
    }

    if (searchQuery.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final (folderId, filePath, fileName) = filtered[index];
          return _FavoriteCard(
            key: ValueKey('search_$filePath$index'),
            filePath: filePath!,
            fileName: fileName!,
            index: index,
            model: model,
            folderId: folderId,
            showDragHandle: false,
          );
        },
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
      itemCount: model.favorites.length,
      onReorder: model.reorderFavorites,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final elevation = Tween<double>(begin: 0, end: 10).evaluate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          return Material(
            color: Colors.transparent,
            elevation: elevation,
            borderRadius: BorderRadius.circular(14),
            shadowColor: _kBrown.withValues(alpha: 0.1),
            child: child,
          );
        },
      ),
      itemBuilder: (context, index) {
        final (folderId, filePath, fileName) = model.favorites[index];
        return _FavoriteCard(
          key: ValueKey('fav_$filePath$index'),
          filePath: filePath!,
          fileName: fileName!,
          index: index,
          model: model,
          folderId: folderId,
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _kBrown.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: _kBrownLight),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kBrown,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: _kBrownLight,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
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
    required this.folderId,
    this.showDragHandle = true,
  });

  final String filePath;
  final String fileName;
  final int index;
  final FavoritesModel model;
  final int folderId;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final type = _detectType(filePath);
    final color = _typeColor(type);
    final bool isEditing = model.editingIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(filePath),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            model.removeFavorite((folderId, filePath, fileName));
            return true;
          } else {
            try {
              await SharePlus.instance.share(ShareParams(
                files: [XFile(filePath)],
                subject: 'Sharing: $fileName',
              ));
            } catch (e) {
              debugPrint('Error sharing: $e');
            }
            return false;
          }
        },
        background: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF4A8EC2),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: const [
              Icon(Icons.share_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD44A54),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Colored left stripe ──────────────────────────
                    Container(
                      width: 4,
                      color: color,
                    ),

                    // ── Type icon block ──────────────────────────────
                    Container(
                      width: 52,
                      color: _typeBg(type),
                      child: Center(
                        child: Icon(_typeIcon(type), color: color, size: 24),
                      ),
                    ),

                    // ── Content ──────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name row + badge
                            Row(
                              children: [
                                Expanded(
                                  child: _NameSection(
                                    fileName: fileName,
                                    filePath: filePath,
                                    index: index,
                                    model: model,
                                    isEditing: isEditing,
                                    folderId: folderId,
                                  ),
                                ),
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

                    // ── Drag handle ──────────────────────────────────
                    if (showDragHandle)
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: _kBrownLight.withValues(alpha: 0.6),
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Name / rename section ─────────────────────────────────────────────────────

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
  final int folderId;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return TextField(
        controller: TextEditingController(text: fileName),
        autofocus: true,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: _kBrown,
          letterSpacing: -0.2,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
          filled: false,
        ),
        onSubmitted: (newName) async {
          if (newName.isNotEmpty) {
            final sourceFile = File(filePath);
            final appDir = await getApplicationDocumentsDirectory();
            var extension = ".${filePath.split('.').last}";
            final destPath = path.join(appDir.path, newName + extension);
            await sourceFile.copy(destPath);
            model.renameFavorite((folderId, filePath, fileName), newName, destPath);
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
            
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
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: _kBrown,
          letterSpacing: -0.2,
          overflow: TextOverflow.ellipsis,
        ),
        maxLines: 1,
      ),
    );
  }
}

// ── Type badge chip ───────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.color});

  final _FileType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
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
      _FileType.audio => _AudioControls(
          filePath: filePath,
          fileName: fileName,
          index: index,
          model: model,
          color: color),
      _FileType.image =>
        _ImagePreview(filePath: filePath, fileName: fileName),
      _FileType.text =>
        _TextPreview(filePath: filePath, fileName: fileName),
      _FileType.pdf =>
        _PdfPreview(filePath: filePath, fileName: fileName),
      _FileType.video => 
        _VideoPreview(filePath: filePath, fileName: fileName),
      _FileType.other => const SizedBox.shrink(),
    };
  }
}

// ── New: inline video preview card ───────────────────────────────────────────
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7C4DFF);
    return GestureDetector(
      onTap: () => _showVideoPlayer(context, widget.filePath, widget.fileName),
      child: Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EEFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail from first frame
            if (_ready)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _ctrl.value.size.width,
                    height: _ctrl.value.size.height,
                    child: VideoPlayer(_ctrl),
                  ),
                ),
              )
            else
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFF7C4DFF),
                    strokeWidth: 2,
                  ),
                ),
              ),

            // Dark scrim so the play button is always readable
            Container(color: Colors.black.withValues(alpha: 0.30)),

            // Duration badge — bottom-right
            if (_ready)
              Positioned(
                bottom: 5,
                right: 7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _fmt(_ctrl.value.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Play button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── New: full-screen video player page ───────────────────────────────────────
void _showVideoPlayer(
    BuildContext context, String filePath, String fileName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _VideoPlayerPage(filePath: filePath, fileName: fileName),
    ),
  );
}

class _VideoPlayerPage extends StatefulWidget {
  const _VideoPlayerPage({required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      });
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7C4DFF);
    final value = _ctrl.value;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            if (_initialized)
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7C4DFF),
                  strokeWidth: 2.5,
                ),
              ),

            // Overlay controls
            if (_showControls && _initialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play / Pause centred
                      GestureDetector(
                        onTap: () {
                          value.isPlaying ? _ctrl.pause() : _ctrl.play();
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Progress row
                      Row(
                        children: [
                          Text(
                            _fmt(position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                                activeTrackColor: color,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.2),
                                thumbColor: color,
                                overlayColor:
                                    color.withValues(alpha: 0.15),
                              ),
                              child: Slider(
                                value: progress,
                                onChanged: (v) {
                                  final target = Duration(
                                    milliseconds:
                                        (v * duration.inMilliseconds)
                                            .round(),
                                  );
                                  _ctrl.seekTo(target);
                                },
                              ),
                            ),
                          ),
                          Text(
                            _fmt(duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = model.current == index;

    return Row(
      children: [
        // Play / Pause button
        GestureDetector(
          onTap: () {
            if (!isPlaying) {
              model.playAudio(
                  (filePath, fileName), model.getSliderPosition(index), index);
            } else {
              model.pauseAudio();
              model.setCurrent(-1);
            }
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Slider + time
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.15),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: model.getSliderPosition(index).clamp(0.0, 1.0),
              onChanged: (v) => model.setSliderPosition(index, v),
            ),
          ),
        ),
        // Time display
        SizedBox(
          width: 38,
          child: FutureBuilder<Duration>(
            future: model.getAudioDuration(filePath),
            builder: (context, snapshot) {
              final total = snapshot.data ?? Duration.zero;
              final pos = Duration(
                milliseconds:
                    (model.getSliderPosition(index) * total.inMilliseconds)
                        .round(),
              );
              return Text(
                isPlaying ? _fmt(pos) : _fmt(total),
                style: const TextStyle(
                  fontSize: 12,
                  color: _kBrownMid,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              );
            },
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
          height: 64,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.broken_image_rounded,
                color: Color(0xFF4A8EC2), size: 28),
          ),
        ),
      ),
    );
  }
}

// ── PDF preview ───────────────────────────────────────────────────────────────

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPdfViewer(context, filePath, fileName),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFD44A54).withValues(alpha: 0.2),
              width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFD44A54), size: 16),
            const SizedBox(width: 8),
            const Text(
              'Tap to open PDF',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFD44A54),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color(0xFFD44A54).withValues(alpha: 0.5),
              size: 12,
            ),
          ],
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
          final isEmpty = preview.trim().isEmpty;
          return Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF4CAF7D).withValues(alpha: 0.2),
                  width: 1),
            ),
            child: Text(
              isEmpty ? 'Tap to view note…' : preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isEmpty
                    ? const Color(0xFF4CAF7D).withValues(alpha: 0.5)
                    : const Color(0xFF2E6B4F),
                fontStyle:
                    isEmpty ? FontStyle.italic : FontStyle.normal,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── PDF Viewer ────────────────────────────────────────────────────────────────

void _showPdfViewer(
    BuildContext context, String filePath, String fileName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _PdfViewerPage(filePath: filePath, fileName: fileName),
    ),
  );
}

class _PdfViewerPage extends StatefulWidget {
  const _PdfViewerPage({required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  State<_PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<_PdfViewerPage> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0EBE6)),
        ),
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C221E),
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF2C221E),
        ),
      ),
      body: PdfViewPinch(
        controller: _controller,
        scrollDirection: Axis.vertical,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          errorBuilder: (_, error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFD44A54), size: 40),
                const SizedBox(height: 12),
                Text(
                  'Failed to load PDF',
                  style: const TextStyle(
                    color: _kBrown,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFD4A574),
              strokeWidth: 2.5,
            ),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFD4A574),
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Full image dialog ─────────────────────────────────────────────────────────

void _showFullImage(
    BuildContext context, String filePath, String fileName) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(filePath),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 200,
                color: const Color(0xFF1A1410),
                child: const Icon(Icons.broken_image_rounded,
                    color: Color(0xFF6B5E56), size: 48),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Text viewer dialog ────────────────────────────────────────────────────────

void _showTextViewer(
    BuildContext context, String filePath, String fileName) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF4),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.description_rounded,
                color: Color(0xFF4CAF7D), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kBrown,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: FutureBuilder<String>(
        future: File(filePath).readAsString(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD4A574),
                  strokeWidth: 2.5,
                ),
              ),
            );
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
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: _kBrown,
                ),
                linkStyle: const TextStyle(
                  color: Color(0xFF4A8EC2),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF4A8EC2),
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
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

// ── Text editor dialog ────────────────────────────────────────────────────────

void _showTextEditor(
    BuildContext context, String filePath, String fileName) async {
  String existing = '';
  try {
    existing = await File(filePath).readAsString();
  } catch (_) {}

  final controller = TextEditingController(text: existing);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF4),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.edit_rounded,
                color: Color(0xFF4CAF7D), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kBrown,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: controller,
        maxLines: 10,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: _kBrown,
        ),
        decoration: const InputDecoration(
          hintText: 'Write something…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await File(filePath).writeAsString(controller.text);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
