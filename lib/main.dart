import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple, 
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const ExpressiveHomePage(),
    );
  }
}

class ExpressiveHomePage extends StatelessWidget {
  const ExpressiveHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold is marked as const here because all dynamic widgets inside are commented out
    return const Scaffold(
      /*
      appBar: AppBar(
        title: const Text('Material 3 Expressive'),
        centerTitle: true,
        scrolledUnderElevation: 4.0, 
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Dynamic Typography',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Notice how this card doesn\'t use shadows? Material 3 Expressive relies on tonal variations (surfaceContainerHighest) rather than heavy drop shadows.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: () {},
                child: const Text('Filled Button'),
              ),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('Tonal Button'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
      */
    );
  }
}
