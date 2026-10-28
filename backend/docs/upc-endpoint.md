# UPC lookup endpoint (client contract)

How a client looks up a disc by barcode (RMSTR-7). The iOS client (RMSTR-11) is built against this document. The response body is described in [`edition-schema.md`](edition-schema.md).

Implementation: [`src/upc/upc.controller.ts`](../src/upc/upc.controller.ts), [`src/upc/upc.service.ts`](../src/upc/upc.service.ts), [`src/upc/utils/upc.utils.ts`](../src/upc/utils/upc.utils.ts). If this document and the code disagree, fix whichever is wrong in the same change.

Sections marked **Planned** describe agreed behaviour that isn't implemented yet. Clients shouldn't rely on it until the marker is removed.

## Request

`GET /upc/{code}`

| Part    | Required | Values                                         | Notes                                                                                                                                         |
| ------- | -------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `code`  | yes      | 8, 12 or 13 digits                             | The barcode exactly as scanned. No spaces, dashes or other characters.                                                                        |
| `shape` | no       | `EAN-13` \| `UPC-A` \| `UPC-E` \| `EAN-8`      | The barcode type the scanner reported. Send it whenever it's known. Without it the server has to guess for 8-digit codes (see below).         |

The `shape` values are the backend's own names, not a scanner framework's. On iOS, map Vision's `VNBarcodeSymbology` values `.ean13`, `.upce` and `.ean8` to `EAN-13`, `UPC-E` and `EAN-8`. Vision has no UPC-A type: it reports UPC-A barcodes as EAN-13 with a leading `0`, which the server handles correctly. `UPC-A` is for clients that do read 12-digit codes.

The client should restrict its scanner to those three symbologies, so that QR codes, Code 128, ITF-14 and other types never reach the server.

### How the code is normalized

The server converts every accepted code to a canonical 13-digit GTIN before doing anything else. That value is sent to UPCMDB and returned as the edition's `id`.

| `code`    | `shape`        | Treated as                                                                                         | Canonical form                         |
| --------- | -------------- | -------------------------------------------------------------------------------------------------- | -------------------------------------- |
| 13 digits | `EAN-13`, none | EAN-13                                                                                             | unchanged                              |
| 12 digits | `UPC-A`, none  | UPC-A                                                                                              | one leading `0`                        |
| 8 digits  | `UPC-E`        | UPC-E. First digit must be `0` or `1`.                                                             | expanded to UPC-A, then one leading `0` |
| 8 digits  | `EAN-8`        | EAN-8                                                                                              | five leading `0`s                      |
| 8 digits  | none           | UPC-E if the first digit is `0` or `1` and the expanded form is valid; otherwise EAN-8              | as above                               |

In every case the check digit must be valid. A UPC-E's check digit is checked on its expanded form.

Some 8-digit codes are valid both as a UPC-E and as an EAN-8, and the two readings are different products. Without `shape`, the server picks the UPC-E reading. Sending `shape` avoids that.

Examples:

| Request                         | `id`            |
| ------------------------------- | --------------- |
| `/upc/0043396647640`            | `0043396647640` |
| `/upc/043396647640`             | `0043396647640` |
| `/upc/04252614?shape=UPC-E`     | `0042100005264` |
| `/upc/96385074?shape=EAN-8`     | `0000096385074` |

## Responses

### 200 OK

The body is an `Edition` object, as described in [`edition-schema.md`](edition-schema.md).

### Errors

Error bodies use Nest's default shape: a JSON object with `statusCode` (number), `message` (string) and `error` (the status name). The messages aren't settled yet, so **clients should branch on the status code only, not on the message text**.

| Status                        | When                                                                                                                                                                                                                                                       | Calls UPCMDB? |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| **400 Bad Request**           | `code` contains anything other than digits, or is empty. Its length isn't 8, 12 or 13, or doesn't match `shape` (e.g. 13 digits with `UPC-E`). The check digit is wrong. A `UPC-E` code's first digit isn't `0` or `1`. `shape` isn't one of the four values. The code is valid but isn't a retail product (see [Codes that aren't products](#codes-that-arent-products)). | no            |
| **404 Not Found**             | UPCMDB has no record for the code, or its response isn't JSON or isn't a JSON object (the raw body is logged).                                                                                                                                            | yes           |
| **500 Internal Server Error** | The request to UPCMDB failed in some other way (e.g. a network error).                                                                                                                                                                                    | yes           |
| **502 Bad Gateway**           | UPCMDB returned an error status other than 404.                                                                                                                                                                                                           | yes           |
| **504 Gateway Timeout**       | UPCMDB didn't respond within 5 seconds.                                                                                                                                                                                                                    | yes           |

#### Codes that aren't products

After normalization, the server checks the first three digits of the GTIN-13 against GS1 prefixes that are never used on retail products. A match is rejected with a 400 before UPCMDB is called. The message names the reason (currently `Invalid scanned barcode - <reason>`; don't parse it).

| Prefix                    | Reason                                                 |
| ------------------------- | ------------------------------------------------------ |
| 020–029, 040–049, 200–299 | `Restricted circulation` (store labels, in-house codes) |
| 050–059, 981–984, 990–999 | `Coupon`                                               |
| 980                       | `Refund receipt`                                       |

Books (978, 979) and ISSN (977) are allowed. They won't match a disc, but they're real products and get a normal 404.

Known gap: EAN-8 codes are padded to `00000…`, so this check doesn't see their own prefix. Restricted-circulation EAN-8s (GS1 RCN-8, first digit `0` or `2`; verify against the GS1 General Specifications) currently pass through to UPCMDB.

What the client should do:

- **400:** the scan was bad, or the barcode isn't the product's (a store label or coupon). Ask the user to scan the original barcode again; don't retry the same code.
- **404:** the disc isn't known. Fall back to manual search (MVP: Keep my data right › Handle a failed scan).
- **500, 502, 504:** a temporary failure. Offer a retry.

### Planned

- **RCN-8:** reject restricted-circulation EAN-8 codes, which needs `normalizeUPC` to report which reading it chose.
- **Error codes:** a stable, machine-readable code per 400 reason (bad characters, wrong length, length doesn't match `shape`, bad check digit, store label), so clients can show specific messages without matching on text.
- **Response wrapper** with a schema version (see open items in [`edition-schema.md`](edition-schema.md)).

## Privacy

- **Sent by the client:** the barcode and optionally its type. Nothing else: no user or device identifier, no library contents.
- **Sent to UPCMDB:** the canonical GTIN-13 and the server's API key. Nothing from the client.
- **Logged:** upstream failures and responses that can't be decoded (the raw UPCMDB body), plus warnings about the UPCMDB record itself: its EAN doesn't match the requested code, a value can't be mapped (unknown format, HDR token or date format), or its packaging fields contradict each other. Warnings include the UPC and the raw UPCMDB values, never anything about the client. The client's IP and request details are never logged by the application. Hosting-level request logging is RMSTR-10.
- Invalid codes (400) and not-found lookups (404) are normal outcomes and aren't logged.
