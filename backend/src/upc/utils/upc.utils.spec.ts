import { BadRequestException } from '@nestjs/common';
import { normalizeUPC } from './upc.utils';

describe('UPCUtils', () => {
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
