// ignore_for_file: no_leading_underscores_for_local_identifiers, unused_element
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/folders_model.dart';
import '../models/favorites_model.dart';
import 'favorites_home_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kBrown = Color(0xFF2C221E);
const _kBrownMid = Color(0xFF8A7A72);
const _kBrownLight = Color(0xFFB0A49C);
const _kAccent = Color(0xFFD4A574);
const _kBackground = Color(0xFFF5F1EE);
const _kBorder = Color(0xFFEDE8E2);

// ── Stripe palette ────────────────────────────────────────────────────────────

const _kStripeColors = [
  Color(0xFFD4A574), // warm gold
  Color(0xFF8B6F5E), // mocha
  Color(0xFF7A9E7E), // sage
  Color(0xFF9B8BB4), // lavender
  Color(0xFF6B9BBD), // steel blue
  Color(0xFFBD7B7B), // dusty rose
];

// ── Main page ─────────────────────────────────────────────────────────────────

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key, this.searchQuery = ''});

  final searchQuery;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FoldersModel>();

    final filtered = searchQuery.isEmpty
        ? model.folders
        : model.folders
            .where((f) =>
                (f.$2 ?? '').toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    if (searchQuery.isEmpty && model.folders.isEmpty) {
      return _EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No folders yet',
        subtitle: 'Tap + to create your first folder',
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
          final (folderId, fileName) = filtered[index];
          return _FolderCard(
            key: ValueKey('search_$fileName$index'),
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
      itemCount: model.folders.length,
      onReorder: model.reorderFolders,
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
            shadowColor: _kBrown.withValues(alpha: 0.15),
            child: child,
          );
        },
      ),
      itemBuilder: (context, index) {
        final (folderId, fileName) = model.folders[index];
        return _FolderCard(
          key: ValueKey('folder_$folderId$index'),
          folderId: folderId,
          fileName: fileName!,
          index: index,
          model: model,
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

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required super.key,
    required this.folderId,
    required this.fileName,
    required this.index,
    required this.model,
    this.showDragHandle = true,
  });

  final int folderId;
  final String fileName;
  final int index;
  final FoldersModel model;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final stripeColor = _kStripeColors[index % _kStripeColors.length];
    final bool isEditing = model.editingIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(folderId),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            model.removeFolder((folderId, fileName));
            return true;
          } else {
            var folderPaths = await model.getFilePathsFromFolder(folderId);
            List<XFile> folderFiles = [];
            for (var path in folderPaths) {
              folderFiles.add(XFile(path));
            }
            try {
              await SharePlus.instance.share(ShareParams(
                files: folderFiles,
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
          child: const Row(
            children: [
              Icon(Icons.share_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Share',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Delete',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
        // ── Tappable card (restored from working version) ──
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => FavoritesModel(folderIndex: folderId),
                    child: FavoritesHomePage(folderIndex: folderId),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 90), 
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Colored left stripe ──────────────────────────────
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: stripeColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                          ),
                        ),
                      ),
                
                      // ── Folder icon ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: stripeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.folder_rounded,
                              color: stripeColor, size: 20),
                        ),
                      ),
                
                      // ── Name section ─────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _NameSection(
                            fileName: fileName,
                            folderId: folderId,
                            index: index,
                            model: model,
                            isEditing: isEditing,
                          ),
                        ),
                      ),
                
                      // ── Drag handle ──────────────────────────────────────
                      if (showDragHandle)
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: _kBrownLight.withValues(alpha: 0.7),
                              size: 20,
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
      ),
    );
  }
}

// ── Name / rename section ─────────────────────────────────────────────────────

class _NameSection extends StatelessWidget {
  const _NameSection({
    required this.fileName,
    required this.folderId,
    required this.index,
    required this.model,
    required this.isEditing,
  });

  final String fileName;
  final int folderId;
  final int index;
  final FoldersModel model;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return TextField(
        controller: TextEditingController(text: fileName),
        autofocus: true,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: _kBrown,
          letterSpacing: -0.2,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
          filled: false,
        ),
        onSubmitted: (newName) {
          if (newName.isNotEmpty) {
            model.renameFolder((folderId, fileName), newName);
          }
          model.setEditingIndex(-1);
        },
        onTapOutside: (_) => model.setEditingIndex(-1),
      );
    }

    return GestureDetector(
      onLongPress: () => model.setEditingIndex(index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fileName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: _kBrown,
              letterSpacing: -0.2,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          const Text(
            'Hold to rename',
            style: TextStyle(
              fontSize: 12,
              color: _kBrownLight,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
