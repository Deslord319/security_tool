from __future__ import annotations

import argparse
import json
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.tools.test_asset_common import (
    IMPORT_REPORT_PATH,
    VALIDATION_REPORT_PATH,
    batch_delete_catalog_records,
    batch_promote_case_drafts,
    build_case_catalog,
    build_coverage_snapshot,
    decode_base64_file,
    default_catalog,
    import_excel_workbook,
    load_catalog,
    load_json,
    refresh_catalog_result_status,
    save_catalog,
    transform_catalog_records,
    upsert_record,
    validate_test_assets,
)

HTML_PATH = PROJECT_ROOT / "docs/04-测试文档/e2e测试/test-assets-dashboard.html"


def read_json_body(handler: BaseHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length", "0"))
    if length <= 0:
        return {}
    payload = handler.rfile.read(length)
    return json.loads(payload.decode("utf-8"))


class TestAssetHandler(BaseHTTPRequestHandler):
    server_version = "SecurityToolTestAssets/1.0"

    def _write_json(self, payload: dict, status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _write_html(self, content: str) -> None:
        body = content.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in {"/", "/index.html"}:
            if HTML_PATH.exists():
                self._write_html(HTML_PATH.read_text(encoding="utf-8"))
            else:
                self._write_json(
                    {
                        "message": "test asset dashboard html has been removed",
                        "catalog_endpoint": "/api/catalog",
                    }
                )
            return
        if parsed.path == "/api/catalog":
            catalog = refresh_catalog_result_status(load_catalog(), persist=True)
            coverage = build_coverage_snapshot(catalog)
            self._write_json(
                {
                    "catalog": catalog,
                    "coverage": coverage,
                    "import_report": load_json(IMPORT_REPORT_PATH, {}),
                    "validation_report": load_json(VALIDATION_REPORT_PATH, {}),
                }
            )
            return
        self._write_json({"error": "Not found"}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        route_path = parsed.path.rstrip("/") or "/"
        try:
            if route_path == "/api/catalog/rebuild":
                catalog = build_case_catalog()
                coverage = build_coverage_snapshot(catalog)
                self._write_json({"catalog": catalog, "coverage": coverage})
                return
            if route_path == "/api/catalog/save":
                payload = read_json_body(self)
                catalog = payload.get("catalog", default_catalog())
                saved = save_catalog(catalog)
                coverage = build_coverage_snapshot(saved)
                self._write_json({"catalog": saved, "coverage": coverage})
                return
            if route_path == "/api/catalog/upsert":
                payload = read_json_body(self)
                catalog = upsert_record(payload.get("record", {}))
                coverage = build_coverage_snapshot(catalog)
                self._write_json({"catalog": catalog, "coverage": coverage})
                return
            if route_path == "/api/import-excel":
                payload = read_json_body(self)
                filename = payload.get("filename", "upload.xlsx")
                content = decode_base64_file(payload["content_base64"])
                result = import_excel_workbook(content, filename=filename)
                coverage = build_coverage_snapshot(result.catalog)
                self._write_json({"catalog": result.catalog, "coverage": coverage, "report": result.report})
                return
            if route_path == "/api/transform":
                catalog = transform_catalog_records()
                coverage = build_coverage_snapshot(catalog)
                self._write_json({"catalog": catalog, "coverage": coverage})
                return
            if route_path == "/api/batch-promote":
                payload = read_json_body(self)
                result = batch_promote_case_drafts(payload.get("case_ids", []))
                self._write_json(result)
                return
            if route_path == "/api/batch-delete":
                payload = read_json_body(self)
                result = batch_delete_catalog_records(payload.get("case_ids", []))
                self._write_json(result)
                return
            if route_path == "/api/validate":
                report = validate_test_assets()
                self._write_json({"report": report})
                return
        except Exception as exc:  # noqa: BLE001
            self._write_json({"error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return

        self._write_json({"error": "Not found"}, status=HTTPStatus.NOT_FOUND)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the local test asset management web server.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), TestAssetHandler)
    print(f"Test asset dashboard: http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
