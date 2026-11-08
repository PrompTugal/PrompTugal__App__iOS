import os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import tf


class Requests(unittest.TestCase):
    def test_add(self):
        self.assertEqual(tf.plan_add_to_group("G", "B"),
                         ("POST", "/v1/betaGroups/G/relationships/builds", {"data": [{"type": "builds", "id": "B"}]}))

    def test_remove(self):
        m, p, body = tf.plan_remove_from_group("G", "B")
        self.assertEqual((m, p), ("DELETE", "/v1/betaGroups/G/relationships/builds"))
        self.assertEqual(body["data"], [{"type": "builds", "id": "B"}])

    def test_expire(self):
        m, p, body = tf.plan_expire("B")
        self.assertEqual((m, p), ("PATCH", "/v1/builds/B"))
        self.assertIs(body["data"]["attributes"]["expired"], True)

    def test_submit(self):
        m, p, body = tf.plan_submit_beta_review("B")
        self.assertEqual((m, p), ("POST", "/v1/betaAppReviewSubmissions"))
        self.assertEqual(body["data"]["relationships"]["build"]["data"], {"type": "builds", "id": "B"})

    def test_whats_new_create_and_update(self):
        m, p, b = tf.plan_whats_new("B", None, "en-US", "hi")
        self.assertEqual((m, p), ("POST", "/v1/betaBuildLocalizations"))
        self.assertEqual(b["data"]["attributes"], {"locale": "en-US", "whatsNew": "hi"})
        m, p, b = tf.plan_whats_new("B", "L1", "en-US", "x" * 5000)
        self.assertEqual((m, p), ("PATCH", "/v1/betaBuildLocalizations/L1"))
        self.assertEqual(len(b["data"]["attributes"]["whatsNew"]), 4000)

    def test_builds_query(self):
        q = tf.builds_query("A1", "6")
        self.assertIn("filter[app]=A1", q)
        self.assertIn("filter[version]=6", q)
        self.assertNotIn("filter[version]", tf.builds_query("A1"))

    def test_review_detail(self):
        m, p, b = tf.plan_review_detail("D", {"notes": "n"})
        self.assertEqual((m, p), ("PATCH", "/v1/betaAppReviewDetails/D"))
        self.assertEqual(b["data"]["type"], "betaAppReviewDetails")


class ReviewInfo(unittest.TestCase):
    def test_missing_listed(self):
        attrs, missing = tf.review_attributes({}, "Key <DEMO_OPENROUTER_KEY> and <CONTACT_ADDRESS>", {})
        self.assertIn("contactEmail", missing)
        self.assertIn("notes placeholder <DEMO_OPENROUTER_KEY>", missing)

    def test_complete(self):
        info = {"contactFirstName": "A", "contactLastName": "B", "contactEmail": "a@b.c", "contactPhone": "+351"}
        attrs, missing = tf.review_attributes(info, "Key <DEMO_KEY>", {"DEMO_KEY": "sk-x"})
        self.assertEqual(missing, [])
        self.assertEqual(attrs["notes"], "Key sk-x")
        self.assertIs(attrs["demoAccountRequired"], False)

    def test_demo_account_needs_credentials(self):
        info = {"contactFirstName": "A", "contactLastName": "B", "contactEmail": "a@b.c", "contactPhone": "1",
                "demoAccountRequired": True}
        _, missing = tf.review_attributes(info, "n", {})
        self.assertEqual(missing, ["demoAccountName", "demoAccountPassword"])


if __name__ == "__main__":
    unittest.main()
