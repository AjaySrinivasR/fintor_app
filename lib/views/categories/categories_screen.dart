// lib/views/categories/categories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories & Auto-Rules',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: provider.categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final cat = provider.categories[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: cat.color.withOpacity(0.12),
                child: Icon(cat.icon, color: cat.color, size: 20),
              ),
              title: Text(cat.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('${cat.keywords.length} auto-match keywords',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('SMS & Statement Match Keywords:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...cat.keywords.map((kw) => Chip(
                          label: Text(kw, style: const TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        )),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('Add Rule',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => _showAddKeywordDialog(context, cat),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddCategoryDialog(context),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Category',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  void _showAddKeywordDialog(BuildContext context, CategoryItem category) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Keyword Rule to ${category.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. "bigbasket" or "d-mart"',
            labelText: 'Keyword',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final kw = controller.text.trim();
              if (kw.isNotEmpty) {
                context
                    .read<CategoryProvider>()
                    .addKeywordToCategory(category.id, kw);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Rule'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final kwController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kwController,
              decoration: const InputDecoration(
                labelText: 'Comma-separated Keywords',
                hintText: 'e.g. medicine, pharmacy, apollo',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final keywords = kwController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (name.isNotEmpty) {
                context.read<CategoryProvider>().addCategory(
                      name,
                      Icons.folder_outlined,
                      Colors.indigo,
                      keywords,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
