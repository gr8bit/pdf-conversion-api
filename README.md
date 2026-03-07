# PDF Conversion API

Minimal web service wrapping Ghostscript for two PDF conversions:

- **PDF to PDF/A-3** with font embedding and sRGB color profile
- **PDF to ZUGFeRD/Factur-X** (version 2p1, conformance level BASIC) with embedded XML invoice

Ruby 4 / Sinatra / Puma / Docker. No database, no JavaScript.

## Quickstart

```sh
docker compose up
```

The service is available at `http://localhost:8080`.

## API

### `GET /health`

Returns `ok` as plain text.

```sh
curl http://localhost:8080/health
```

---

### `POST /to_pdfa3`

Converts a PDF to PDF/A-3.

**Parameters (multipart/form-data):**

| Name   | Type | Description |
|--------|------|-------------|
| `file` | File | PDF file    |

**Response:** A `Content-Type: application/pdf` response means success. Any other content type indicates an error — the body will be `text/plain` with a human-readable error message.

On success, the response also includes:
- Header `Content-Disposition: attachment; filename="pdfa3.pdf"`
- Header `X-Ghostscript-Log`: Ghostscript output (see [below](#x-ghostscript-log))

**Error status codes:** `400` (missing parameter), `413` (upload too large), `500` (Ghostscript failure)

```sh
curl -F "file=@invoice.pdf" http://localhost:8080/to_pdfa3 -o output.pdf
```

---

### `POST /to_zugferd`

Converts a PDF to a ZUGFeRD-compliant PDF/A-3 with embedded Factur-X XML.

**Parameters (multipart/form-data):**

| Name   | Type   | Description                          |
|--------|--------|--------------------------------------|
| `file` | File   | PDF file                             |
| `xml`  | File   | Factur-X XML invoice file            |
| `date` | String | Invoice date as ISO 8601, e.g. `2024-01-15T10:00:00+01:00` |

**Response:** A `Content-Type: application/pdf` response means success. Any other content type indicates an error — the body will be `text/plain` with a human-readable error message.

On success, the response also includes:
- Header `Content-Disposition: attachment; filename="zugferd.pdf"`
- Header `X-Ghostscript-Log`: Ghostscript output (see [below](#x-ghostscript-log))

**Error status codes:** `400` (missing/invalid parameter), `413` (upload too large), `500` (Ghostscript failure)

```sh
curl -F "file=@invoice.pdf" \
     -F "xml=@factur-x.xml" \
     -F "date=2024-01-15T10:00:00+01:00" \
     http://localhost:8080/to_zugferd -o zugferd.pdf
```

### `X-Ghostscript-Log`

Both conversion endpoints return the Ghostscript log output in the `X-Ghostscript-Log` response header. Non-printable characters and `%` are percent-encoded (e.g. newlines become `%0A`), printable ASCII passes through as-is.

The header is limited to 4096 bytes. If the encoded log exceeds this limit, it is truncated and padded with `~` characters to exactly 4096 bytes. To detect truncation: if the raw header value (before unescaping the percent-encoded sequences) is 4096 bytes long and ends with `~`, the log was truncated.

## Important: Validate your output

This service performs PDF conversions using Ghostscript, but **a successful HTTP 200 response does not guarantee a valid PDF/A-3 or ZUGFeRD document**. Ghostscript may produce output that is structurally incomplete or non-conformant depending on the input PDF.

You **must** validate the output before using it in production:

- **[veraPDF](https://verapdf.org/)** — open-source PDF/A validator. Use this to verify PDF/A-3 conformance.
- **[Mustang](https://www.mustangproject.org/)** — open-source ZUGFeRD/Factur-X library (Java). Use this to validate that the embedded XML, metadata, and PDF/A structure conform to the ZUGFeRD standard.

Do not skip validation. Invalid documents may be silently rejected by recipients, tax authorities, or archiving systems.

## Configuration

| Environment variable | Default | Description |
|----------------------|---------|-------------|
| `MAX_UPLOAD_MB`      | `50`    | Maximum upload size in MB. |
| `GS_TIMEOUT`         | `60`    | Ghostscript process timeout in seconds. |

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      MAX_UPLOAD_MB: 100
      GS_TIMEOUT: 120
```

## License

AGPL-3.0 — inherited from [Ghostscript](https://www.ghostscript.com/), which is licensed under the GNU Affero General Public License v3.0.
