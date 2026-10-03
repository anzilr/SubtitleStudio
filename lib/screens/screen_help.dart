import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:subtitle_studio/utils/app_info.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/screens/help/help_catalog.dart';
import 'package:subtitle_studio/screens/help/help_models.dart';

class HelpScreen extends StatefulWidget {
  final String? initialCategoryId;
  
  const HelpScreen({super.key, this.initialCategoryId});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  String _searchQuery = '';
  int _selectedCategoryIndex = -1; // -1 means show all
  
  List<HelpCategory> get _categories =>
      buildHelpCategories(defaultTargetPlatform);

  List<HelpCategory> get _filteredCategories {
    if (_searchQuery.isEmpty && _selectedCategoryIndex == -1) {
      return _categories;
    }
    
    if (_selectedCategoryIndex != -1) {
      return [_categories[_selectedCategoryIndex]];
    }
    
    return _categories.where((category) {
      final categoryMatch = category.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final sectionMatch = category.sections.any((section) =>
          section.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          section.content.toLowerCase().contains(_searchQuery.toLowerCase()));
      return categoryMatch || sectionMatch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    
    // If initialCategoryId is provided, select that category
    if (widget.initialCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final categoryIndex = _categories.indexWhere(
          (category) => category.id == widget.initialCategoryId,
        );
        if (categoryIndex != -1) {
          setState(() {
            _selectedCategoryIndex = categoryIndex;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _scrollToCategory(String categoryId) {
    setState(() {
      _selectedCategoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
    });
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      bool launched = false;
      
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        // Try with platform default mode if external application fails
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      
      if (!launched) {
        // Show error message if URL couldn't be opened
        if (mounted) {
          SnackbarHelper.showError(context, 'Could not open website. Please check your internet connection.');
        }
      }
    } catch (e) {
      // Show error message for invalid URL
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open website. Invalid URL.');
      }
    }
  }

  Widget _buildStepText(String step, BuildContext context) {
    // Check if this step contains "MSone website"
    if (step.contains('MSone website')) {
      // Split the text and create clickable link
      final parts = step.split('MSone website');
      return RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: parts[0]),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _launchUrl('https://malayalamsubtitles.org/'),
                child: Text(
                  'MSone website',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
            if (parts.length > 1) TextSpan(text: parts[1]),
          ],
        ),
      );
    }
    
    // Return normal text for other steps
    return Text(
      step,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Documentation', style: Theme.of(context).textTheme.titleLarge),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          IconButton(
            onPressed: () => _showQuickNavigation(),
            icon: Icon(Icons.menu_book_outlined, color: Theme.of(context).colorScheme.onSurface,),
            tooltip: 'Quick Navigation',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchSection(),
            _buildCategoryFilter(),
            Expanded(
              child: _buildHelpContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How can we help you?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for features, guides, or solutions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _selectedCategoryIndex = -1; // Reset category filter when searching
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final scrollController = ScrollController();
    
    return SizedBox(
      height: 60,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Convert vertical scroll to horizontal scroll
            final offset = event.scrollDelta.dy;
            scrollController.position.moveTo(
              scrollController.offset + offset,
              curve: Curves.linear,
            );
          }
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
            scrollbars: false,
          ),
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length + 1, // +1 for "All" option
            itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(
              'All',
              Icons.apps,
              Theme.of(context).primaryColor,
              _selectedCategoryIndex == -1,
              () {
                setState(() {
                  _selectedCategoryIndex = -1;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            );
          }
          
          final category = _categories[index - 1];
          final isSelected = _selectedCategoryIndex == index - 1;
          
          return _buildCategoryChip(
            category.title,
            category.icon,
            category.color,
            isSelected,
            () {
              setState(() {
                _selectedCategoryIndex = index - 1;
                _searchController.clear();
                _searchQuery = '';
              });
            },
          );
        },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpContent() {
    final filteredCategories = _filteredCategories;
    
    if (filteredCategories.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, categoryIndex) {
        final category = filteredCategories[categoryIndex];
        return _buildCategoryCard(category, categoryIndex);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(HelpCategory category, int categoryIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: _selectedCategoryIndex == categoryIndex || _searchQuery.isNotEmpty,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            category.icon,
            color: category.color,
            size: 24,
          ),
        ),
        title: Text(
          category.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: category.sections.map((section) => _buildSectionCard(section, category.color)).toList(),
      ),
    );
  }

  Widget _buildSectionCard(HelpSection section, Color categoryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          section.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: categoryColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (section.content.isNotEmpty) ...[
                  Text(
                    section.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (section.steps.isNotEmpty) ...[
                  Text(
                    'Step-by-step guide:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...section.steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStepText(step, context),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickNavigation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Navigation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      leading: Icon(
                        category.icon,
                        color: category.color,
                      ),
                      title: Text(category.title),
                      subtitle: Text('${category.sections.length} sections'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToCategory(category.id);
                      },
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subtitle Studio v${AppInfo.version}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Professional Subtitle Editing Tool',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
