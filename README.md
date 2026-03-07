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

**Success (200):**
- Body: PDF/A-3 file (`application/pdf`)
- Header `Content-Disposition: attachment; filename="output.pdf"`
- Header `X-Ghostscript-Log`: Ghostscript output (single line, max 4096 chars)

**Errors:**
- `400` — missing parameter (plain text)
- `413` — upload exceeds size limit (plain text)
- `500` — Ghostscript error, full output in body (plain text)

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

**Success (200):**
- Body: ZUGFeRD PDF/A-3 file (`application/pdf`)
- Header `Content-Disposition: attachment; filename="zugferd.pdf"`
- Header `X-Ghostscript-Log`: Ghostscript output (single line, max 4096 chars)

**Errors:**
- `400` — missing or invalid parameter (plain text)
- `413` — upload exceeds size limit (plain text)
- `500` — Ghostscript error, full output in body (plain text)

```sh
curl -F "file=@invoice.pdf" \
     -F "xml=@factur-x.xml" \
     -F "date=2024-01-15T10:00:00+01:00" \
     http://localhost:8080/to_zugferd -o zugferd.pdf
```

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
