import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/workshops/data/workshops.dart';
import 'features/workshops/presentation/pages.dart';

void main() => runApp(const WorkshopApp());

class WorkshopApp extends StatefulWidget {
  const WorkshopApp({
    super.key,
    this.repository,
    this.initialLocation = '/discover',
  });
  final WorkshopRepository? repository;
  final String initialLocation;
  @override
  State<WorkshopApp> createState() => _WorkshopAppState();
}

class _WorkshopAppState extends State<WorkshopApp> {
  late final Dio _client;
  late final WorkshopRepository _repository;
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    const address = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8765/api/v1',
    );
    _client = Dio(
      BaseOptions(
        baseUrl: '${address.replaceAll(RegExp(r'/+$'), '')}/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    _repository =
        widget.repository ?? HttpWorkshopRepository(WorkshopService(_client));
    _router = GoRouter(
      initialLocation: widget.initialLocation,
      routes: [
        GoRoute(path: '/discover', builder: (_, _) => const DiscoverPage()),
        GoRoute(
          path: '/workshops/:workshopId',
          name: 'workshop',
          builder: (_, state) =>
              WorkshopDetailPage(id: state.pathParameters['workshopId']!),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _client.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(_repository)],
    child: MaterialApp.router(
      title: '周末工坊',
      routerConfig: _router,
      theme: ThemeData(
        fontFamily: 'WorkshopSerif',
        scaffoldBackgroundColor: const Color(0xFFF7F5F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          surface: const Color(0xFFF7F5F2),
          primary: accent,
          onSurface: const Color(0xFF1C1B19),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF9C958E),
          thickness: 0.6,
        ),
      ),
    ),
  );
}
