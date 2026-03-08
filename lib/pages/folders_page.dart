// ignore_for_file: no_leading_underscores_for_local_identifiers, unused_element
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folders_model.dart';
import '../models/favorites_model.dart';
import 'favorites_home_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kBrown = Color(0xFF41342F);
const _kAccent = Color(0xFFD4A574);
const _kSurface = Color(0xFFFAF7F4);
const _kBorder = Color(0xFFEDE8E3);

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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _kBrown.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded,
                  size: 40, color: _kBrown),
            ),
            const SizedBox(height: 20),
            const Text(
              'No folders yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kBrown,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create your first folder',
              style: TextStyle(
                fontSize: 14,
                color: _kBrown.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }

    if (searchQuery.isNotEmpty && filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _kBrown.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded,
                  size: 40, color: _kBrown),
            ),
            const SizedBox(height: 20),
            const Text(
              'No matching results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kBrown,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      );
    }

    if (searchQuery.isNotEmpty){

      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final (folderId, fileName) = filtered[index];
          return _FolderCard(
            key: ValueKey('$fileName$index'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: model.folders.length,
      onReorder: model.reorderFolders,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final elevation = Tween<double>(begin: 0, end: 12).evaluate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          return Material(
            color: Colors.transparent,
            elevation: elevation,
            borderRadius: BorderRadius.circular(16),
            shadowColor: _kBrown.withValues(alpha: 0.25),
            child: child,
          );
        },
      ),
      itemBuilder: (context, index) {
        final (folderId, fileName) = model.folders[index];
        return _FolderCard(
          key: ValueKey('$folderId$fileName$index'),
          folderId: folderId,
          fileName: fileName!,
          index: index,
          model: model,
        );
      },
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

  // Cycle through warm accent tones for the left stripe
  static const _stripeColors = [
    Color(0xFFD4A574),
    Color(0xFF8B6F5E),
    Color(0xFFC4956A),
    Color(0xFF7A9E7E),
    Color(0xFF9B8BB4),
    Color(0xFF6B9BBD),
  ];

  @override
  Widget build(BuildContext context) {
    final stripeColor = _stripeColors[index % _stripeColors.length];
    final bool isEditing = model.editingIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => FavoritesModel(folderIndex: folderId),
                  child: FavoritesHomePage(folderIndex : folderId),
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Colored left stripe ────────────────────────────
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: stripeColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),

                  // ── Folder icon ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: stripeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.folder_rounded,
                          color: stripeColor, size: 22),
                    ),
                  ),

                  // ── Name section ───────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _NameSection(
                        fileName: fileName,
                        folderId: folderId,
                        index: index,
                        model: model,
                        isEditing: isEditing,
                      ),
                    ),
                  ),

                  // ── Actions ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionIcon(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.red.shade300,
                          tooltip: 'Delete',
                          onTap: () =>
                              model.removeFolder((folderId, fileName)),
                        ),
                        if (showDragHandle)
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
        ),
      ),
    );
  }
}

// ── Name / rename section ────────────────────────────────────────────────────

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
              fontSize: 15,
              color: _kBrown,
              letterSpacing: -0.2,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 3),
        ],
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