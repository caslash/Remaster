import { BadRequestException } from '@nestjs/common';
import {
  isNotRetailProductReason,
  normalizeUPC,
  StoreRangeReason,
} from './upc.utils';

describe('UPCUtils', () => {
  describe('normalizeUPC', () => {
    it('should normalize EAN-13 to 13 digit id without shape', () => {
      const upc = '0043396647640';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0043396647640');
    });

    it('should normalize EAN-13 to 13 digit id with shape', () => {
      const upc = '0043396647640';

      const normalUPC = normalizeUPC(upc, 'EAN-13');

      expect(normalUPC).toBe('0043396647640');
    });

    it('should throw on invalid EAN-13 with bad check digit', () => {
      const upc = '0043396647641';

      expect(() => normalizeUPC(upc, 'EAN-13')).toThrow(BadRequestException);
    });

    it('should throw on invalid EAN-13 with mismatched length', () => {
      const upc = '043396647640';

      expect(() => normalizeUPC(upc, 'EAN-13')).toThrow(BadRequestException);
    });

    it('should normalize UPC-A to 13 digit id without shape', () => {
      const upc = '123456789012';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0123456789012');
    });

    it('should normalize UPC-A to 13 digit id with shape', () => {
      const upc = '123456789012';

      const normalUPC = normalizeUPC(upc, 'UPC-A');

      expect(normalUPC).toBe('0123456789012');
    });

    it('should throw on invalid UPC-A with bad check digit', () => {
      const upc = '043396647641';

      expect(() => normalizeUPC(upc, 'UPC-A')).toThrow(BadRequestException);
    });

    it('should throw on invalid UPC-A with mismatched length', () => {
      const upc = '0043396647640';

      expect(() => normalizeUPC(upc, 'UPC-A')).toThrow(BadRequestException);
    });

    it('should normalize 0 UPC-E to 13 digit id without shape', () => {
      const upc = '04252614';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0042100005264');
    });

    it('should normalize 0 UPC-E to 13 digit id with shape', () => {
      const upc = '04252614';

      const normalUPC = normalizeUPC(upc, 'UPC-E');

      expect(normalUPC).toBe('0042100005264');
    });

    it('should normalize 1 UPC-E to 13 digit id without shape', () => {
      const upc = '14252611';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0142100005261');
    });

    it('should normalize 1 UPC-E to 13 digit id with shape', () => {
      const upc = '14252611';

      const normalUPC = normalizeUPC(upc, 'UPC-E');

      expect(normalUPC).toBe('0142100005261');
    });

    it('should throw on invalid UPC-E with bad check digit', () => {
      const upc = '04252615';

      expect(() => normalizeUPC(upc, 'UPC-E')).toThrow(BadRequestException);
    });

    it('should throw on invalid UPC-E with number system 2', () => {
      const upc = '24252618';

      expect(() => normalizeUPC(upc, 'UPC-E')).toThrow(BadRequestException);
    });

    it('should throw on invalid UPC-E with mismatched length', () => {
      const upc = '425261';

      expect(() => normalizeUPC(upc, 'UPC-E')).toThrow(BadRequestException);
    });

    it('should throw on invalid UPC-E with valid expanded form', () => {
      const upc = '042100005264';

      expect(() => normalizeUPC(upc, 'UPC-E')).toThrow(BadRequestException);
    });

    it('should normalize EAN-8 to 13 digit id without shape', () => {
      const upc = '96385074';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0000096385074');
    });

    it('should normalize EAN-8 to 13 digit id without shape and invalid UPC-E', () => {
      const upc = '02345611';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0000002345611');
    });

    it('should normalize EAN-8 to 13 digit id with shape', () => {
      const upc = '40170725';

      const normalUPC = normalizeUPC(upc, 'EAN-8');

      expect(normalUPC).toBe('0000040170725');
    });

    it('should throw on invalid EAN-8 with bad check digit', () => {
      const upc = '96385075';

      expect(() => normalizeUPC(upc, 'EAN-8')).toThrow(BadRequestException);
    });

    it('should throw on invalid EAN-8 with valid UPC-E', () => {
      const upc = '04252614';

      expect(() => normalizeUPC(upc, 'EAN-8')).toThrow(BadRequestException);
    });

    it('should throw on invalid EAN-8 with mismatched length', () => {
      const upc = '043396647640';

      expect(() => normalizeUPC(upc, 'EAN-8')).toThrow(BadRequestException);
    });

    it('should normalize ambiguous UPC-E/EAN-8 to 13 digit id', () => {
      const upc = '00123457';

      const normalUPC = normalizeUPC(upc, undefined);

      expect(normalUPC).toBe('0001234000057');
    });

    it('should throw on invalid 8 digit upc', () => {
      const upc = '04252615';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });

    it('should throw on invalid 12 digit upc', () => {
      const upc = '043396647641';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });

    it('should throw on invalid 13 digit upc', () => {
      const upc = '5051892123450';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });

    it('should throw on 14 digit upc', () => {
      const upc = '00043396647640';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });

    it('should throw on 6 digit upc', () => {
      const upc = '425261';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });

    it('should throw on letters in upc', () => {
      const upc = '04252615nasd';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });

    it('should throw on empty upc', () => {
      const upc = '';

      expect(() => normalizeUPC(upc, undefined)).toThrow(BadRequestException);
    });
  });

  describe('isNotRetailProductReason', () => {
    it('should allow <020 prefix', () => {
      const upc = '0191234567893';

      expect(isNotRetailProductReason(upc)).toBeFalsy();
    });

    it('should block 020-029 prefix', () => {
      const lowerLimit = '0201234567899';
      const upperLimit = '0291234567890';

      expect(isNotRetailProductReason(lowerLimit)).toBe(
        StoreRangeReason.RESTRICTED,
      );
      expect(isNotRetailProductReason(upperLimit)).toBe(
        StoreRangeReason.RESTRICTED,
      );
    });

    it('should allow 030-039 prefix', () => {
      const lowerLimit = '0301234567896';
      const upperLimit = '0391234567897';

      expect(isNotRetailProductReason(lowerLimit)).toBeFalsy();
      expect(isNotRetailProductReason(upperLimit)).toBeFalsy();
    });

    it('should block 040-049 prefix', () => {
      const lowerLimit = '0401234567893';
      const upperLimit = '0491234567894';

      expect(isNotRetailProductReason(lowerLimit)).toBe(
        StoreRangeReason.RESTRICTED,
      );
      expect(isNotRetailProductReason(upperLimit)).toBe(
        StoreRangeReason.RESTRICTED,
      );
    });

    it('should block 050-059 prefix', () => {
      const lowerLimit = '0501234567890';
      const upperLimit = '0591234567891';

      expect(isNotRetailProductReason(lowerLimit)).toBe(
        StoreRangeReason.COUPON,
      );
      expect(isNotRetailProductReason(upperLimit)).toBe(
        StoreRangeReason.COUPON,
      );
    });

    it('should allow 060 prefix', () => {
      const upc = '0601234567897';

      expect(isNotRetailProductReason(upc)).toBeFalsy();
    });

    it('should allow 199 prefix', () => {
      const upc = '1991234567898';

      expect(isNotRetailProductReason(upc)).toBeFalsy();
    });

    it('should block 200-299 prefix', () => {
      const lowerLimit = '2001234567893';
      const upperLimit = '2991234567897';

      expect(isNotRetailProductReason(lowerLimit)).toBe(
        StoreRangeReason.RESTRICTED,
      );
      expect(isNotRetailProductReason(upperLimit)).toBe(
        StoreRangeReason.RESTRICTED,
      );
    });

    it('should allow 300 prefix', () => {
      const upc = '3001234567892';

      expect(isNotRetailProductReason(upc)).toBeFalsy();
    });

    it('should allow 978-979 prefix', () => {
      const lowerLimit = '9781234567897';
      const upperLimit = '9791234567896';

      expect(isNotRetailProductReason(lowerLimit)).toBeFalsy();
      expect(isNotRetailProductReason(upperLimit)).toBeFalsy();
    });

    it('should block 980 prefix', () => {
      const upc = '9801234567892';

      expect(isNotRetailProductReason(upc)).toBe(StoreRangeReason.REFUND);
    });

    it('should block 981-984 prefix', () => {
      const lowerLimit = '9811234567891';
      const upperLimit = '9841234567898';

      expect(isNotRetailProductReason(lowerLimit)).toBe(
        StoreRangeReason.COUPON,
      );
      expect(isNotRetailProductReason(upperLimit)).toBe(
        StoreRangeReason.COUPON,
      );
    });

    it('should allow 985-989 prefix', () => {
      const lowerLimit = '9851234567897';
      const upperLimit = '9891234567893';

      expect(isNotRetailProductReason(lowerLimit)).toBeFalsy();
      expect(isNotRetailProductReason(upperLimit)).toBeFalsy();
    });

    it('should allow 990-999 prefix', () => {
      const lowerLimit = '9901234567899';
      const upperLimit = '9991234567890';

      expect(isNotRetailProductReason(lowerLimit)).toBe(
        StoreRangeReason.COUPON,
      );
      expect(isNotRetailProductReason(upperLimit)).toBe(
        StoreRangeReason.COUPON,
      );
    });
  });
});
