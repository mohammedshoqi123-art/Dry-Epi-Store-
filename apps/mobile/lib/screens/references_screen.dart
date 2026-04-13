import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// References & Resources page — downloadable books, guides, and manuals.
class ReferencesScreen extends ConsumerStatefulWidget {
  const ReferencesScreen({super.key});

  @override
  ConsumerState<ReferencesScreen> createState() => _ReferencesScreenState();
}

class _ReferencesScreenState extends ConsumerState<ReferencesScreen> {
  List<Map<String, dynamic>> _references = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final data = await db.getReferences();
      if (mounted) {
        setState(() {
          _references = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _references;
    return _references.where((r) {
      final title = (r['title_ar'] ?? '').toString().toLowerCase();
      final desc = (r['description_ar'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المراجع والكتب', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: EpiSearchBar(
              hint: 'ابحث في المراجع...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const EpiLoading()
                : _filtered.isEmpty
                    ? const EpiEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'لا توجد مراجع متاحة حالياً',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReferences,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final ref = _filtered[index];
                            return _ReferenceCard(
                              title: ref['title_ar'] ?? '',
                              description: ref['description_ar'] ?? '',
                              category: ref['category'] ?? '',
                              fileUrl: ref['file_url'],
                              icon: _getCategoryIcon(ref['category']),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'guide':
        return Icons.description_rounded;
      case 'manual':
        return Icons.menu_book_rounded;
      case 'form':
        return Icons.assignment_rounded;
      case 'training':
        return Icons.school_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}

class _ReferenceCard extends StatelessWidget {
  final String title;
  final String description;
  final String category;
  final String? fileUrl;
  final IconData icon;

  const _ReferenceCard({
    required this.title,
    required this.description,
    required this.category,
    this.fileUrl,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return EpiCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: fileUrl != null ? () => _openFile(fileUrl!) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _categoryLabel(category),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (fileUrl != null)
                const Icon(Icons.download_rounded, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'guide':
        return 'دليل';
      case 'manual':
        return 'كتيب';
      case 'form':
        return 'استمارة';
      case 'training':
        return 'تدريب';
      default:
        return 'عام';
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
