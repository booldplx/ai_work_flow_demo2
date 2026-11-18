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
  const WorkshopFailure({bool notFound = false, this.statusCode, this.code})
    : _notFound = notFound;
  final bool _notFound;
  final int? statusCode;
  final String? code;
  bool get notFound => _notFound || statusCode == 404;
}

abstract interface class WorkshopRepository {
  Future<Reservation> createReservation(String id);
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
  }) => _request(path, query: query, cancelToken: cancelToken);

  Future<Map<String, dynamic>> create(String id) =>
      _request('reservations', body: {'workshopId': id});

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await client.request<Map<String, dynamic>>(
        path,
        queryParameters: query,
        data: body,
        cancelToken: cancelToken,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode != (body == null ? 200 : 201) ||
          response.data == null) {
        throw const WorkshopFailure();
      }
      return response.data!;
    } on DioException catch (error) {
      final data = error.response?.data;
      throw WorkshopFailure(
        statusCode: error.response?.statusCode,
        code: data is Map && data['code'] is String
            ? data['code'] as String
            : null,
      );
    }
  }
}

class HttpWorkshopRepository implements WorkshopRepository {
  HttpWorkshopRepository(this.service);
  final WorkshopService service;
  @override
  Future<Reservation> createReservation(String id) async {
    try {
      final json = await service.create(id);
      final reservation = Reservation(
        json['id'] as int,
        Workshop.fromJson(json['workshop'] as Map<String, dynamic>),
      );
      if (reservation.id < 1 ||
          reservation.workshop.id != id ||
          reservation.workshop.myReservationId != reservation.id) {
        throw const FormatException('Invalid reservation');
      }
      return reservation;
    } on WorkshopFailure {
      rethrow;
    } catch (_) {
      throw const WorkshopFailure();
    }
  }

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
    } on WorkshopFailure {
      rethrow;
    } catch (_) {
      throw const WorkshopFailure();
    }
  }
}

class Reservation {
  const Reservation(this.id, this.workshop);
  final int id;
  final Workshop workshop;
}
