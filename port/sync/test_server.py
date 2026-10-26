import base64
import importlib.util
import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

spec = importlib.util.spec_from_file_location("ledger", Path(__file__).with_name("server.py"))
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)


class LedgerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        ledger.DB = str(Path(cls.temp.name) / "test.sqlite")
        ledger.initialize()
        cls.server = ledger.ThreadingHTTPServer(("127.0.0.1", 0), ledger.Handler)
        cls.worker = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.worker.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.worker.join()
        cls.temp.cleanup()

    def request(self, path, data=None, auth=None):
        headers = {}
        if auth:
            headers = {"Authorization": "Bearer " + auth["token"], "X-Mechagram-Installation": auth["installation"]}
        request = urllib.request.Request(self.base + path, data=None if data is None else json.dumps(data).encode(), headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=5) as r:
                return r.status, json.load(r)
        except urllib.error.HTTPError as r:
            with r:
                return r.code, json.load(r)

    def test_installation_isolation_transfer_and_public_read(self):
        _, first = self.request("/v1/register", {})
        _, second = self.request("/v1/register", {})
        record = {"id": "123", "owner": "456", "payload": base64.b64encode(json.dumps({"gift": {}, "date": 1, "nameHidden": False, "savedToProfile": True, "canUpgrade": False}).encode()).decode(), "worn": False}
        self.assertEqual(self.request("/v1/gift", record)[0], 401)
        spoofed = dict(first, token=second["token"])
        self.assertEqual(self.request("/v1/gift", record, spoofed)[0], 401)
        self.assertEqual(self.request("/v1/gift", record, first)[0], 200)
        self.assertEqual(len(self.request("/v1/profile/456")[1]["gifts"]), 1)
        record["owner"] = "789"
        self.assertEqual(self.request("/v1/gift", record, first)[0], 200)
        self.assertEqual(self.request("/v1/profile/456")[1]["gifts"], [])
        self.assertEqual(len(self.request("/v1/profile/789")[1]["gifts"]), 1)
        self.assertEqual(self.request("/v1/gift", dict(record, id="bad"), first)[0], 400)
        self.assertEqual(self.request("/v1/gift", dict(record, payload="bad"), first)[0], 400)
        private_payload = base64.b64encode(json.dumps({"gift": {}, "fromPeerId": "secret"}).encode()).decode()
        self.assertEqual(self.request("/v1/gift", dict(record, payload=private_payload), first)[0], 400)
        record["owner"] = "111"
        self.assertEqual(self.request("/v1/gift", record, second)[0], 200)
        old_profile = self.request("/v1/profile/789")[1]
        self.assertEqual(old_profile["gifts"], [])
        self.assertEqual(old_profile["moved"], ["123"])
        self.assertEqual(len(self.request("/v1/profile/111")[1]["gifts"]), 1)
        self.assertEqual(self.request("/v1/profile/789?sql=1")[0], 404)


if __name__ == "__main__":
    unittest.main()
