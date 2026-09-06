import 'dart:io';

import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFile extends Mock implements File {}

void main() {
  group('FileInfo', () {
    late MockFile file;

    setUp(() {
      file = MockFile();
    });

    test('reads size and valid last modified time', () async {
      final lastModified = DateTime(2026, 7, 29);
      when(() => file.exists()).thenAnswer((_) async => true);
      when(() => file.length()).thenAnswer((_) async => 2048);
      when(() => file.lastModified()).thenAnswer((_) async => lastModified);

      final fileInfo = await file.getFileInfo();

      expect(fileInfo, FileInfo(size: 2048, lastModified: lastModified));
    });

    test(
      'treats positive timestamps within the epoch year as unknown',
      () async {
        when(() => file.exists()).thenAnswer((_) async => true);
        when(() => file.length()).thenAnswer((_) async => 1024);
        when(
          () => file.lastModified(),
        ).thenAnswer((_) async => DateTime(1970, 12, 31, 23, 59, 59));

        final fileInfo = await file.getFileInfo();

        expect(fileInfo, const FileInfo(size: 1024));
      },
    );

    test('keeps size when last modified time cannot be read', () async {
      when(() => file.exists()).thenAnswer((_) async => true);
      when(() => file.length()).thenAnswer((_) async => 1024);
      when(
        () => file.lastModified(),
      ).thenThrow(const FileSystemException('last modified unavailable'));

      final fileInfo = await file.getFileInfo();

      expect(fileInfo, const FileInfo(size: 1024));
    });

    test('returns null when file does not exist', () async {
      when(() => file.exists()).thenAnswer((_) async => false);

      expect(await file.getFileInfo(), isNull);
      verifyNever(() => file.length());
      verifyNever(() => file.lastModified());
    });

    testWidgets('shows unknown while preserving file size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Builder(
            builder: (context) {
              return Text(const FileInfo(size: 1024).getDesc(context));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.00 KB  ·  Unknown'), findsOneWidget);
    });

    testWidgets('shows relative time for valid last modified time', (
      tester,
    ) async {
      final lastModified = DateTime.now().subtract(const Duration(days: 2));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Builder(
            builder: (context) {
              return Text(
                FileInfo(
                  size: 1024,
                  lastModified: lastModified,
                ).getDesc(context),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.00 KB  ·  2 days ago'), findsOneWidget);
    });
  });

  group('PackagesExt', () {
    const packages = [
      Package(
        packageName: 'system.app',
        label: 'System',
        system: true,
        internet: true,
        lastUpdateTime: 1,
      ),
      Package(
        packageName: 'user.old',
        label: 'Alpha',
        system: false,
        internet: false,
        lastUpdateTime: 2,
      ),
      Package(
        packageName: 'user.new',
        label: 'Beta',
        system: false,
        internet: true,
        lastUpdateTime: 3,
      ),
    ];

    test('filters system and non-internet apps', () {
      final result = packages.getViewList(
        pinedList: [],
        sortType: AccessSortType.none,
        isFilterSystemApp: true,
        isFilterNonInternetApp: true,
      );

      expect(result.map((item) => item.packageName), ['user.new']);
    });

    test('pins selected packages before sorted packages', () {
      final result = packages.getViewList(
        pinedList: ['user.old'],
        sortType: AccessSortType.name,
        isFilterSystemApp: false,
        isFilterNonInternetApp: false,
      );

      expect(result.map((item) => item.packageName), [
        'user.old',
        'user.new',
        'system.app',
      ]);
    });
  });

  group('TrackerInfoExt', () {
    test('builds destination description and process text', () {
      final trackerInfo = TrackerInfo(
        id: '1',
        start: DateTime(2026),
        metadata: const Metadata(
          network: 'tcp',
          host: 'example.com',
          destinationIP: '1.1.1.1',
          destinationPort: '443',
          process: 'Browser',
          uid: 501,
        ),
        chains: const ['Proxy'],
        rule: 'MATCH',
        rulePayload: '',
      );

      expect(trackerInfo.desc, 'tcp://example.com/1.1.1.1:443');
      expect(trackerInfo.progressText, 'Browser(501)');
    });
  });

  group('TrafficExt', () {
    test('formats speed, description, tray title, and total speed', () {
      const traffic = Traffic(up: 1024, down: 2048);

      expect(traffic.speedText, '↑ 1.00 KB/s   ↓ 2.00 KB/s');
      expect(traffic.desc, '1.00 KB ↑ 2.00 KB ↓');
      expect(traffic.trayTitle, '1 KB/s\n2 KB/s');
      expect(traffic.speed, 3072);
    });
  });

  group('GroupsExt', () {
    test('finds group by name and resolves current selection', () {
      const groups = [
        Group(name: 'Auto', type: GroupType.URLTest, now: 'Proxy A'),
        Group(name: 'Manual', type: GroupType.Selector, now: 'Proxy B'),
      ];

      expect(
        groups.getGroup('Auto')?.getCurrentSelectedName('Proxy C'),
        'Proxy A',
      );
      expect(
        groups.getGroup('Manual')?.getCurrentSelectedName('Proxy C'),
        'Proxy C',
      );
      expect(groups.getGroup('Missing'), isNull);
    });
  });

  group('IpInfo parsers', () {
    test('parse supported response shapes', () {
      expect(
        IpInfo.fromIpInfoIoJson({'ip': '1.1.1.1', 'country': 'US'}),
        const IpInfo(ip: '1.1.1.1', countryCode: 'US'),
      );
      expect(
        IpInfo.fromMyIpJson({'ip': '2.2.2.2', 'cc': 'JP'}),
        const IpInfo(ip: '2.2.2.2', countryCode: 'JP'),
      );
      expect(
        IpInfo.fromIpAPIJson({'query': '3.3.3.3', 'countryCode': 'CN'}),
        const IpInfo(ip: '3.3.3.3', countryCode: 'CN'),
      );
    });

    test('throw FormatException for unsupported response shapes', () {
      expect(
        () => IpInfo.fromIpInfoIoJson({'ip': '1.1.1.1'}),
        throwsFormatException,
      );
      expect(
        () => IpInfo.fromIpApiCoJson({'ip': '1.1.1.1'}),
        throwsFormatException,
      );
    });
  });

  group('IpInfo optional fields', () {
    // 每个源给的字段名都不一样，而竞速拿到哪个源是不确定的——所以每个解析函数
    // 都得单独钉住，不能只测一个就以为都对。
    test('ipwho.is nests asn and timezone in sub objects', () {
      final info = IpInfo.fromIpWhoIsJson({
        'ip': '1.1.1.1',
        'country_code': 'US',
        'country': 'United States',
        'region': 'California',
        'city': 'Mountain View',
        'latitude': 37.4056,
        'longitude': -122.0775,
        'connection': {
          'asn': 15169,
          'org': 'Google LLC',
          'isp': 'Google Public DNS',
        },
        'timezone': {'id': 'America/Los_Angeles'},
      });

      expect(info.country, 'United States');
      expect(info.region, 'California');
      expect(info.city, 'Mountain View');
      expect(info.latitude, 37.4056);
      expect(info.longitude, -122.0775);
      expect(info.asn, 15169);
      expect(info.asnOrganization, 'Google LLC');
      expect(info.isp, 'Google Public DNS');
      expect(info.timezone, 'America/Los_Angeles');
    });

    test('ipinfo.io splits the packed loc string', () {
      final info = IpInfo.fromIpInfoIoJson({
        'ip': '8.8.8.8',
        'country': 'US',
        'city': 'Mountain View',
        'region': 'California',
        'loc': '37.4056,-122.0775',
        'org': 'AS15169 Google LLC',
        'timezone': 'America/Los_Angeles',
      });

      expect(info.latitude, 37.4056);
      expect(info.longitude, -122.0775);
      expect(info.asn, 15169);
      expect(info.asnOrganization, 'Google LLC');
    });

    test('ip-api.com reads the AS field and its region name', () {
      final info = IpInfo.fromIpAPIJson({
        'query': '8.8.8.8',
        'countryCode': 'US',
        'country': 'United States',
        'regionName': 'California',
        'city': 'Mountain View',
        'lat': 37.4056,
        'lon': -122.0775,
        'isp': 'Google LLC',
        'org': 'Google Public DNS',
        'as': 'AS15169 Google LLC',
      });

      expect(info.region, 'California');
      expect(info.asn, 15169);
      expect(info.asnOrganization, 'Google LLC');
      expect(info.isp, 'Google LLC');
      expect(info.latitude, 37.4056);
    });

    test('ip.sb and ident.me and myip fill what they have', () {
      final ipSb = IpInfo.fromIpSbJson({
        'ip': '1.1.1.1',
        'country_code': 'AU',
        'country': 'Australia',
        'city': 'Sydney',
        'asn': 13335,
        'asn_organization': 'Cloudflare, Inc.',
        'isp': 'Cloudflare',
        'latitude': -33.8,
        'longitude': 151.2,
      });
      expect(ipSb.asn, 13335);
      expect(ipSb.asnOrganization, 'Cloudflare, Inc.');
      expect(ipSb.isp, 'Cloudflare');

      final identMe = IpInfo.fromIdentMeJson({
        'ip': '1.1.1.1',
        'cc': 'AU',
        'country': 'Australia',
        'city': 'Sydney',
        'asn': 13335,
        'aso': 'Cloudflare, Inc.',
        'tz': 'Australia/Sydney',
      });
      expect(identMe.country, 'Australia');
      expect(identMe.asnOrganization, 'Cloudflare, Inc.');
      expect(identMe.timezone, 'Australia/Sydney');

      // myip.com 只给这三样，其余必须是 null 而不是空串——空串会在界面上画出
      // 一行有标题没内容的空行。
      final myIp = IpInfo.fromMyIpJson({
        'ip': '2.2.2.2',
        'cc': 'JP',
        'country': 'Japan',
      });
      expect(myIp.country, 'Japan');
      expect(myIp.asn, isNull);
      expect(myIp.city, isNull);
    });

    test('ipapi.is supplies the fields no other source has', () {
      final info = IpInfo.fromIpApiIsJson({
        'ip': '8.8.8.8',
        'rir': 'ARIN',
        'is_datacenter': true,
        'is_vpn': false,
        'is_proxy': false,
        'is_tor': false,
        'company': {
          'name': 'Google LLC',
          'abuser_score': '0.0012 (Low)',
          'type': 'business',
          'network': '8.8.8.0/24',
        },
        'asn': {
          'asn': 15169,
          'org': 'Google LLC',
          'country': 'us',
          'rir': 'ARIN',
          'route': '8.8.8.0/24',
          'type': 'business',
          'abuser_score': '0.0001 (Very Low)',
        },
        'location': {
          'country': 'United States',
          'country_code': 'US',
          'state': 'California',
          'city': 'Mountain View',
          'latitude': 37.4056,
          'longitude': -122.0775,
          'timezone': 'America/Los_Angeles',
        },
      });

      expect(info.ip, '8.8.8.8');
      expect(info.countryCode, 'US');
      expect(info.country, 'United States');
      expect(info.region, 'California');
      expect(info.city, 'Mountain View');
      expect(info.longitude, -122.0775);
      expect(info.latitude, 37.4056);
      expect(info.asn, 15169);
      expect(info.asnOrganization, 'Google LLC');
      expect(info.company, 'Google LLC');
      expect(info.ipType, 'business');
      // 两个子对象都有评分，企业那份更贴近这个具体地址段，取它。
      expect(info.risk, '0.0012 (Low)');
      expect(info.registryCountry, 'us');
      expect(info.registry, 'ARIN');
      expect(info.cidr, '8.8.8.0/24');
      expect(info.isDatacenter, isTrue);
      expect(info.isVpn, isFalse);
    });

    test('ipapi.is without a country code is rejected', () {
      expect(
        () => IpInfo.fromIpApiIsJson({'ip': '8.8.8.8', 'location': {}}),
        throwsFormatException,
      );
      expect(
        () => IpInfo.fromIpApiIsJson({
          'location': {'country_code': 'US'},
        }),
        throwsFormatException,
      );
    });

    test('empty strings become null instead of blank rows', () {
      final info = IpInfo.fromIpSbJson({
        'ip': '1.1.1.1',
        'country_code': 'AU',
        'city': '   ',
        'isp': '',
      });
      expect(info.city, isNull);
      expect(info.isp, isNull);
    });

    test('an AS number with no owner name yields no owner', () {
      // "AS15169" 后面没有名字时不能返回空串，否则界面会多出一行空的
      // 「ASN 所有者」。
      final info = IpInfo.fromIpInfoIoJson({
        'ip': '8.8.8.8',
        'country': 'US',
        'org': 'AS15169',
      });
      expect(info.asn, 15169);
      expect(info.asnOrganization, isNull);
    });

    test('an owner name starting with a digit is kept whole', () {
      // "3 Ireland" 是真实存在的运营商名。按「开头的数字」去剥前缀会把它剥成
      // "Ireland"，所以剥的时候必须认准 AS 前缀。
      final info = IpInfo.fromIpApiCoJson({
        'ip': '1.1.1.1',
        'country_code': 'IE',
        'org': '3 Ireland',
      });
      expect(info.asnOrganization, '3 Ireland');

      final packed = IpInfo.fromIpAPIJson({
        'query': '1.1.1.1',
        'countryCode': 'IE',
        'as': '3 Ireland',
      });
      expect(packed.asnOrganization, '3 Ireland');
    });

    test('fillMissingFrom fills gaps without overwriting what is known', () {
      const base = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'US',
        country: 'United States',
        asn: 15169,
      );
      const detail = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'JP',
        country: 'Japan',
        asn: 99999,
        company: 'Google LLC',
        risk: '0.0012 (Low)',
        cidr: '8.8.8.0/24',
      );

      final merged = base.fillMissingFrom(detail);

      // 已经确认的值不能被第二步的结果顶掉——那会让用户眼前的 IP 和国家跳一下。
      expect(merged.countryCode, 'US');
      expect(merged.country, 'United States');
      expect(merged.asn, 15169);
      // 空的才补。
      expect(merged.company, 'Google LLC');
      expect(merged.risk, '0.0012 (Low)');
      expect(merged.cidr, '8.8.8.0/24');
    });
  });

  group('ResultExt', () {
    test('identifies success and error results', () {
      final success = Result.success('ok');
      final error = Result<Object>.error('failed');

      expect(success.isSuccess, isTrue);
      expect(success.isError, isFalse);
      expect(error.isSuccess, isFalse);
      expect(error.isError, isTrue);
    });
  });
}
