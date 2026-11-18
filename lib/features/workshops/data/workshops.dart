import 'package:dio/dio.dart';

class Workshop {
  const Workshop({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.venue,
    required this.description,
    required this.remaining,
    required this.myReservationId,
  });
  final String id, title, venue, description;
  final DateTime startsAt, endsAt;
  final int remaining;

  /// 固定体验者的有效预约 ID，null 表示未预约。
  final int? myReservationId;

  factory Workshop.fromJson(Map<String, dynamic> json) {
    final remaining = json['remaining'] as int;
    final reservation = json['myReservationId'] as int?;
    if (!json.containsKey('myReservationId') ||
        remaining < 0 ||
        (reservation != null && reservation < 1)) {
      throw const FormatException('Invalid workshop');
    }
    return Workshop(
      id: json['id'] as String,
      title: json['title'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      venue: json['venue'] as String,
      description: json['description'] as String,
      remaining: remaining,
      myReservationId: reservation,
    );
  }
}

class WorkshopPage {
  WorkshopPage(List<Workshop> items, this.nextPage)
    : items = List.unmodifiable(items);
  final List<Workshop> items;
  final int? nextPage;
}

class WorkshopFailure implements Exception {
  const WorkshopFailure({this.notFound = false});
  final bool notFound;
}

abstract interface class WorkshopRepository {
  Future<WorkshopPage> listWorkshops(int page, {CancelToken? cancelToken});
  Future<Workshop> getWorkshop(String id, {CancelToken? cancelToken});
}

class WorkshopService {
  WorkshopService(this.client);
  final Dio client;
  Future<Map<String, dynamic>> read(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final response = await client.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
    );
    if (response.statusCode != 200 || response.data == null) {
      throw const WorkshopFailure();
    }
    return response.data!;
  }
}

class HttpWorkshopRepository implements WorkshopRepository {
  HttpWorkshopRepository(this.service);
  final WorkshopService service;
  @override
  Future<WorkshopPage> listWorkshops(
    int page, {
    CancelToken? cancelToken,
  }) async {
    try {
      final json = await service.read(
        'workshops',
        query: {'page': page, 'pageSize': 3},
        cancelToken: cancelToken,
      );
      if (!json.containsKey('nextPage')) {
        throw const FormatException('Missing nextPage');
      }
      final next = json['nextPage'] as int?;
      if (next != null && next <= page) {
        throw const FormatException('Invalid nextPage');
      }
      return WorkshopPage(
        (json['items'] as List)
            .map((item) => Workshop.fromJson(item as Map<String, dynamic>))
            .toList(),
        next,
      );
    } catch (_) {
      throw const WorkshopFailure();
    }
  }

  @override
  Future<Workshop> getWorkshop(String id, {CancelToken? cancelToken}) async {
    try {
      return Workshop.fromJson(
        await service.read(
          'workshops/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        ),
      );
    } on DioException catch (error) {
      throw WorkshopFailure(notFound: error.response?.statusCode == 404);
    } catch (_) {
      throw const WorkshopFailure();
    }
  }
}
