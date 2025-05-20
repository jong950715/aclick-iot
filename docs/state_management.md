# Riverpod State Management Architecture

This document outlines the state management architecture used in the IoT and Phone applications. Both applications use Flutter Riverpod for predictable, testable state management.

## Table of Contents
1. [Overview](#overview)
2. [Architecture Layers](#architecture-layers)
3. [Provider Organization](#provider-organization)
4. [State Management Patterns](#state-management-patterns)
5. [Best Practices](#best-practices)
6. [Common Usage Patterns](#common-usage-patterns)

## Overview

Our state management architecture follows a clear separation of concerns with distinct layers:

- **States**: Immutable data classes that represent application state
- **StateNotifiers**: Classes that manage state changes
- **Providers**: Dependency injection and state access points
- **Controllers**: Business logic that coordinates state changes

This architecture enables:
- Predictable state updates
- Easy testing with dependency injection
- Clear, unidirectional data flow
- Optimal rebuilds with fine-grained reactivity

## Architecture Layers

### States

States are immutable data classes that represent a snapshot of the application. Key features:

- **Immutability**: All state classes are immutable
- **copyWith()**: All states provide a `copyWith()` method for creating modified copies
- **Default values**: Constructors provide sensible defaults
- **Clear Responsibility**: Each state class has a single, well-defined responsibility

Example state class:
```dart
class SensorState {
  final bool isConnected;
  final List<String> activeSensors;
  final Map<String, double> readings;
  final DateTime lastUpdated;

  const SensorState({
    this.isConnected = false,
    this.activeSensors = const [],
    this.readings = const {},
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  SensorState copyWith({...}) {...}
}
```

### StateNotifiers

StateNotifiers are responsible for modifying state based on events or actions. Key features:

- **Single Responsibility**: Each notifier manages one state class
- **Atomic Updates**: State changes are applied atomically
- **Validation**: Business rules are enforced during state changes
- **Encapsulation**: State can only be modified through the notifier

Example state notifier:
```dart
class SensorStateNotifier extends StateNotifier<SensorState> {
  SensorStateNotifier() : super(const SensorState());

  void setConnectionStatus(bool isConnected) {
    state = state.copyWith(
      isConnected: isConnected,
      lastUpdated: DateTime.now(),
    );
  }
  
  // Other update methods...
}
```

### Providers

Providers act as the access points for state and dependencies. Key features:

- **Dependency Injection**: Providers create and provide dependencies
- **Discoverability**: Providers are organized in feature modules
- **Composition**: Providers can depend on other providers
- **Reactivity**: UI rebuilds automatically when watched provider state changes

Example providers:
```dart
// State provider
final sensorStateProvider = StateNotifierProvider<SensorStateNotifier, SensorState>((ref) {
  return SensorStateNotifier();
});

// Derived provider
final activeSensorsProvider = Provider<List<String>>((ref) {
  return ref.watch(sensorStateProvider).activeSensors;
});
```

### Controllers

Controllers implement business logic and coordinate state changes. Key features:

- **Use Cases**: Controllers encapsulate use cases and operations
- **Dependency Injection**: Controllers receive dependencies through constructor
- **State Access**: Controllers read state and trigger state updates
- **Side Effects**: External operations (API calls, etc.) are handled here

Example controller:
```dart
class SensorController {
  final Ref _ref;
  Timer? _refreshTimer;

  SensorController(this._ref);

  Future<void> startSensors() async {
    // Business logic...
    final stateNotifier = _ref.read(sensorStateProvider.notifier);
    stateNotifier.setConnectionStatus(true);
    // ...
  }
  
  // Other methods...
}
```

## Provider Organization

Providers are organized by feature and type:

```
lib/
  src/
    providers/
      sensor_providers.dart     // Feature-specific providers
      settings_providers.dart
      connection_providers.dart
      providers.dart            // Export file for easy imports
    states/                     // State classes
    controllers/                // Controller classes
    models/                     // Domain model classes
```

Benefits of this organization:
- **Discoverability**: Easy to find providers for a specific feature
- **Cohesion**: Related providers are grouped together
- **Scalability**: Structure scales well as the application grows
- **Import Management**: Export files simplify imports

## State Management Patterns

### 1. Container-Presenter Pattern

This pattern separates UI from state management:

- **Container Components**: Connect to providers and pass data to presenters
- **Presenter Components**: Pure UI without state management dependencies

Example:
```dart
// Container
class SensorPageContainer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensors = ref.watch(activeSensorsProvider);
    final readings = ref.watch(allSensorReadingsProvider);
    
    return SensorPagePresenter(
      sensors: sensors,
      readings: readings,
      onRefresh: () => ref.read(sensorControllerProvider).refreshSensorData(),
    );
  }
}

// Presenter
class SensorPagePresenter extends StatelessWidget {
  final List<String> sensors;
  final Map<String, double> readings;
  final VoidCallback onRefresh;
  
  // UI implementation...
}
```

### 2. Feature-Specific Provider Pattern

Each feature has a dedicated group of providers, including:
- State provider
- Controller provider
- Derived data providers

Example for sensor feature:
```dart
// Base state provider
final sensorStateProvider = StateNotifierProvider<SensorStateNotifier, SensorState>((ref) {
  return SensorStateNotifier();
});

// Controller provider
final sensorControllerProvider = Provider<SensorController>((ref) {
  return SensorController(ref);
});

// Derived providers
final activeSensorsProvider = Provider<List<String>>((ref) {
  return ref.watch(sensorStateProvider).activeSensors;
});

final sensorReadingProvider = Provider.family<double, String>((ref, sensorId) {
  final sensorState = ref.watch(sensorStateProvider);
  return sensorState.readings[sensorId] ?? 0.0;
});
```

### 3. Family Providers for Parameterized Data

Use `Provider.family` to create providers that accept parameters:

```dart
final sensorReadingProvider = Provider.family<double, String>((ref, sensorId) {
  final sensorState = ref.watch(sensorStateProvider);
  return sensorState.readings[sensorId] ?? 0.0;
});

// Usage:
final temperature = ref.watch(sensorReadingProvider('temperature'));
```

### 4. Error Handling Strategy

All error states are part of the state classes:

```dart
class ConnectionState {
  final bool isConnected;
  final String? errorMessage;
  // ...
}

// Controller handles errors and updates state
Future<void> connect() async {
  try {
    // Connection logic...
  } catch (e) {
    ref.read(connectionStateProvider.notifier).setError(e.toString());
  }
}
```

## Best Practices

### 1. Single Source of Truth

Each piece of state should exist in exactly one place. Derived state should be created using providers.

```dart
// GOOD
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionStateProvider).isConnected;
});

// BAD
// Don't duplicate state across multiple state objects
```

### 2. Keep States Immutable

Never modify state objects directly. Always use the `copyWith()` method to create new state instances.

```dart
// GOOD
void updateSensorReading(String sensorId, double value) {
  final updatedReadings = Map<String, double>.from(state.readings);
  updatedReadings[sensorId] = value;
  
  state = state.copyWith(
    readings: updatedReadings,
    lastUpdated: DateTime.now(),
  );
}

// BAD
// state.readings[sensorId] = value; // Never modify state directly
```

### 3. Granular Providers

Create fine-grained providers to minimize unnecessary rebuilds.

```dart
// GOOD
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(settingsStateProvider).isDarkMode;
});

// Instead of watching the entire settings state in UI components
```

### 4. Watch vs. Read

- Use `ref.watch()` in `build()` methods to react to state changes
- Use `ref.read()` in event handlers to access current state without creating dependencies

```dart
// GOOD
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Will rebuild when darkMode changes
  final isDarkMode = ref.watch(darkModeProvider);
  
  return Switch(
    value: isDarkMode,
    onChanged: (_) {
      // Won't create a dependency on settingsControllerProvider
      ref.read(settingsControllerProvider).toggleDarkMode();
    },
  );
}
```

### 5. Side Effect Management

Handle side effects (like network calls) in controllers, not in StateNotifiers.

```dart
// GOOD
// In controller
Future<void> refreshSensorData() async {
  final result = await _apiService.getSensorData();
  _ref.read(sensorStateProvider.notifier).updateSensorReadings(result);
}

// BAD
// Don't put API calls in StateNotifiers
```

## Common Usage Patterns

### 1. Consuming Providers in UI

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    
    return Text(isConnected ? 'Connected' : 'Disconnected');
  }
}
```

### 2. Stateful Consumer Widget

```dart
class MyStatefulPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyStatefulPage> createState() => _MyStatefulPageState();
}

class _MyStatefulPageState extends ConsumerState<MyStatefulPage> {
  @override
  void initState() {
    super.initState();
    
    // Use Future.microtask to avoid calling read during build
    Future.microtask(() {
      ref.read(settingsControllerProvider).loadSettings();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // UI implementation...
  }
}
```

### 3. Handling Loading/Error States

```dart
// Combined loading/error/data state pattern
class AsyncValue<T> {
  final T? data;
  final bool isLoading;
  final String? errorMessage;
  
  // ...
}

// Usage in UI
final dataState = ref.watch(asyncDataProvider);

if (dataState.isLoading) {
  return CircularProgressIndicator();
} else if (dataState.errorMessage != null) {
  return Text('Error: ${dataState.errorMessage}');
} else {
  return DataWidget(data: dataState.data!);
}
```

### 4. Controller Method Invocation

```dart
ElevatedButton(
  onPressed: () {
    // Invoke controller method
    ref.read(sensorControllerProvider).refreshSensorData();
  },
  child: Text('Refresh'),
)
```

---

By following these patterns and best practices, we maintain a clean, maintainable, and testable state management architecture across both IoT and Phone applications.
