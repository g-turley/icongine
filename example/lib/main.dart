import 'package:flutter/material.dart';

import 'generated/example_icons.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'icongine example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const IconCatalogPage(),
    );
  }
}

class IconCatalogPage extends StatefulWidget {
  const IconCatalogPage({super.key});

  @override
  State<IconCatalogPage> createState() => _IconCatalogPageState();
}

class _IconCatalogPageState extends State<IconCatalogPage> {
  late final List<MapEntry<String, IconData>> _allIcons =
      ExampleIcons.all.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleIcons = _allIcons
        .where((entry) => entry.key.toLowerCase().contains(_query))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('icongine catalog')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search ${_allIcons.length} icons',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: _updateQuery,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '${visibleIcons.length} ${visibleIcons.length == 1 ? 'icon' : 'icons'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: visibleIcons.isEmpty
                  ? _EmptySearch(query: _searchController.text)
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 176,
                            mainAxisExtent: 112,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: visibleIcons.length,
                      itemBuilder: (context, index) {
                        return _IconTile(entry: visibleIcons[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateQuery('');
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.entry});

  final MapEntry<String, IconData> entry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${entry.key} icon',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.value, size: 28),
              const SizedBox(height: 8),
              Text(
                entry.key,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No icons match “$query”.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
