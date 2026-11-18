import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_work_flow_demo2/features/workshops/data/workshops.dart';

void main() {
  test('HTTP list query, typed decoding and missing detail', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = Dio(
      BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}/api/v1/'),
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
    final requests = <Uri>[];
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/missing')) {
        request.response.statusCode = 404;
        request.response.write(
          jsonEncode({'code': 'NOT_FOUND', 'message': '记录不存在'}),
        );
      } else {
        request.response.write(
          jsonEncode({
            'items': [
              {
                'id': 'w01',
                'title': '纸上造景',
                'startsAt': '2026-11-21T14:00:00+08:00',
                'endsAt': '2026-11-21T16:00:00+08:00',
                'venue': '河畔工作室',
                'description': '介绍',
                'remaining': 3,
                'myReservationId': null,
              },
            ],
            'nextPage': 2,
          }),
        );
      }
      await request.response.close();
    });
    final repo = HttpWorkshopRepository(WorkshopService(client));
    final result = await repo.listWorkshops(1);
    expect(result.items.single.id, 'w01');
    expect(result.nextPage, 2);
    expect(requests.single.path, '/api/v1/workshops');
    expect(requests.single.queryParameters, {'page': '1', 'pageSize': '3'});
    await expectLater(
      repo.getWorkshop('missing'),
      throwsA(isA<WorkshopFailure>().having((e) => e.notFound, '404', true)),
    );
  });

  test('malformed contract fields fail decoding', () {
    expect(
      () => Workshop.fromJson({'remaining': -1, 'myReservationId': null}),
      throwsFormatException,
    );
    expect(() => Workshop.fromJson({'remaining': 3}), throwsFormatException);
  });
  for (final status in [201, 400, 404, 409]) {
    test('createReservation HTTP $status request and mapping', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final dio = Dio(
        BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}/api/v1/'),
      );
      addTearDown(() async {
        dio.close(force: true);
        await server.close(force: true);
      });
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/reservations');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'workshopId': 'w01',
        });
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = status;
        request.response.write(
          jsonEncode(
            status == 201
                ? {
                    'id': 1,
                    'workshop': {
                      'id': 'w01',
                      'title': '纸上造景',
                      'startsAt': '2026-11-21T14:00:00+08:00',
                      'endsAt': '2026-11-21T16:00:00+08:00',
                      'venue': '工作室',
                      'description': '介绍',
                      'remaining': 2,
                      'myReservationId': 1,
                    },
                  }
                : {
                    'code': status == 409
                        ? 'FULL'
                        : status == 400
                        ? 'BAD_REQUEST'
                        : 'NOT_FOUND',
                    'message': '错误',
                  },
          ),
        );
        await request.response.close();
      });
      final repo = HttpWorkshopRepository(WorkshopService(dio));
      if (status == 201) {
        final result = await repo.createReservation('w01');
        expect(result.workshop.remaining, 2);
        expect(result.id, 1);
      } else {
        await expectLater(
          repo.createReservation('w01'),
          throwsA(
            isA<WorkshopFailure>().having(
              (e) => e.statusCode,
              'status',
              status,
            ),
          ),
        );
      }
    });
  }
}
