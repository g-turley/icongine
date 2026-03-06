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
      theme: ThemeData(colorSchemeSeed: Colors.teal),
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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allIcons = ExampleIcons.all.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final visibleIcons = allIcons
        .where((entry) => entry.key.toLowerCase().contains(_query))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text('icongine catalog (${visibleIcons.length})')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
              decoration: const InputDecoration(
                hintText: 'Filter icons by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.3,
              ),
              itemCount: visibleIcons.length,
              itemBuilder: (context, index) {
                final entry = visibleIcons[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(entry.value, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          entry.key,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
