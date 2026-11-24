import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/core/pricing.dart';
import 'package:my_first_app/core/request_status.dart';
import 'package:my_first_app/core/service_catalog.dart';

void main() {
  group('Pricing', () {
    test('labor cost is 1.5 SAR per minute', () {
      expect(Pricing.laborCost(5), 7.5);
      expect(Pricing.laborCost(60), 90.0);
      expect(Pricing.laborCost(120), 180.0);
    });

    test('app fee never goes below 5 SAR', () {
      expect(Pricing.appFee(Pricing.laborCost(5)), 5.0);
      expect(Pricing.appFee(Pricing.laborCost(22)), 5.0);
    });

    test('app fee is 15% of labor above the minimum', () {
      // 23 دقيقة = 34.5 ريال، 15% = 5.175 -> 5.17
      expect(Pricing.appFee(Pricing.laborCost(23)), 5.17);
      expect(Pricing.appFee(Pricing.laborCost(60)), 13.5);
      expect(Pricing.appFee(Pricing.laborCost(120)), 27.0);
    });

    test('fee matches the Firestore rule formula for every duration', () {
      for (var m = Pricing.minMinutes; m <= Pricing.maxMinutes; m++) {
        final labor = Pricing.laborCost(m);
        final halalas = (labor * 15).floor();
        final ruleFee = halalas >= 500 ? halalas / 100.0 : 5.0;
        expect(Pricing.appFee(labor), ruleFee, reason: '$m minutes');
      }
    });

    test('total adds labor, fee and materials', () {
      expect(Pricing.total(laborCost: 90, appFee: 13.5), 103.5);
      expect(
        Pricing.total(laborCost: 90, appFee: 13.5, materialsCost: 20),
        123.5,
      );
    });
  });

  group('ServiceCatalog', () {
    test('contains the four services in the rules', () {
      expect(ServiceCatalog.all.map((s) => s.id), [
        'plumber',
        'electrician',
        'ac',
        'washing_machine',
      ]);
    });

    test('AC and washing machine ask for device and issue', () {
      expect(ServiceCatalog.ac.hasDeviceDetails, isTrue);
      expect(ServiceCatalog.washingMachine.hasDeviceDetails, isTrue);
      expect(ServiceCatalog.plumber.hasDeviceDetails, isFalse);
      expect(ServiceCatalog.electrician.hasDeviceDetails, isFalse);
    });

    test('option labels fit the 60 character rule limit', () {
      for (final service in ServiceCatalog.all) {
        for (final option in [...service.deviceTypes, ...service.issueTypes]) {
          expect(option.length, lessThanOrEqualTo(60));
        }
      }
    });

    test('unknown ids are handled', () {
      expect(ServiceCatalog.byId('unknown'), isNull);
      expect(ServiceCatalog.jobNameOf(null), '-');
    });
  });

  group('RequestStatus', () {
    test('accepted requests cannot be cancelled by the customer', () {
      expect(RequestStatus.cancellable, isNot(contains('accepted')));
      expect(RequestStatus.cancellable, contains('searching'));
    });
  });
}
